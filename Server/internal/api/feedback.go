package api

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

const feedbackPerDay = 60

// POST /v1/brain/feedback {kind, predicted, corrected, photoRef?, lang}: owners correct the brain.
// kind: species | scene_field (predicted/corrected as "field=value", e.g. "soil.medium=soil" → "soil.medium=water")
// | answer_helpful | diagnose_helpful (predicted = answer or knowledge id, corrected = "yes" | "no").
func (s *Server) brainFeedback(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Kind, Predicted, Corrected, Lang string
		PhotoRef                         string `json:"photoRef"`
	}
	ok := decode(r, &in) == nil && len(in.Predicted) <= 120 && len(in.Corrected) <= 120 && len(in.Lang) <= 12
	switch in.Kind {
	case "species", "scene_field", "answer_helpful", "diagnose_helpful":
	default:
		ok = false
	}
	var jungle, media string
	if in.PhotoRef != "" {
		parts := strings.Split(in.PhotoRef, "/")
		ok = ok && len(parts) == 2 && isUUID(parts[0]) && isUUID(parts[1])
		if ok {
			jungle, media = parts[0], parts[1]
		}
	}
	if !ok {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	if in.Kind == "species" {
		if sp := theBrainWith(s).findSpecies(in.Corrected); sp != nil {
			in.Corrected = sp.ID
		}
	}
	ctx, c := r.Context(), claimsOf(r)
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		var n int
		if err := tx.QueryRow(ctx, `select count(*) from brain_feedback where user_id = $1 and day = current_date`, c.Sub).Scan(&n); err != nil {
			return err
		}
		if n >= feedbackPerDay {
			return apiError{http.StatusTooManyRequests, "daily_limit"}
		}
		var ref any
		if jungle != "" {
			// Only a photo this user can already reach (RLS on media).
			var one int
			if err := tx.QueryRow(ctx, `select 1 from media where jungle_id = $1 and id = $2`, jungle, media).Scan(&one); err != nil {
				return apiError{http.StatusNotFound, "photo_not_found"}
			}
			ref = jungle + "/" + media
		}
		_, err := tx.Exec(ctx, `insert into brain_feedback (user_id, kind, predicted, corrected, photo_ref, lang) values ($1,$2,$3,$4,$5,$6)`,
			c.Sub, in.Kind, in.Predicted, in.Corrected, ref, in.Lang)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func theBrainWith(s *Server) *brain {
	if theBrain.dir == "" {
		theBrain.dir = s.cfg.ContentDir
	}
	return theBrain
}

// learnLoop runs the nightly learning round (around 03:00 UTC).
func (s *Server) learnLoop(ctx context.Context) {
	t := time.NewTicker(time.Hour)
	defer t.Stop()
	last := ""
	for {
		if now := time.Now().UTC(); now.Hour() == 3 && now.Format("2006-01-02") != last {
			last = now.Format("2006-01-02")
			s.learnRound(ctx)
		}
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

// outdoorPrior: how much less likely a garden species is than a houseplant in an owner's photo. Retuned weekly
// (Sundays, or after a restart) from the last 90 days of species corrections: owners correcting to outdoor
// species more often than away from them loosens it, the reverse tightens it. Default -0.7, range -1.5..0.
var outdoorPriorState struct {
	v    float64
	week string
}

func (s *Server) outdoorPrior(ctx context.Context) float64 {
	y, wk := time.Now().UTC().ISOWeek()
	week := fmt.Sprintf("%d-%d", y, wk)
	if outdoorPriorState.week != "" && (outdoorPriorState.week == week || time.Now().UTC().Weekday() != time.Sunday) {
		return outdoorPriorState.v
	}
	v := -0.7
	var toOut, fromOut, n float64
	if rows, err := s.db.Auth.Query(ctx, `select predicted, corrected from brain_feedback where kind = 'species' and corrected <> predicted
		and created_at > now() - interval '90 days'`); err == nil {
		for rows.Next() {
			var p, c string
			if rows.Scan(&p, &c) != nil {
				continue
			}
			speciesDB.RLock()
			ps, cs := speciesDB.byID[p], speciesDB.byID[c]
			speciesDB.RUnlock()
			if ps == nil || cs == nil {
				continue
			}
			n++
			if cs.Outdoor && !ps.Outdoor {
				toOut++
			}
			if ps.Outdoor && !cs.Outdoor {
				fromOut++
			}
		}
		rows.Close()
	}
	if n >= 20 {
		v = max(-1.5, min(0, -0.7+1.5*(toOut-fromOut)/n))
	}
	outdoorPriorState.v, outdoorPriorState.week = v, week
	return v
}

// learnRound turns confirmed species corrections into (1) a per-species prior for mtj-id (more owners correcting
// to a species → a small boost) and (2) reference photos: corrected photos the owner shared are embedded into
// the reference index by mtj-id. Nothing leaves the server.
func (s *Server) learnRound(ctx context.Context) {
	b := theBrainWith(s)
	b.species()
	prior := map[string]float64{}
	if rows, err := s.db.Auth.Query(ctx, `select corrected, count(distinct user_id) from brain_feedback where kind = 'species' and corrected <> predicted group by 1`); err == nil {
		for rows.Next() {
			var id string
			var n float64
			rows.Scan(&id, &n)
			speciesDB.RLock()
			_, known := speciesDB.byID[id]
			speciesDB.RUnlock()
			if known && n >= 2 { // confirmed by at least two owners
				prior[id] = min(0.6, 0.15*n)
			}
		}
		rows.Close()
	}
	postID(ctx, "/prior", map[string]any{"boost": prior, "_outdoor": s.outdoorPrior(ctx)})
	rows, err := s.db.Auth.Query(ctx, `select id, corrected, photo_ref from brain_feedback where kind = 'species' and photo_ref is not null and learned_at is null limit 200`)
	if err != nil {
		return
	}
	type item struct {
		ID       int64
		Species  string
		PhotoRef string
	}
	items, _ := pgx.CollectRows(rows, pgx.RowToStructByPos[item])
	for _, it := range items {
		speciesDB.RLock()
		_, known := speciesDB.byID[it.Species]
		speciesDB.RUnlock()
		parts := strings.Split(it.PhotoRef, "/")
		done := !known || len(parts) != 2
		if !done {
			path, aad := s.mediaPath(parts[0], parts[1])
			if sealed, err := os.ReadFile(path); err == nil {
				if plain, err := open(s.cfg.MediaKey, aad, sealed); err == nil && len(plain) > 3 && plain[0] == 0xFF && plain[1] == 0xD8 {
					done = postID(ctx, "/learn", map[string]any{"photo": base64.StdEncoding.EncodeToString(plain), "id": it.Species, "ref": it.PhotoRef})
				}
			} else {
				done = true // photo deleted since
			}
		}
		if done {
			s.db.Auth.Exec(ctx, `update brain_feedback set learned_at = now() where id = $1`, it.ID)
		}
	}
}

func postID(ctx context.Context, path string, body any) bool {
	b, _ := json.Marshal(body)
	cctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(cctx, "POST", "http://127.0.0.1:8092"+path, strings.NewReader(string(b)))
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return false
	}
	res.Body.Close()
	return res.StatusCode == 200
}
