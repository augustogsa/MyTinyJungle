package api

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
	"time"
)

// Abuse limits and cost guards.
//   - Daily quotas per user and per device on the brain endpoints (api_quota), 429 {"error":"daily_limit"}.
//   - A cap on concurrent brain requests (503 {"error":"busy"} after a short wait), and a cap on concurrent
//     calls into each local model (llama.cpp 8091, BioCLIP 8092), so the VPS can't be overloaded.
//   - A monthly cap on paid model calls (Gemini, Claude): MTJ_AI_MONTHLY_CAP calls per month in total
//     (default 3000, 0 = paid tiers off). Over the cap the paid call fails fast and the brain uses its own answer.
// The model guards sit on http.DefaultClient's transport, which every brain call (and the Anthropic SDK) uses.

var dailyQuota = map[string]struct {
	kind string
	n    int
}{
	"/v1/brain/scene":          {"scene", 60},
	"/v1/brain/identify":       {"identify", 60},
	"/v1/brain/identify-batch": {"identify", 60}, // plus one per extra crop (chargeQuota)
	"/v1/brain/ask":            {"ask", 300},
	"/v1/diagnose":             {"diagnose", 20},
}

var (
	brainSlots = make(chan struct{}, envInt("MTJ_BRAIN_CONCURRENCY", 4))
	modelSlots = map[string]chan struct{}{
		"127.0.0.1:8091": make(chan struct{}, envInt("MTJ_VLM_CONCURRENCY", 2)),
		"127.0.0.1:8092": make(chan struct{}, envInt("MTJ_ID_CONCURRENCY", 2)),
	}
	paidHosts = map[string]string{"api.anthropic.com": "claude", "generativelanguage.googleapis.com": "gemini"}
	guardSrv  atomic.Pointer[Server]
	guardOnce sync.Once
	spendStop atomic.Int64 // unix time until which paid calls are known to be over the cap
	busyCount atomic.Int64
)

func envInt(k string, d int) int {
	if v, err := strconv.Atoi(os.Getenv(k)); err == nil && v >= 0 {
		return v
	}
	return d
}

func monthlyCap() int { return envInt("MTJ_AI_MONTHLY_CAP", 3000) }

// installGuards puts the model guards on http.DefaultClient (once per process).
func installGuards(s *Server) {
	guardSrv.Store(s)
	guardOnce.Do(func() {
		base := http.DefaultClient.Transport
		if base == nil {
			base = http.DefaultTransport
		}
		http.DefaultClient.Transport = guardTransport{base}
	})
}

// guard applies the daily quota and the brain concurrency cap. ok=false means the response was written.
func (s *Server) guard(w http.ResponseWriter, r *http.Request, c Claims) (release func(), ok bool) {
	q, limited := dailyQuota[r.URL.Path]
	if !limited || r.Method != http.MethodPost {
		return func() {}, true
	}
	if s.db != nil && s.db.Auth != nil {
		subjects := []string{"u:" + c.Sub}
		if c.Dev != "" {
			subjects = append(subjects, "d:"+c.Dev)
		}
		for _, sub := range subjects {
			var n int
			err := s.db.Auth.QueryRow(r.Context(), `insert into api_quota (subject, kind, n) values ($1, $2, 1)
				on conflict (day, subject, kind) do update set n = api_quota.n + 1 returning n`, sub, q.kind).Scan(&n)
			if err == nil && n > q.n {
				writeErr(w, http.StatusTooManyRequests, "daily_limit")
				return nil, false
			}
		}
	}
	t := time.NewTimer(20 * time.Second)
	defer t.Stop()
	select {
	case brainSlots <- struct{}{}:
		return func() { <-brainSlots }, true
	case <-t.C:
		busyCount.Add(1)
		writeErr(w, http.StatusServiceUnavailable, "busy")
		return nil, false
	case <-r.Context().Done():
		return nil, false
	}
}

type guardTransport struct{ base http.RoundTripper }

func (g guardTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	if sem, ok := modelSlots[req.URL.Host]; ok {
		select {
		case sem <- struct{}{}:
			defer func() { <-sem }()
		case <-req.Context().Done():
			return nil, req.Context().Err()
		}
		return g.base.RoundTrip(req)
	}
	if provider, ok := paidHosts[req.URL.Host]; ok && !allowPaid(req.Context(), provider) {
		return &http.Response{StatusCode: http.StatusForbidden, Status: "403 Forbidden", Proto: "HTTP/1.1", ProtoMajor: 1, ProtoMinor: 1,
			Header: http.Header{"Content-Type": {"application/json"}}, Request: req,
			Body: io.NopCloser(bytes.NewReader([]byte(`{"error":{"type":"monthly_cap","message":"paid model monthly cap reached"}}`)))}, nil
	}
	return g.base.RoundTrip(req)
}

// allowPaid counts one paid call this month if the total is under the cap.
func allowPaid(ctx context.Context, provider string) bool {
	limit := monthlyCap()
	if limit == 0 {
		return false
	}
	s := guardSrv.Load()
	if s == nil || s.db == nil || s.db.Auth == nil {
		return true
	}
	if time.Now().Unix() < spendStop.Load() {
		recordBlocked(ctx, s, provider)
		return false
	}
	var used int
	_ = s.db.Auth.QueryRow(ctx, `select coalesce(sum(n), 0) from ai_spend where month = date_trunc('month', current_date)::date`).Scan(&used)
	if used >= limit {
		spendStop.Store(time.Now().Add(5 * time.Minute).Unix())
		recordBlocked(ctx, s, provider)
		return false
	}
	_, _ = s.db.Auth.Exec(context.WithoutCancel(ctx), `insert into ai_spend (month, provider, n) values (date_trunc('month', current_date)::date, $1, 1)
		on conflict (month, provider) do update set n = ai_spend.n + 1`, provider)
	return true
}

func recordBlocked(ctx context.Context, s *Server, provider string) {
	_, _ = s.db.Auth.Exec(context.WithoutCancel(ctx), `insert into ai_spend (month, provider, blocked) values (date_trunc('month', current_date)::date, $1, 1)
		on conflict (month, provider) do update set blocked = ai_spend.blocked + 1`, provider)
}

// adminLimits: GET /v1/admin/limits — quotas, today's use, who hit a limit, paid spend this month, live load.
func (s *Server) adminLimits(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	type kindUse struct {
		Kind     string `json:"kind"`
		Limit    int    `json:"limit"`
		Calls    int    `json:"calls"`
		Users    int    `json:"users"`
		AtLimit  int    `json:"atLimit"`
		MaxByOne int    `json:"maxByOne"`
	}
	var kinds []kindUse
	for _, q := range []string{"scene", "identify", "ask", "diagnose"} {
		k := kindUse{Kind: q}
		for _, d := range dailyQuota {
			if d.kind == q {
				k.Limit = d.n
			}
		}
		_ = s.db.Admin.QueryRow(ctx, `select coalesce(sum(n), 0), count(*), count(*) filter (where n >= $2), coalesce(max(n), 0)
			from api_quota where day = current_date and kind = $1 and subject like 'u:%'`, q, k.Limit).Scan(&k.Calls, &k.Users, &k.AtLimit, &k.MaxByOne)
		kinds = append(kinds, k)
	}
	type spend struct {
		Provider string `json:"provider"`
		Calls    int    `json:"calls"`
		Blocked  int    `json:"blocked"`
	}
	spends := []spend{}
	rows, err := s.db.Admin.Query(ctx, `select provider, n, blocked from ai_spend where month = date_trunc('month', current_date)::date order by provider`)
	if err == nil {
		for rows.Next() {
			var sp spend
			if rows.Scan(&sp.Provider, &sp.Calls, &sp.Blocked) == nil {
				spends = append(spends, sp)
			}
		}
		rows.Close()
	}
	var digestOn, digestOff, digestSent7d int
	_ = s.db.Admin.QueryRow(ctx, `select count(*) filter (where digest_on and push_token is not null), count(*) filter (where not digest_on),
		count(*) filter (where digest_sent_at > now() - interval '7 days') from devices`).Scan(&digestOn, &digestOff, &digestSent7d)
	writeJSON(w, http.StatusOK, map[string]any{
		"today": kinds,
		"paid":  map[string]any{"monthlyCap": monthlyCap(), "month": spends},
		"load": map[string]any{"brainInFlight": len(brainSlots), "brainMax": cap(brainSlots),
			"vlmInFlight": len(modelSlots["127.0.0.1:8091"]), "idInFlight": len(modelSlots["127.0.0.1:8092"]), "busySinceStart": busyCount.Load()},
		"digest": map[string]int{"devicesOn": digestOn, "devicesOff": digestOff, "sent7d": digestSent7d},
	})
}
