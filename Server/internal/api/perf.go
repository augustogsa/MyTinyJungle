package api

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/andybalholm/brotli"
)

// Performance: per-route latency (p50/p95), error rate, cache-hit rate and paid model use, in memory.
// Hourly buckets for 7 days; a route whose last-hour p95 is clearly worse than its trailing day logs
// "p95_regression" (WARN), which the watchdog turns into an alert email (mtj-alert.sh).

type perfBucket struct {
	ms   []int32
	errs int
}

var perf = struct {
	sync.Mutex
	hours  map[int64]map[string]*perfBucket // unix hour -> route -> samples
	hits   map[string][2]int64              // cache -> {hits, misses} since start
	warned map[string]time.Time
}{hours: map[int64]map[string]*perfBucket{}, hits: map[string][2]int64{}, warned: map[string]time.Time{}}

func perfObserve(route string, ms int64, status int) {
	if route == "" {
		route = "other"
	}
	h := time.Now().Unix() / 3600
	perf.Lock()
	defer perf.Unlock()
	m := perf.hours[h]
	if m == nil {
		m = map[string]*perfBucket{}
		perf.hours[h] = m
		for k := range perf.hours {
			if k < h-24*7 {
				delete(perf.hours, k)
			}
		}
	}
	b := m[route]
	if b == nil {
		b = &perfBucket{}
		m[route] = b
	}
	if len(b.ms) < 20000 {
		b.ms = append(b.ms, int32(ms))
	}
	if status >= 500 {
		b.errs++
	}
}

func perfCache(name string, hit bool) {
	perf.Lock()
	c := perf.hits[name]
	if hit {
		c[0]++
	} else {
		c[1]++
	}
	perf.hits[name] = c
	perf.Unlock()
}

func pct(xs []int32, p float64) int32 {
	if len(xs) == 0 {
		return 0
	}
	s := append([]int32(nil), xs...)
	sort.Slice(s, func(i, j int) bool { return s[i] < s[j] })
	return s[min(len(s)-1, int(float64(len(s))*p))]
}

type routePerf struct {
	Route   string  `json:"route"`
	N       int     `json:"n"`
	P50     int32   `json:"p50Ms"`
	P95     int32   `json:"p95Ms"`
	ErrRate float64 `json:"errorRate"`
}

// perfWindow summarises the hours [from, to) per route.
func perfWindow(from, to int64) map[string]routePerf {
	perf.Lock()
	defer perf.Unlock()
	all := map[string]*perfBucket{}
	for h, m := range perf.hours {
		if h < from || h >= to {
			continue
		}
		for r, b := range m {
			a := all[r]
			if a == nil {
				a = &perfBucket{}
				all[r] = a
			}
			a.ms = append(a.ms, b.ms...)
			a.errs += b.errs
		}
	}
	out := map[string]routePerf{}
	for r, b := range all {
		out[r] = routePerf{r, len(b.ms), pct(b.ms, 0.5), pct(b.ms, 0.95), float64(b.errs) / float64(max(1, len(b.ms)))}
	}
	return out
}

// GET /v1/admin/perf: last hour and last 24 h per route, cache-hit rates, paid model calls this month.
func (s *Server) adminPerf(w http.ResponseWriter, r *http.Request) {
	h := time.Now().Unix() / 3600
	list := func(m map[string]routePerf) []routePerf {
		var l []routePerf
		for _, v := range m {
			l = append(l, v)
		}
		sort.Slice(l, func(i, j int) bool { return l[i].N > l[j].N })
		return l
	}
	perf.Lock()
	caches := map[string]any{}
	for k, c := range perf.hits {
		caches[k] = map[string]any{"hits": c[0], "misses": c[1], "hitRate": float64(c[0]) / float64(max(1, c[0]+c[1]))}
	}
	perf.Unlock()
	cost := map[string]int{}
	if s.db != nil && s.db.Auth != nil {
		if rows, err := s.db.Auth.Query(r.Context(), `select provider, n from ai_spend where month = date_trunc('month', current_date)::date`); err == nil {
			for rows.Next() {
				var p string
				var n int
				if rows.Scan(&p, &n) == nil {
					cost[p] = n
				}
			}
			rows.Close()
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"lastHour": list(perfWindow(h, h+1)), "last24h": list(perfWindow(h-23, h+1)),
		"caches": caches, "paidCallsThisMonth": cost, "paidCap": monthlyCap()})
}

// perfLoop: every 10 minutes, compare each route's last-60-minute p95 with the 24 hours before it.
func (s *Server) perfLoop(ctx context.Context) {
	t := time.NewTicker(10 * time.Minute)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
		h := time.Now().Unix() / 3600
		now, base := perfWindow(h, h+1), perfWindow(h-24, h)
		for r, p := range now {
			b, ok := base[r]
			if !ok || p.N < 20 || b.N < 50 {
				continue
			}
			if float64(p.P95) > 1.5*float64(b.P95) && p.P95-b.P95 > 300 {
				perf.Lock()
				last := perf.warned[r]
				fresh := time.Since(last) > 6*time.Hour
				if fresh {
					perf.warned[r] = time.Now()
				}
				perf.Unlock()
				if fresh {
					s.log.Warn("p95_regression", "route", r, "p95Ms", p.P95, "baselineMs", b.P95, "n", p.N)
				}
			}
		}
	}
}

// ---- compression ----

// compressWriter brotli- or gzip-encodes JSON and HTML responses (not event streams, media or tiny bodies).
type compressWriter struct {
	http.ResponseWriter
	enc     string
	w       io.WriteCloser
	decided bool
	code    int
}

func (c *compressWriter) WriteHeader(code int) {
	if c.decided {
		return
	}
	c.decided = true
	c.code = code
	ct := c.Header().Get("Content-Type")
	if code != http.StatusNotModified && code != http.StatusNoContent && c.Header().Get("Content-Encoding") == "" &&
		(strings.HasPrefix(ct, "application/json") || strings.HasPrefix(ct, "text/html")) {
		h := c.Header()
		h.Set("Content-Encoding", c.enc)
		h.Add("Vary", "Accept-Encoding")
		h.Del("Content-Length")
		if c.enc == "br" {
			c.w = brotli.NewWriterLevel(c.ResponseWriter, 4)
		} else {
			c.w, _ = gzip.NewWriterLevel(c.ResponseWriter, gzip.BestSpeed)
		}
	}
	c.ResponseWriter.WriteHeader(code)
}

func (c *compressWriter) Write(b []byte) (int, error) {
	if !c.decided {
		if c.Header().Get("Content-Type") == "" {
			c.Header().Set("Content-Type", http.DetectContentType(b))
		}
		c.WriteHeader(http.StatusOK)
	}
	if c.w != nil {
		return c.w.Write(b)
	}
	return c.ResponseWriter.Write(b)
}

func (c *compressWriter) Flush() {
	if f, ok := c.w.(interface{ Flush() error }); ok {
		f.Flush()
	}
	if f, ok := c.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

func (c *compressWriter) close() {
	if c.w != nil {
		c.w.Close()
	}
}

func acceptEnc(r *http.Request) string {
	ae := r.Header.Get("Accept-Encoding")
	switch {
	case strings.Contains(r.Header.Get("Accept"), "text/event-stream"), strings.HasPrefix(r.URL.Path, "/v1/media/"):
		return ""
	case strings.Contains(ae, "br"):
		return "br"
	case strings.Contains(ae, "gzip"):
		return "gzip"
	}
	return ""
}

// ---- ETag ----

type bufWriter struct {
	h    http.Header
	code int
	buf  bytes.Buffer
}

func (b *bufWriter) Header() http.Header         { return b.h }
func (b *bufWriter) WriteHeader(c int)           { b.code = c }
func (b *bufWriter) Write(p []byte) (int, error) { return b.buf.Write(p) }

// etag: a strong validator on a GET's body; If-None-Match that matches gets 304 with no body.
func etag(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		bw := &bufWriter{h: http.Header{}, code: 200}
		h.ServeHTTP(bw, r)
		for k, v := range bw.h {
			w.Header()[k] = v
		}
		if bw.code != http.StatusOK {
			w.WriteHeader(bw.code)
			w.Write(bw.buf.Bytes())
			return
		}
		sum := sha256.Sum256(bw.buf.Bytes())
		tag := `"` + hex.EncodeToString(sum[:12]) + `"`
		w.Header().Set("ETag", tag)
		w.Header().Set("Cache-Control", "private, no-cache")
		for _, t := range strings.Split(r.Header.Get("If-None-Match"), ",") {
			if t = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(t), "W/")); t == tag {
				w.WriteHeader(http.StatusNotModified)
				return
			}
		}
		w.WriteHeader(http.StatusOK)
		w.Write(bw.buf.Bytes())
	})
}
