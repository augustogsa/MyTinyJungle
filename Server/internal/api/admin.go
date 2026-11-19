package api

import (
	_ "embed"
	"encoding/json"
	"net/http"
	"slices"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/simpleappscompany/mytinyjungle/server/internal/jwt"
)

//go:embed admin.html
var adminHTML []byte

// admin requires a Cloudflare Access login (Zero Trust, email + one-time code / authenticator) whose
// email is on MTJ_ADMIN_EMAILS. The Access JWT is verified here too, so a request that skips the edge fails.
func (s *Server) admin(h http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s.access == nil || s.cfg.AccessAud == "" {
			writeErr(w, http.StatusServiceUnavailable, "admin_not_configured")
			return
		}
		tok := r.Header.Get("Cf-Access-Jwt-Assertion")
		p, err := jwt.VerifyRS256(tok, s.access.Key)
		var c struct {
			jwt.Std
			Email string `json:"email"`
		}
		if err != nil || json.Unmarshal(p, &c) != nil ||
			c.Check([]string{"https://" + s.cfg.AccessTeam}, []string{s.cfg.AccessAud}, s.now()) != nil ||
			!slices.Contains(s.cfg.AdminEmails, strings.ToLower(c.Email)) {
			writeErr(w, http.StatusForbidden, "forbidden")
			return
		}
		if !s.limiter.Allow("admin:"+c.Email, rateUser) {
			writeErr(w, http.StatusTooManyRequests, "rate_limited")
			return
		}
		h(w, r)
	})
}

func (s *Server) adminPage(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Content-Security-Policy", "default-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'")
	_, _ = w.Write(adminHTML)
}

func (s *Server) adminStats(w http.ResponseWriter, r *http.Request) {
	var out struct {
		Users, New7d, Active24h, Active30d, IOS, Android, Shared, Plants, Events, Plus, Deleted int
	}
	err := s.db.Admin.QueryRow(r.Context(), `select
		(select count(*) from users where deleted_at is null),
		(select count(*) from users where created_at > now() - interval '7 days'),
		(select count(distinct user_id) from devices where last_seen_at > now() - interval '1 day'),
		(select count(distinct user_id) from devices where last_seen_at > now() - interval '30 days'),
		(select count(*) from devices where platform = 'ios'),
		(select count(*) from devices where platform = 'android'),
		(select count(*) from jungles where not is_personal),
		(select count(*) from records where entity = 'plant' and not deleted),
		(select count(*) from records where entity = 'care_event' and not deleted),
		(select count(distinct user_id) from entitlements where status in ('active','grace') and (expires_at is null or expires_at > now())),
		(select count(*) from users where deleted_at is not null)`).
		Scan(&out.Users, &out.New7d, &out.Active24h, &out.Active30d, &out.IOS, &out.Android, &out.Shared, &out.Plants, &out.Events, &out.Plus, &out.Deleted)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]int{"users": out.Users, "newUsers7d": out.New7d, "activeUsers24h": out.Active24h,
		"activeUsers30d": out.Active30d, "iosDevices": out.IOS, "androidDevices": out.Android, "sharedJungles": out.Shared,
		"plants": out.Plants, "careEvents": out.Events, "plusUsers": out.Plus, "pendingDeletion": out.Deleted})
}

func (s *Server) adminUsers(w http.ResponseWriter, r *http.Request) {
	type row struct {
		ID          string     `json:"id"`
		Email       *string    `json:"email"`
		DisplayName *string    `json:"displayName"`
		CreatedAt   time.Time  `json:"createdAt"`
		DeletedAt   *time.Time `json:"deletedAt"`
		LastSeen    *time.Time `json:"lastSeen"`
		Platforms   *string    `json:"platforms"`
		Plus        bool       `json:"plus"`
	}
	q := "%" + strings.ReplaceAll(strings.ReplaceAll(r.URL.Query().Get("q"), "%", ""), "_", "") + "%"
	rows, _ := s.db.Admin.Query(r.Context(), `select u.id, u.email, u.display_name, u.created_at, u.deleted_at,
		(select max(last_seen_at) from devices d where d.user_id = u.id),
		(select string_agg(distinct platform, ',') from devices d where d.user_id = u.id),
		exists (select 1 from entitlements e where e.user_id = u.id and e.status in ('active','grace') and (e.expires_at is null or e.expires_at > now()))
		from users u where coalesce(u.email,'') ilike $1 or coalesce(u.display_name,'') ilike $1 or u.id::text ilike $1
		order by u.created_at desc limit 200`, q)
	out, err := pgx.CollectRows(rows, func(rw pgx.CollectableRow) (row, error) {
		var x row
		return x, rw.Scan(&x.ID, &x.Email, &x.DisplayName, &x.CreatedAt, &x.DeletedAt, &x.LastSeen, &x.Platforms, &x.Plus)
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if out == nil {
		out = []row{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"users": out})
}

func (s *Server) adminUser(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if !isUUID(id) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx := r.Context()
	asJSON := func(sql string) (json.RawMessage, error) {
		var b json.RawMessage
		err := s.db.Admin.QueryRow(ctx, `select coalesce(json_agg(t), '[]'::json) from (`+sql+`) t`, id).Scan(&b)
		return b, err
	}
	out := map[string]json.RawMessage{}
	for k, q := range map[string]string{
		"user":         `select id, email, display_name, locale, created_at, deleted_at from users where id = $1`,
		"identities":   `select provider, email, created_at from identities where user_id = $1`,
		"devices":      `select id, platform, model, app_version, last_seen_at, push_token is not null as push from devices where user_id = $1 order by last_seen_at desc`,
		"jungles":      `select j.id, j.name, j.is_personal, m.role, m.until, (select count(*) from records x where x.jungle_id = j.id and x.entity = 'plant' and not x.deleted) as plants from jungle_members m join jungles j on j.id = m.jungle_id where m.user_id = $1`,
		"entitlements": `select store, product_id, status, expires_at, environment, updated_at from entitlements where user_id = $1`,
	} {
		b, err := asJSON(q)
		if err != nil {
			s.fail(w, r, err)
			return
		}
		out[k] = b
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) adminStoreEvents(w http.ResponseWriter, r *http.Request) {
	var b json.RawMessage
	err := s.db.Admin.QueryRow(r.Context(), `select coalesce(json_agg(t), '[]'::json) from
		(select id, store, notification_type, verified, received_at from store_notifications order by id desc limit 100) t`).Scan(&b)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]json.RawMessage{"events": b})
}
