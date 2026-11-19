package api

import (
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
)

type entitlementOut struct {
	Store     string     `json:"store"`
	ProductID string     `json:"productId"`
	ExpiresAt *time.Time `json:"expiresAt"`
	Status    string     `json:"status"`
}

func (s *Server) me(w http.ResponseWriter, r *http.Request) {
	ctx, c := r.Context(), claimsOf(r)
	type device struct {
		ID         string    `json:"id"`
		Platform   string    `json:"platform"`
		Model      *string   `json:"model"`
		AppVersion *string   `json:"appVersion"`
		LastSeenAt time.Time `json:"lastSeenAt"`
		This       bool      `json:"thisDevice"`
	}
	out := struct {
		ID           string           `json:"id"`
		Email        *string          `json:"email"`
		DisplayName  *string          `json:"displayName"`
		Locale       *string          `json:"locale"`
		CreatedAt    time.Time        `json:"createdAt"`
		Providers    []string         `json:"providers"`
		Devices      []device         `json:"devices"`
		Plus         bool             `json:"plus"`
		Entitlements []entitlementOut `json:"entitlements"`
	}{Providers: []string{}, Devices: []device{}, Entitlements: []entitlementOut{}}
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, `select id, email, display_name, locale, created_at from users where id = $1 and deleted_at is null`, c.Sub).
			Scan(&out.ID, &out.Email, &out.DisplayName, &out.Locale, &out.CreatedAt); err != nil {
			return err
		}
		rows, _ := tx.Query(ctx, `select provider from identities where user_id = $1 order by provider`, c.Sub)
		ps, err := pgx.CollectRows(rows, pgx.RowTo[string])
		if err != nil {
			return err
		}
		out.Providers = append(out.Providers, ps...)
		rows, _ = tx.Query(ctx, `select id, platform, model, app_version, last_seen_at from devices order by last_seen_at desc`)
		ds, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (device, error) {
			var d device
			err := row.Scan(&d.ID, &d.Platform, &d.Model, &d.AppVersion, &d.LastSeenAt)
			d.This = d.ID == c.Dev
			return d, err
		})
		if err != nil {
			return err
		}
		out.Devices = append(out.Devices, ds...)
		out.Entitlements, err = activeEntitlements(r, tx)
		out.Plus = len(out.Entitlements) > 0
		return err
	})
	if isNoRows(err) {
		writeErr(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func activeEntitlements(r *http.Request, tx pgx.Tx) ([]entitlementOut, error) {
	rows, _ := tx.Query(r.Context(), `select store, product_id, expires_at, status from entitlements
		where status in ('active','grace') and (expires_at is null or expires_at > now()) order by expires_at desc nulls first`)
	es, err := pgx.CollectRows(rows, func(row pgx.CollectableRow) (entitlementOut, error) {
		var e entitlementOut
		return e, row.Scan(&e.Store, &e.ProductID, &e.ExpiresAt, &e.Status)
	})
	if es == nil {
		es = []entitlementOut{}
	}
	return es, err
}

func (s *Server) patchMe(w http.ResponseWriter, r *http.Request) {
	var in struct {
		DisplayName *string `json:"displayName"`
		Locale      *string `json:"locale"`
	}
	if err := decode(r, &in); err != nil {
		s.fail(w, r, err)
		return
	}
	if (in.DisplayName != nil && len(*in.DisplayName) > 60) || (in.Locale != nil && len(*in.Locale) > 12) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	c := claimsOf(r)
	err := s.db.AsUser(r.Context(), c.Sub, func(tx pgx.Tx) error {
		_, err := tx.Exec(r.Context(), `update users set display_name = coalesce($2, display_name), locale = coalesce($3, locale) where id = $1`,
			c.Sub, in.DisplayName, in.Locale)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (s *Server) pushToken(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Token string `json:"token"`
	}
	if err := decode(r, &in); err != nil || len(in.Token) == 0 || len(in.Token) > 400 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	c := claimsOf(r)
	err := s.db.AsUser(r.Context(), c.Sub, func(tx pgx.Tx) error {
		_, err := tx.Exec(r.Context(), `update devices set push_token = $2, last_seen_at = now() where id = $1`, c.Dev, in.Token)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// deleteMe: in-app account deletion (App Review 5.1.1(v)). Signs out everywhere now; the purge job erases
// the account and every jungle it owns after 30 days unless the user signs in again.
func (s *Server) deleteMe(w http.ResponseWriter, r *http.Request) {
	ctx, c := r.Context(), claimsOf(r)
	err := pgx.BeginFunc(ctx, s.db.Auth, func(tx pgx.Tx) error {
		if _, err := tx.Exec(ctx, `update users set deleted_at = now() where id = $1`, c.Sub); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `delete from sessions where user_id = $1`, c.Sub); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `insert into audit_log (actor, action, target) values ($1,'account.delete',$1)`, c.Sub)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "purgeAfterDays": 30})
}
