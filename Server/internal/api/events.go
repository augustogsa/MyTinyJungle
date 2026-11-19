package api

import (
	"net/http"
	"regexp"

	"github.com/jackc/pgx/v5"
)

var eventName = regexp.MustCompile(`^[a-z][a-z0-9_]{1,39}$`)

// postEvents adds anonymous daily counts. No auth, no identifiers: the body is just {name: count}.
func (s *Server) postEvents(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Platform   string           `json:"platform"`
		AppVersion string           `json:"appVersion"`
		Counts     map[string]int64 `json:"counts"`
	}
	if decode(r, &in) != nil || (in.Platform != "ios" && in.Platform != "android") || in.AppVersion == "" || len(in.AppVersion) > 32 || len(in.Counts) == 0 || len(in.Counts) > 60 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx := r.Context()
	err := pgx.BeginFunc(ctx, s.db.Auth, func(tx pgx.Tx) error {
		for name, n := range in.Counts {
			if !eventName.MatchString(name) || n < 1 || n > 1000 {
				continue
			}
			if _, err := tx.Exec(ctx, `insert into event_counts (day, name, platform, app_version, n) values (current_date, $1, $2, $3, $4)
				on conflict (day, name, platform, app_version) do update set n = event_counts.n + excluded.n`, name, in.Platform, in.AppVersion, n); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) adminEvents(w http.ResponseWriter, r *http.Request) {
	var out []byte
	err := s.db.Admin.QueryRow(r.Context(), `select coalesce(json_agg(t), '[]') from (
		select name, platform, sum(n) as n, sum(n) filter (where day > current_date - 7) as last7
		from event_counts where day > current_date - 30 group by 1, 2 order by 3 desc limit 300) t`).Scan(&out)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(out)
}
