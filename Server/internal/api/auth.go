package api

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"net/http"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/simpleappscompany/mytinyjungle/server/internal/jwt"
)

type Claims struct {
	jwt.Std
	Dev string `json:"dev"`
}

type ctxKey struct{}

func claimsOf(r *http.Request) Claims { return r.Context().Value(ctxKey{}).(Claims) }

var uuidRe = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

func isUUID(s string) bool { return uuidRe.MatchString(s) }

func (s *Server) issueAccess(uid, dev string) (string, error) {
	now := s.now()
	aud, _ := json.Marshal("mtj-app")
	return jwt.SignEdDSA(s.priv, s.cfg.SigningKid, Claims{
		Std: jwt.Std{Iss: s.cfg.Issuer, Sub: uid, Aud: aud, Iat: now.Unix(), Exp: now.Add(s.cfg.AccessTTL).Unix()},
		Dev: dev,
	})
}

// user authenticates a bearer access token and applies the per-account rate limit.
func (s *Server) user(h http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tok, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok {
			writeErr(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		p, err := jwt.VerifyEdDSA(tok, s.pubs)
		var c Claims
		if err != nil || json.Unmarshal(p, &c) != nil ||
			c.Check([]string{s.cfg.Issuer}, []string{"mtj-app"}, s.now()) != nil || !isUUID(c.Sub) {
			writeErr(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		if !s.limiter.Allow("u:"+c.Sub, rateUser) {
			writeErr(w, http.StatusTooManyRequests, "rate_limited")
			return
		}
		h(w, r.WithContext(context.WithValue(r.Context(), ctxKey{}, c)))
	})
}

type tokens struct {
	UserID       string `json:"userId"`
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
	ExpiresIn    int    `json:"expiresIn"`
}

func hashToken(t string) []byte { h := sha256.Sum256([]byte(t)); return h[:] }

func randToken() string {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func (s *Server) newSession(ctx context.Context, tx pgx.Tx, uid, dev, family string) (tokens, error) {
	access, err := s.issueAccess(uid, dev)
	if err != nil {
		return tokens{}, err
	}
	refresh := randToken()
	if family == "" {
		_ = tx.QueryRow(ctx, `select gen_random_uuid()::text`).Scan(&family)
	}
	_, err = tx.Exec(ctx, `insert into sessions (token_hash, family_id, user_id, device_id, expires_at) values ($1,$2,$3,$4,$5)`,
		hashToken(refresh), family, uid, dev, s.now().Add(s.cfg.RefreshTTL))
	return tokens{uid, access, refresh, int(s.cfg.AccessTTL.Seconds())}, err
}

type providerID struct{ Subject, Email string }

func (s *Server) verifyProvider(provider, token string) (providerID, error) {
	var (
		p   []byte
		err error
		iss []string
		aud []string
	)
	switch provider {
	case "apple":
		p, err = jwt.VerifyRS256(token, s.apple.Key)
		iss, aud = []string{"https://appleid.apple.com"}, s.cfg.AppleAud
	case "google":
		p, err = jwt.VerifyRS256(token, s.google.Key)
		iss, aud = []string{"https://accounts.google.com", "accounts.google.com"}, s.cfg.GoogleAud
	default:
		return providerID{}, bad("unknown_provider")
	}
	if err != nil || len(aud) == 0 {
		return providerID{}, apiError{http.StatusUnauthorized, "invalid_identity_token"}
	}
	var c struct {
		jwt.Std
		Email string `json:"email"`
	}
	if json.Unmarshal(p, &c) != nil || c.Check(iss, aud, s.now()) != nil || c.Sub == "" {
		return providerID{}, apiError{http.StatusUnauthorized, "invalid_identity_token"}
	}
	return providerID{c.Sub, strings.ToLower(c.Email)}, nil
}

type deviceIn struct {
	DeviceID   string `json:"deviceId"`
	Platform   string `json:"platform"`
	Model      string `json:"model"`
	AppVersion string `json:"appVersion"`
}

func (d deviceIn) valid() bool {
	return isUUID(d.DeviceID) && slices.Contains([]string{"ios", "android", "web"}, d.Platform) &&
		len(d.Model) <= 80 && len(d.AppVersion) <= 40
}

func (s *Server) signIn(w http.ResponseWriter, r *http.Request) {
	var in struct {
		deviceIn
		Provider string `json:"provider"`
		IDToken  string `json:"idToken"`
		Name     string `json:"name"`
	}
	if err := decode(r, &in); err != nil {
		s.fail(w, r, err)
		return
	}
	if !in.valid() || len(in.IDToken) < 20 || len(in.Name) > 60 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	id, err := s.verifyProvider(in.Provider, in.IDToken)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	ctx := r.Context()
	var out tokens
	err = pgx.BeginFunc(ctx, s.db.Auth, func(tx pgx.Tx) error {
		var uid string
		var deleted *time.Time
		err := tx.QueryRow(ctx, `select u.id, u.deleted_at from identities i join users u on u.id = i.user_id
			where i.provider = $1 and i.subject = $2`, in.Provider, id.Subject).Scan(&uid, &deleted)
		switch {
		case isNoRows(err):
			if err := tx.QueryRow(ctx, `insert into users (email, display_name) values (nullif($1,''), nullif($2,'')) returning id`,
				id.Email, in.Name).Scan(&uid); err != nil {
				return err
			}
			if _, err := tx.Exec(ctx, `insert into identities (provider, subject, user_id, email) values ($1,$2,$3,nullif($4,''))`,
				in.Provider, id.Subject, uid, id.Email); err != nil {
				return err
			}
		case err != nil:
			return err
		case deleted != nil:
			// Signing in during the 30-day grace period restores the account.
			if _, err := tx.Exec(ctx, `update users set deleted_at = null where id = $1`, uid); err != nil {
				return err
			}
		}
		if _, err := tx.Exec(ctx, `insert into devices (id, user_id, platform, model, app_version, last_seen_at)
			values ($1,$2,$3,nullif($4,''),nullif($5,''), now())
			on conflict (id) do update set user_id = excluded.user_id, platform = excluded.platform, model = excluded.model,
			  app_version = excluded.app_version, push_token = case when devices.user_id = excluded.user_id then devices.push_token end,
			  last_seen_at = now()`, in.DeviceID, uid, in.Platform, in.Model, in.AppVersion); err != nil {
			return err
		}
		// One live session family per device.
		if _, err := tx.Exec(ctx, `delete from sessions where device_id = $1`, in.DeviceID); err != nil {
			return err
		}
		out, err = s.newSession(ctx, tx, uid, in.DeviceID, "")
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) refresh(w http.ResponseWriter, r *http.Request) {
	var in struct {
		RefreshToken string `json:"refreshToken"`
	}
	if err := decode(r, &in); err != nil || len(in.RefreshToken) < 20 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx := r.Context()
	var out tokens
	revoked := false
	err := pgx.BeginFunc(ctx, s.db.Auth, func(tx pgx.Tx) error {
		var uid, dev, family string
		var used *time.Time
		var expires time.Time
		err := tx.QueryRow(ctx, `select s.user_id, s.device_id, s.family_id, s.used_at, s.expires_at
			from sessions s join users u on u.id = s.user_id
			where s.token_hash = $1 and u.deleted_at is null for update of s`, hashToken(in.RefreshToken)).
			Scan(&uid, &dev, &family, &used, &expires)
		if err != nil {
			return err
		}
		if used != nil && s.now().Sub(*used) < 30*time.Second {
			// Network retry of the same refresh (lost response, replay): rotate again in the same family.
			out, err = s.newSession(ctx, tx, uid, dev, family)
			return err
		}
		if used != nil {
			// A rotated token came back later: someone else has a copy. Revoke every session of this user.
			if _, err := tx.Exec(ctx, `delete from sessions where user_id = $1`, uid); err != nil {
				return err
			}
			_, err := tx.Exec(ctx, `insert into audit_log (actor, action, target) values ('system','session.reuse_revoke',$1)`, uid)
			revoked = true
			return err
		}
		if expires.Before(s.now()) {
			return pgx.ErrNoRows
		}
		if _, err := tx.Exec(ctx, `update sessions set used_at = now() where token_hash = $1`, hashToken(in.RefreshToken)); err != nil {
			return err
		}
		// Keep used tokens of this family only until they would have expired anyway (reuse detection window).
		if _, err := tx.Exec(ctx, `delete from sessions where family_id = $1 and used_at < now() - interval '30 days'`, family); err != nil {
			return err
		}
		_, _ = tx.Exec(ctx, `update devices set last_seen_at = now() where id = $1`, dev)
		out, err = s.newSession(ctx, tx, uid, dev, family)
		return err
	})
	if err == nil && revoked {
		writeErr(w, http.StatusUnauthorized, "session_revoked")
		return
	}
	if isNoRows(err) {
		writeErr(w, http.StatusUnauthorized, "invalid_refresh")
		return
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) signOut(w http.ResponseWriter, r *http.Request) {
	c := claimsOf(r)
	if _, err := s.db.Auth.Exec(r.Context(), `delete from sessions where user_id = $1 and device_id = $2`, c.Sub, c.Dev); err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// link attaches another provider to the signed-in account (Apple on iPhone + Google on Android = one account).
func (s *Server) link(w http.ResponseWriter, r *http.Request) {
	var in struct{ Provider, IDToken string }
	if err := decode(r, &in); err != nil {
		s.fail(w, r, err)
		return
	}
	id, err := s.verifyProvider(in.Provider, in.IDToken)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	uid := claimsOf(r).Sub
	var owner string
	err = s.db.Auth.QueryRow(r.Context(), `select user_id from identities where provider = $1 and subject = $2`, in.Provider, id.Subject).Scan(&owner)
	switch {
	case err == nil && owner != uid:
		writeErr(w, http.StatusConflict, "identity_in_use")
		return
	case err == nil:
	case isNoRows(err):
		if _, err := s.db.Auth.Exec(r.Context(), `insert into identities (provider, subject, user_id, email) values ($1,$2,$3,nullif($4,''))`,
			in.Provider, id.Subject, uid, id.Email); err != nil {
			s.fail(w, r, err)
			return
		}
	default:
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// TestToken finds or creates a user with this email (provider "apple", subject "test:<email>") and returns
// an access token for a fixed test device. Only reachable through the root-only CLI.
func (s *Server) TestToken(ctx context.Context, email string) (string, error) {
	var uid string
	err := pgx.BeginFunc(ctx, s.db.Auth, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx, `select user_id from identities where provider = 'apple' and subject = $1`, "test:"+email).Scan(&uid)
		if isNoRows(err) {
			if err := tx.QueryRow(ctx, `insert into users (email, display_name) values ($1, 'Test') returning id`, email).Scan(&uid); err != nil {
				return err
			}
			_, err = tx.Exec(ctx, `insert into identities (provider, subject, user_id, email) values ('apple',$1,$2,$3)`, "test:"+email, uid, email)
		}
		return err
	})
	if err != nil {
		return "", err
	}
	dev := "00000000-0000-4000-8000-" + uid[24:]
	_, _ = s.db.Auth.Exec(ctx, `insert into devices (id, user_id, platform) values ($1,$2,'ios') on conflict (id) do nothing`, dev, uid)
	return s.issueAccess(uid, dev)
}
