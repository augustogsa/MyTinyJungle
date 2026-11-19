package api

import (
	"encoding/json"
	"net/http"
	"slices"

	"github.com/jackc/pgx/v5"
)

var diagKinds = []string{"crash", "hang", "cpu", "disk", "launch", "other"}

// postDiagnostics stores crash/hang reports without any user link. Signed-in apps only (abuse control).
func (s *Server) postDiagnostics(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Platform   string `json:"platform"`
		AppVersion string `json:"appVersion"`
		OSVersion  string `json:"osVersion"`
		Reports    []struct {
			Kind    string          `json:"kind"`
			Payload json.RawMessage `json:"payload"`
		} `json:"reports"`
	}
	if decode(r, &in) != nil || (in.Platform != "ios" && in.Platform != "android") || in.AppVersion == "" || len(in.AppVersion) > 32 ||
		len(in.OSVersion) > 64 || len(in.Reports) == 0 || len(in.Reports) > 20 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx, c := r.Context(), claimsOf(r)
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		for _, rep := range in.Reports {
			if !slices.Contains(diagKinds, rep.Kind) || len(rep.Payload) < 2 || len(rep.Payload) > 256<<10 || rep.Payload[0] != '{' {
				continue
			}
			if _, err := tx.Exec(ctx, `insert into diagnostics (platform, app_version, os_version, kind, payload) values ($1,$2,$3,$4,$5)`,
				in.Platform, in.AppVersion, in.OSVersion, rep.Kind, rep.Payload); err != nil {
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

func (s *Server) adminDiagnostics(w http.ResponseWriter, r *http.Request) {
	rows, err := s.db.Admin.Query(r.Context(), `select coalesce(json_agg(t), '[]') from (
		select platform, app_version, kind, count(*) as n, max(created_at) as last
		from diagnostics where created_at > now() - interval '30 days'
		group by 1, 2, 3 order by last desc limit 200) t`)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	defer rows.Close()
	var out json.RawMessage
	if rows.Next() {
		_ = rows.Scan(&out)
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(out)
}
