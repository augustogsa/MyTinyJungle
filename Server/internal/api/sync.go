package api

import (
	"encoding/json"
	"net/http"
	"slices"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
)

var entities = []string{"plant", "care_event", "chat_message", "owned_product", "space", "care_task", "observation", "badge"}

type change struct {
	JungleID        string          `json:"jungleId"`
	Entity          string          `json:"entity"`
	ID              string          `json:"id"`
	Data            json.RawMessage `json:"data"`
	Deleted         bool            `json:"deleted"`
	BaseVersion     *int64          `json:"baseVersion"`
	ClientUpdatedAt time.Time       `json:"clientUpdatedAt"`
}

type record struct {
	JungleID  string          `json:"jungleId"`
	Entity    string          `json:"entity"`
	ID        string          `json:"id"`
	Data      json.RawMessage `json:"data"`
	Deleted   bool            `json:"deleted"`
	Version   int64           `json:"version"`
	UpdatedAt time.Time       `json:"updatedAt"`
}

// pull returns every change after the cursor across all reachable jungles (RLS filters), oldest first.
func (s *Server) pull(w http.ResponseWriter, r *http.Request) {
	since, _ := strconv.ParseInt(r.URL.Query().Get("since"), 10, 64)
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 1000 {
		limit = 500
	}
	ctx, c := r.Context(), claimsOf(r)
	var recs []record
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		rows, _ := tx.Query(ctx, `select jungle_id, entity, id, data, deleted, version, updated_at from records
			where version > $1 order by version limit $2`, since, limit+1)
		var err error
		recs, err = pgx.CollectRows(rows, func(row pgx.CollectableRow) (record, error) {
			var x record
			return x, row.Scan(&x.JungleID, &x.Entity, &x.ID, &x.Data, &x.Deleted, &x.Version, &x.UpdatedAt)
		})
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	more := len(recs) > limit
	if more {
		recs = recs[:limit]
	}
	cursor := since
	if len(recs) > 0 {
		cursor = recs[len(recs)-1].Version
	}
	if recs == nil {
		recs = []record{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"changes": recs, "cursor": cursor, "more": more})
}

type pushResult struct {
	ID      string  `json:"id"`
	Entity  string  `json:"entity"`
	Status  string  `json:"status"` // ok | conflict | forbidden | invalid
	Version int64   `json:"version,omitempty"`
	Server  *record `json:"server,omitempty"`
}

// stale reports whether an incoming write lost against the stored row: the client did not see the current
// version and the stored edit is newer by client clock. Equal versions always win (fast path).
func stale(base *int64, curVersion int64, curUpdated, incoming time.Time) bool {
	if base != nil && *base == curVersion {
		return false
	}
	return curUpdated.After(incoming)
}

func (s *Server) push(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Changes []change `json:"changes"`
	}
	r.Body = http.MaxBytesReader(w, r.Body, 8<<20)
	if err := decode(r, &in); err != nil {
		s.fail(w, r, err)
		return
	}
	if len(in.Changes) == 0 || len(in.Changes) > 500 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx, c := r.Context(), claimsOf(r)
	results := make([]pushResult, 0, len(in.Changes))
	future := s.now().Add(5 * time.Minute)
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		rows, _ := tx.Query(ctx, `select mtj_my_jungles()`)
		mine, err := pgx.CollectRows(rows, pgx.RowTo[string])
		if err != nil {
			return err
		}
		for _, ch := range in.Changes {
			res := pushResult{ID: ch.ID, Entity: ch.Entity}
			switch {
			case !isUUID(ch.ID) || !slices.Contains(entities, ch.Entity) || len(ch.Data) == 0 || len(ch.Data) > 256<<10 ||
				ch.ClientUpdatedAt.IsZero() || ch.ClientUpdatedAt.After(future) || ch.Data[0] != '{':
				res.Status = "invalid"
			case !slices.Contains(mine, ch.JungleID):
				res.Status = "forbidden"
			default:
				var cur record
				var curUpdated time.Time
				err := tx.QueryRow(ctx, `select jungle_id, entity, id, data, deleted, version, updated_at, client_updated_at from records
					where jungle_id = $1 and entity = $2 and id = $3 for update`, ch.JungleID, ch.Entity, ch.ID).
					Scan(&cur.JungleID, &cur.Entity, &cur.ID, &cur.Data, &cur.Deleted, &cur.Version, &cur.UpdatedAt, &curUpdated)
				if err != nil && !isNoRows(err) {
					return err
				}
				if err == nil && stale(ch.BaseVersion, cur.Version, curUpdated, ch.ClientUpdatedAt) {
					res.Status, res.Server = "conflict", &cur
					break
				}
				if err := tx.QueryRow(ctx, `insert into records (jungle_id, entity, id, data, deleted, updated_by, updated_device, client_updated_at)
					values ($1,$2,$3,$4,$5,$6,$7,$8)
					on conflict (jungle_id, entity, id) do update set data = excluded.data, deleted = excluded.deleted,
					  version = nextval('record_version_seq'), updated_by = excluded.updated_by, updated_device = excluded.updated_device,
					  client_updated_at = excluded.client_updated_at, updated_at = now()
					returning version`, ch.JungleID, ch.Entity, ch.ID, ch.Data, ch.Deleted, c.Sub, c.Dev, ch.ClientUpdatedAt).
					Scan(&res.Version); err != nil {
					return err
				}
				res.Status = "ok"
			}
			results = append(results, res)
		}
		return nil
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"results": results})
}
