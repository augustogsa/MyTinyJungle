package api

import (
	"context"
	"crypto/ed25519"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/simpleappscompany/mytinyjungle/server/internal/jwt"
)

type Server struct {
	cfg     Config
	db      *DB
	priv    ed25519.PrivateKey
	pubs    map[string]ed25519.PublicKey
	apple   *jwt.JWKS
	google  *jwt.JWKS
	access  *jwt.JWKS
	limiter *Limiter
	log     *slog.Logger
	now     func() time.Time
	play    *playClient
	pusher  *pusher
}

func New(cfg Config, db *DB, priv ed25519.PrivateKey, pubs map[string]ed25519.PublicKey, log *slog.Logger) *Server {
	s := &Server{
		cfg: cfg, db: db, priv: priv, pubs: pubs, log: log, now: time.Now,
		apple:   jwt.NewJWKS("https://appleid.apple.com/auth/keys"),
		google:  jwt.NewJWKS("https://www.googleapis.com/oauth2/v3/certs"),
		limiter: NewLimiter(),
	}
	if cfg.AccessTeam != "" {
		s.access = jwt.NewJWKS("https://" + cfg.AccessTeam + "/cdn-cgi/access/certs")
	}
	s.pusher = newPusher(cfg, db, log)
	if cfg.PlayPackage != "" && cfg.PlaySAFile != "" {
		s.play = newPlayClient(cfg.PlayPackage, cfg.PlaySAFile)
	}
	return s
}

// Rate classes: requests per minute.
const (
	rateAuthIP  = 20
	rateIP      = 600
	rateUser    = 240
	rateWebhook = 120
)

func (s *Server) Handler() http.Handler {
	m := http.NewServeMux()
	m.HandleFunc("GET /health", s.health)

	m.HandleFunc("GET /v1/content/manifest", s.contentManifest)
	m.HandleFunc("GET /v1/content/b/{name}", s.contentBlob)

	m.Handle("POST /v1/auth/signin", s.ipLimit(rateAuthIP, s.signIn))
	m.Handle("POST /v1/auth/refresh", s.ipLimit(rateAuthIP, s.refresh))
	m.Handle("POST /v1/auth/signout", s.user(s.signOut))
	m.Handle("POST /v1/auth/link", s.user(s.link))

	m.Handle("GET /v1/me", s.user(s.me))
	m.Handle("PATCH /v1/me", s.user(s.patchMe))
	m.Handle("PUT /v1/me/push-token", s.user(s.pushToken))
	m.Handle("DELETE /v1/me", s.user(s.deleteMe))

	m.Handle("GET /v1/jungles", s.user(s.jungles))
	m.Handle("POST /v1/jungles", s.user(s.createJungle))
	m.Handle("DELETE /v1/jungles/{id}", s.user(s.deleteJungle))
	m.Handle("POST /v1/jungles/{id}/invites", s.user(s.createInvite))
	m.Handle("POST /v1/invites/{code}/redeem", s.user(s.redeemInvite))
	m.Handle("PATCH /v1/jungles/{id}/members/{uid}", s.user(s.updateMember))
	m.Handle("DELETE /v1/jungles/{id}/members/{uid}", s.user(s.removeMember))

	m.Handle("GET /v1/jungles/{id}/house", s.user(s.getHouse))
	m.Handle("PUT /v1/jungles/{id}/house", s.user(s.putHouse))
	m.Handle("GET /v1/me/export", s.user(s.export))
	m.Handle("POST /v1/diagnostics", s.user(s.postDiagnostics))

	m.Handle("GET /v1/sync/pull", s.user(s.pull))
	m.Handle("POST /v1/sync/push", s.user(s.push))

	m.Handle("PUT /v1/media/{jungle}/{id}", s.user(s.putMedia))
	m.Handle("GET /v1/media/{jungle}/{id}", s.user(s.getMedia))
	m.Handle("DELETE /v1/media/{jungle}/{id}", s.user(s.deleteMedia))

	m.Handle("POST /v1/store/apple/transactions", s.user(s.appleTransaction))
	m.Handle("POST /v1/store/play/purchases", s.user(s.playPurchase))
	m.Handle("POST /storekit/notifications", s.ipLimit(rateWebhook, s.appleNotification))
	m.Handle("POST /play/rtdn", s.ipLimit(rateWebhook, s.playRTDN))

	m.Handle("GET /admin", s.admin(s.adminPage))
	m.Handle("GET /v1/admin/stats", s.admin(s.adminStats))
	m.Handle("GET /v1/admin/users", s.admin(s.adminUsers))
	m.Handle("GET /v1/admin/users/{id}", s.admin(s.adminUser))
	m.Handle("GET /v1/admin/store-events", s.admin(s.adminStoreEvents))
	m.Handle("GET /v1/admin/diagnostics", s.admin(s.adminDiagnostics))

	return s.wrap(m)
}

// wrap adds security headers, body limits, panic recovery and access logs (no IPs, no user ids).
func (s *Server) wrap(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		h := w.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Referrer-Policy", "no-referrer")
		h.Set("Cache-Control", "no-store")
		h.Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		h.Set("X-Frame-Options", "DENY")
		if !strings.HasPrefix(r.URL.Path, "/v1/media/") {
			r.Body = http.MaxBytesReader(w, r.Body, 2<<20)
		}
		rw := &statusWriter{ResponseWriter: w, code: 200}
		defer func() {
			if p := recover(); p != nil {
				s.log.Error("panic", "path", r.Pattern, "err", p)
				writeErr(rw, http.StatusInternalServerError, "internal")
			}
			s.log.Info("req", "m", r.Method, "route", r.Pattern, "status", rw.code, "ms", time.Since(start).Milliseconds())
		}()
		if !s.limiter.Allow("ip:"+clientIP(r), rateIP) {
			writeErr(rw, http.StatusTooManyRequests, "rate_limited")
			return
		}
		next.ServeHTTP(rw, r)
	})
}

type statusWriter struct {
	http.ResponseWriter
	code int
}

func (w *statusWriter) WriteHeader(c int) { w.code = c; w.ResponseWriter.WriteHeader(c) }

// clientIP trusts CF-Connecting-IP: the origin only accepts Cloudflare (authenticated origin pulls).
// Used only as a rate-limit key in memory, never stored or logged.
func clientIP(r *http.Request) string {
	if ip := r.Header.Get("CF-Connecting-IP"); ip != "" {
		return ip
	}
	return r.RemoteAddr
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	ok := s.db.App.Ping(ctx) == nil && s.db.Auth.Ping(ctx) == nil
	code := http.StatusOK
	if !ok {
		code = http.StatusServiceUnavailable
	}
	writeJSON(w, code, map[string]any{"service": "mytinyjungle-api", "release": s.cfg.Release, "db": ok})
}

func (s *Server) ipLimit(perMin int, h http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !s.limiter.Allow(r.Pattern+":"+clientIP(r), perMin) {
			writeErr(w, http.StatusTooManyRequests, "rate_limited")
			return
		}
		h(w, r)
	})
}

// ---- JSON helpers ----

type apiError struct {
	code   int
	reason string
}

func (e apiError) Error() string { return e.reason }

func bad(reason string) error { return apiError{http.StatusBadRequest, reason} }

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, code int, reason string) {
	writeJSON(w, code, map[string]string{"error": reason})
}

func (s *Server) fail(w http.ResponseWriter, r *http.Request, err error) {
	var ae apiError
	if errors.As(err, &ae) {
		writeErr(w, ae.code, ae.reason)
		return
	}
	var mbe *http.MaxBytesError
	if errors.As(err, &mbe) {
		writeErr(w, http.StatusRequestEntityTooLarge, "too_large")
		return
	}
	s.log.Error("handler", "route", r.Pattern, "err", err.Error())
	writeErr(w, http.StatusInternalServerError, "internal")
}

func decode(r *http.Request, v any) error {
	d := json.NewDecoder(r.Body)
	d.DisallowUnknownFields()
	if err := d.Decode(v); err != nil {
		var mbe *http.MaxBytesError
		if errors.As(err, &mbe) {
			return err
		}
		return bad("invalid_json")
	}
	if d.More() {
		return bad("invalid_json")
	}
	_, _ = io.Copy(io.Discard, r.Body)
	return nil
}

// ---- rate limiter: fixed one-minute windows, swept every minute ----

type Limiter struct {
	mu     sync.Mutex
	window int64
	counts map[string]int
}

func NewLimiter() *Limiter { return &Limiter{counts: map[string]int{}} }

func (l *Limiter) Allow(key string, perMin int) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	if w := time.Now().Unix() / 60; w != l.window {
		l.window, l.counts = w, map[string]int{}
	}
	l.counts[key]++
	return l.counts[key] <= perMin
}
