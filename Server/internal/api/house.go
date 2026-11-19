package api

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
)

// The shared jungle's household state (members' turns, cover asks, activity, plant roster) is one
// JSON document per jungle, merged on the devices. Writes are compare-and-swap on the version:
// a stale write gets 409 with the current copy, the device merges and retries. Every accepted
// write wakes the other members' devices.

const maxHouse = 1 << 20

func (s *Server) getHouse(w http.ResponseWriter, r *http.Request) {
	ctx, c, jid := r.Context(), claimsOf(r), r.PathValue("id")
	if !isUUID(jid) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	var data json.RawMessage
	var version int64
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select data, version from records where jungle_id = $1 and entity = 'house' and id = $1 and not deleted`, jid).Scan(&data, &version)
	})
	if isNoRows(err) {
		writeErr(w, http.StatusNotFound, "not_found")
		return
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": data, "version": version})
}

func (s *Server) putHouse(w http.ResponseWriter, r *http.Request) {
	ctx, c, jid := r.Context(), claimsOf(r), r.PathValue("id")
	var in struct {
		Data        json.RawMessage `json:"data"`
		BaseVersion *int64          `json:"baseVersion"`
	}
	if !isUUID(jid) || decode(r, &in) != nil || len(in.Data) < 2 || len(in.Data) > maxHouse || in.Data[0] != '{' {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	var version int64
	var current json.RawMessage
	conflict := false
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		var err error
		if in.BaseVersion == nil {
			err = tx.QueryRow(ctx, `insert into records (jungle_id, entity, id, data, updated_by, updated_device, client_updated_at)
				values ($1, 'house', $1, $2, $3, $4, now()) on conflict do nothing returning version`, jid, in.Data, c.Sub, c.Dev).Scan(&version)
		} else {
			err = tx.QueryRow(ctx, `update records set data = $2, deleted = false, version = nextval('record_version_seq'), updated_by = $3,
				updated_device = $4, client_updated_at = now(), updated_at = now()
				where jungle_id = $1 and entity = 'house' and id = $1 and version = $5 returning version`, jid, in.Data, c.Sub, c.Dev, *in.BaseVersion).Scan(&version)
		}
		if !isNoRows(err) {
			return err
		}
		conflict = true
		err = tx.QueryRow(ctx, `select data, version from records where jungle_id = $1 and entity = 'house' and id = $1`, jid).Scan(&current, &version)
		if isNoRows(err) {
			return apiError{http.StatusForbidden, "forbidden"}
		}
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if conflict {
		writeJSON(w, http.StatusConflict, map[string]any{"error": "conflict", "data": current, "version": version})
		return
	}
	s.pusher.jungleChanged(jid, c.Sub)
	writeJSON(w, http.StatusOK, map[string]any{"version": version})
}

// export: everything stored about the caller (GDPR art. 15/20, LGPD art. 18) as one JSON file.
// Photos are listed with their download path rather than inlined, to keep the file small.
func (s *Server) export(w http.ResponseWriter, r *http.Request) {
	ctx, c := r.Context(), claimsOf(r)
	out := map[string]any{"exportedAt": s.now().UTC(), "format": "mytinyjungle-export-1"}
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		for _, x := range [][]string{
			{"account", `select id, email, display_name, locale, created_at from users where id = $1`},
			{"signIns", `select provider, created_at from identities where user_id = $1`},
			{"devices", `select id, platform, model, app_version, last_seen_at from devices where user_id = $1`},
			{"entitlements", `select store, product_id, status, expires_at, updated_at from entitlements where user_id = $1`},
			{"jungles", `select j.id, j.name, j.is_personal, m.role, m.until, m.joined_at from jungles j join jungle_members m on m.jungle_id = j.id where m.user_id = $1`},
			{"records", `select jungle_id, entity, id, data, updated_at from records where not deleted and (updated_by = $1 or jungle_id in (select id from jungles where owner_id = $1)) order by jungle_id, entity, updated_at`},
			{"households", `select h.id, h.name, h.jungle_id, m.role, m.joined_at from households h join household_members m on m.household_id = h.id where m.user_id = $1`},
			{"supplies", `select id, kind, name, qty, unit, low_at, updated_at from supplies where user_id = $1`},
			{"passports", `select token, plant_id, card, views, imports, created_at from plant_passports where user_id = $1`},
			{"photos", `select jungle_id, id, content_type, bytes, created_at, '/v1/media/' || jungle_id || '/' || id as path from media where created_by = $1 or jungle_id in (select id from jungles where owner_id = $1)`},
		} {
			var v json.RawMessage
			if err := tx.QueryRow(ctx, `select coalesce(json_agg(t), '[]'::json) from (`+x[1]+`) t`, c.Sub).Scan(&v); err != nil {
				return err
			}
			out[x[0]] = v
		}
		return nil
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	w.Header().Set("Content-Disposition", `attachment; filename="mytinyjungle-`+s.now().UTC().Format(time.DateOnly)+`.json"`)
	writeJSON(w, http.StatusOK, out)
}
