package api

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"io"
	"math/rand/v2"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

// GET /v1/brain/config?lang=pt-BR (X-MTJ-Device: install id, optional): everything the apps' brain can be tuned by
// without a build. Defaults below; the admin overlay (brain_config.body) deep-merges on top:
//
//	{"base": {...any part of the config...},
//	 "lang": {"pt": {...}, "pt-BR": {...}},              // copy per language: exact tag, then its prefix
//	 "experiments": [{"name": "bands", "variants": [{"name": "a", "weight": 50, "set": {...}}, ...]}]}
//
// The reply carries "experiments": {name: variant} so outcomes can be read per variant. Apps cache it (ETag) and
// fall back to the last copy, then to their bundled defaults. Copy fields (word, title, text, hints, howTo) are only
// sent when the overlay has them; the apps' own localized strings are the default.
func (s *Server) brainConfig(w http.ResponseWriter, r *http.Request) {
	lang := r.URL.Query().Get("lang")
	if len(lang) > 12 {
		lang = ""
	}
	cfg, exps := buildBrainConfig(s.brainOverlay(r.Context()), lang, r.Header.Get("X-MTJ-Device"))
	cfg["experiments"] = exps
	writeJSON(w, http.StatusOK, cfg)
}

func brainConfigDefaults() map[string]any {
	return map[string]any{
		"v":     1,
		"scene": map[string]any{"sure": 0.6, "timeoutS": 15},
		"identify": map[string]any{
			"timeoutS": 12, "remoteTimeoutS": 12, "minRevealS": 1.6, "maxCandidates": 3, "maxTips": 3, "onDeviceCandidates": true,
			"bands": []any{
				map[string]any{"id": "veryLikely", "min": 0.8, "tone": "good"},
				map[string]any{"id": "likely", "min": 0.5, "tone": "good"},
				map[string]any{"id": "couldBe", "min": 0, "tone": "warn"},
			},
		},
		"diagnose": map[string]any{"maxTips": 3},
		"ask":      map[string]any{"server": true, "feedback": true},
		"scan": map[string]any{
			"cap": 8, "usefulMin": 0.1, "repeatBonus": 0.04, "floor": 0.2,
			"plans": map[string]any{
				"identify": map[string]any{
					"order":   []any{"leaf", "whole", "flower", "stem", "underside", "pot", "soil", "roots", "other"},
					"weights": map[string]any{"leaf": 0.35, "whole": 0.3, "flower": 0.2, "stem": 0.1, "underside": 0.05},
					"other":   0.03,
				},
				"doctor": map[string]any{
					"order":   []any{"leaf", "whole", "underside", "soil", "pot", "stem", "roots", "flower", "other"},
					"weights": map[string]any{"leaf": 0.3, "whole": 0.2, "underside": 0.2, "soil": 0.15, "pot": 0.1, "stem": 0.05, "roots": 0.05},
					"other":   0.03,
				},
			},
		},
		"flags": map[string]any{"serverIdentify": true, "serverDiagnose": true, "serverCarePlan": true},
		"cards": []any{},
	}
}

// buildBrainConfig: defaults ← overlay.base ← overlay.lang[prefix] ← overlay.lang[tag] ← each experiment's variant.
func buildBrainConfig(overlay map[string]any, lang, device string) (map[string]any, map[string]string) {
	cfg := brainConfigDefaults()
	if b, ok := overlay["base"].(map[string]any); ok {
		cfg = deepMerge(cfg, b)
	}
	if ls, ok := overlay["lang"].(map[string]any); ok && lang != "" {
		pre, _, _ := strings.Cut(lang, "-")
		if m, ok := ls[pre].(map[string]any); ok {
			cfg = deepMerge(cfg, m)
		}
		if m, ok := ls[lang].(map[string]any); ok && lang != pre {
			cfg = deepMerge(cfg, m)
		}
	}
	exps := map[string]string{}
	for name, v := range pickVariants(overlay, device) {
		exps[name] = v.name
		if v.set != nil {
			cfg = deepMerge(cfg, v.set)
		}
	}
	if cards, ok := cfg["cards"].([]any); ok {
		cfg["cards"] = liveCards(cards, lang, time.Now())
	}
	return cfg, exps
}

type variant struct {
	name string
	set  map[string]any
}

// pickVariants: a stable variant per experiment for this install (sha256 of device+name over the weights).
// No device id: the first variant (control).
func pickVariants(overlay map[string]any, device string) map[string]variant {
	out := map[string]variant{}
	list, _ := overlay["experiments"].([]any)
	for _, e := range list {
		em, _ := e.(map[string]any)
		name, _ := em["name"].(string)
		vs, _ := em["variants"].([]any)
		if name == "" || len(vs) == 0 {
			continue
		}
		var total float64
		for _, v := range vs {
			vm, _ := v.(map[string]any)
			total += weightOf(vm)
		}
		roll := 0.0
		if device != "" && total > 0 {
			h := sha256.Sum256([]byte(device + "\x1f" + name))
			roll = float64(binary.BigEndian.Uint64(h[:8])%1_000_000) / 1_000_000 * total
		}
		for i, v := range vs {
			vm, _ := v.(map[string]any)
			roll -= weightOf(vm)
			if roll < 0 || i == len(vs)-1 {
				n, _ := vm["name"].(string)
				set, _ := vm["set"].(map[string]any)
				out[name] = variant{n, set}
				break
			}
		}
	}
	return out
}

func weightOf(v map[string]any) float64 {
	if w, ok := v["weight"].(float64); ok && w >= 0 {
		return w
	}
	return 1
}

// liveCards drops cards outside their window (from/until, RFC 3339) or for other languages (langs: ["pt", "en"]).
func liveCards(cards []any, lang string, now time.Time) []any {
	out := []any{}
	pre, _, _ := strings.Cut(lang, "-")
	for _, c := range cards {
		m, ok := c.(map[string]any)
		if !ok {
			continue
		}
		if t, err := time.Parse(time.RFC3339, anyStr(m["from"])); err == nil && now.Before(t) {
			continue
		}
		if t, err := time.Parse(time.RFC3339, anyStr(m["until"])); err == nil && now.After(t) {
			continue
		}
		if ls, ok := m["langs"].([]any); ok && len(ls) > 0 {
			hit := false
			for _, l := range ls {
				if x := anyStr(l); x == lang || x == pre || (lang == "" && x == "en") {
					hit = true
				}
			}
			if !hit {
				continue
			}
		}
		out = append(out, m)
	}
	return out
}

func anyStr(v any) string { s, _ := v.(string); return s }

// deepMerge: objects merge key by key; anything else (arrays included) replaces. Null removes.
func deepMerge(dst, src map[string]any) map[string]any {
	out := make(map[string]any, len(dst)+len(src))
	for k, v := range dst {
		out[k] = v
	}
	for k, v := range src {
		if v == nil {
			delete(out, k)
			continue
		}
		if sm, ok := v.(map[string]any); ok {
			if dm, ok := out[k].(map[string]any); ok {
				out[k] = deepMerge(dm, sm)
				continue
			}
		}
		out[k] = v
	}
	return out
}

var overlayCache struct {
	sync.Mutex
	at time.Time
	v  map[string]any
}

// brainOverlay: the admin overlay, re-read at most every 30 s.
func (s *Server) brainOverlay(ctx context.Context) map[string]any {
	overlayCache.Lock()
	defer overlayCache.Unlock()
	if overlayCache.v != nil && time.Since(overlayCache.at) < 30*time.Second {
		return overlayCache.v
	}
	v := map[string]any{}
	if s.db != nil && s.db.Auth != nil {
		var raw []byte
		if err := s.db.Auth.QueryRow(ctx, `select body from brain_config where id = 1`).Scan(&raw); err == nil {
			_ = json.Unmarshal(raw, &v)
		}
	}
	overlayCache.v, overlayCache.at = v, time.Now()
	return v
}

// GET /v1/admin/brain/config: the overlay as stored. PUT replaces it (validated: an object with base/lang/experiments).
func (s *Server) adminBrainConfig(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	if r.Method == http.MethodGet {
		var raw []byte
		var at time.Time
		if err := s.db.Admin.QueryRow(ctx, `select body, updated_at from brain_config where id = 1`).Scan(&raw, &at); err != nil {
			s.fail(w, r, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"overlay": json.RawMessage(raw), "updatedAt": at, "defaults": brainConfigDefaults()})
		return
	}
	var in map[string]any
	if decode(r, &in) != nil {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	for k, v := range in {
		switch k {
		case "base", "lang":
			if _, ok := v.(map[string]any); !ok {
				s.fail(w, r, bad("invalid_"+k))
				return
			}
		case "experiments":
			if _, ok := v.([]any); !ok {
				s.fail(w, r, bad("invalid_experiments"))
				return
			}
		default:
			s.fail(w, r, bad("unknown_key"))
			return
		}
	}
	raw, _ := json.Marshal(in)
	if _, err := s.db.Admin.Exec(ctx, `update brain_config set body = $1, updated_at = now() where id = 1`, raw); err != nil {
		s.fail(w, r, err)
		return
	}
	overlayCache.Lock()
	overlayCache.v = nil
	overlayCache.Unlock()
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// MARK: outcomes

type outcomeRow struct {
	kind, species, slice, outcome, lang string
	conf                                *float64
	ms                                  int
}

// variantTag: "exp=variant,…" for this install, sorted; empty without experiments.
func (s *Server) variantTag(r *http.Request) string {
	vs := pickVariants(s.brainOverlay(r.Context()), r.Header.Get("X-MTJ-Device"))
	var parts []string
	for n, v := range vs {
		parts = append(parts, n+"="+v.name)
	}
	sort.Strings(parts)
	return strings.Join(parts, ",")
}

func (s *Server) logOutcome(r *http.Request, o outcomeRow) {
	if s.db == nil || s.db.Auth == nil {
		return
	}
	ctx := context.WithoutCancel(r.Context())
	cut := func(v string, n int) string {
		if len(v) > n {
			return v[:n]
		}
		return v
	}
	_, _ = s.db.Auth.Exec(ctx, `insert into brain_outcomes (kind, species, slice, variant, conf, outcome, lang, ms) values ($1,$2,$3,$4,$5,$6,$7,$8)`,
		o.kind, cut(o.species, 120), cut(o.slice, 200), cut(s.variantTag(r), 200), o.conf, o.outcome, cut(o.lang, 12), o.ms)
	if rand.IntN(2000) == 0 {
		_, _ = s.db.Auth.Exec(ctx, `delete from brain_outcomes where day < current_date - 180`)
	}
}

// teeWriter passes the reply through and keeps the first 256 KB to read the outcome from.
type teeWriter struct {
	http.ResponseWriter
	code int
	buf  bytes.Buffer
}

func (t *teeWriter) WriteHeader(c int) { t.code = c; t.ResponseWriter.WriteHeader(c) }
func (t *teeWriter) Write(b []byte) (int, error) {
	if t.buf.Len() < 256<<10 {
		t.buf.Write(b)
	}
	return t.ResponseWriter.Write(b)
}
func (t *teeWriter) Flush() {
	if f, ok := t.ResponseWriter.(http.Flusher); ok {
		f.Flush()
	}
}

// outcomes wraps identify and diagnose: reads photo kinds and lang from the request and the top answer from the
// reply, then logs one brain_outcomes row. The handler itself is untouched.
func (s *Server) outcomes(kind string, h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		body, err := io.ReadAll(r.Body)
		if err != nil {
			s.fail(w, r, bad("invalid_request"))
			return
		}
		r.Body = io.NopCloser(bytes.NewReader(body))
		var in struct {
			Lang    string `json:"lang"`
			Species string `json:"species"`
			Photo   string `json:"photo"`
			Photos  []struct {
				Kind string `json:"kind"`
			} `json:"photos"`
		}
		_ = json.Unmarshal(body, &in)
		tw := &teeWriter{ResponseWriter: w, code: http.StatusOK}
		h.ServeHTTP(tw, r)
		kinds := []string{}
		for _, p := range in.Photos {
			kinds = append(kinds, p.Kind)
		}
		if len(kinds) == 0 && in.Photo != "" {
			kinds = append(kinds, "single")
		}
		sort.Strings(kinds)
		o := outcomeRow{kind: kind, lang: in.Lang, species: in.Species, ms: int(time.Since(start).Milliseconds()),
			slice: "n=" + strconv.Itoa(len(kinds)) + ";k=" + strings.Join(kinds, "+")}
		readOutcome(&o, tw.code, tw.buf.Bytes())
		s.logOutcome(r, o)
	})
}

// readOutcome fills species, confidence and outcome (answered | low | empty | error_<code>) from a reply.
func readOutcome(o *outcomeRow, code int, reply []byte) {
	if code != http.StatusOK {
		o.outcome = "error_" + strconv.Itoa(code)
		return
	}
	switch o.kind {
	case "identify":
		var rep struct {
			Candidates []struct {
				ID         string  `json:"id"`
				Scientific string  `json:"scientific"`
				Score      float64 `json:"score"`
			} `json:"candidates"`
		}
		_ = json.Unmarshal(reply, &rep)
		if len(rep.Candidates) == 0 {
			o.outcome = "empty"
			return
		}
		c := rep.Candidates[0]
		o.species = c.ID
		if o.species == "" {
			o.species = c.Scientific
		}
		o.conf = &c.Score
		o.outcome = "answered"
		if c.Score < 0.5 {
			o.outcome = "low"
		}
	case "diagnose":
		var rep struct {
			Confidence string   `json:"confidence"`
			IDs        []string `json:"ids"`
			Source     string   `json:"source"`
		}
		_ = json.Unmarshal(reply, &rep)
		conf := map[string]float64{"low": 0.3, "medium": 0.6, "high": 0.9}[rep.Confidence]
		o.conf = &conf
		top := ""
		if len(rep.IDs) > 0 {
			top = rep.IDs[0]
		}
		o.slice += ";top=" + top + ";src=" + rep.Source
		o.outcome = "answered"
		if rep.Confidence == "low" || rep.Confidence == "" {
			o.outcome = "low"
		}
	}
}

// GET /v1/admin/brain/misses?days=30: where the brain misses, by species and slice, per experiment variant, plus
// owner corrections and "Did this help?" votes. The learning loop's read-out.
func (s *Server) adminBrainMisses(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	days, _ := strconv.Atoi(r.URL.Query().Get("days"))
	if days <= 0 || days > 180 {
		days = 30
	}
	type miss struct {
		Kind    string  `json:"kind"`
		Species string  `json:"species"`
		Slice   string  `json:"slice"`
		Variant string  `json:"variant"`
		N       int64   `json:"n"`
		Misses  int64   `json:"misses"`
		AvgConf float64 `json:"avgConf"`
		AvgMs   float64 `json:"avgMs"`
	}
	misses := []miss{}
	if rows, err := s.db.Admin.Query(ctx, `select kind, species, regexp_replace(slice, ';top=.*$', ''), variant, count(*),
		count(*) filter (where outcome <> 'answered'), coalesce(avg(conf), 0), coalesce(avg(ms), 0)
		from brain_outcomes where day > current_date - $1::int and kind <> 'pick' group by 1,2,3,4 order by 6 desc, 5 desc limit 300`, days); err == nil {
		for rows.Next() {
			var x miss
			rows.Scan(&x.Kind, &x.Species, &x.Slice, &x.Variant, &x.N, &x.Misses, &x.AvgConf, &x.AvgMs)
			misses = append(misses, x)
		}
		rows.Close()
	}
	type vrow struct {
		Kind     string  `json:"kind"`
		Variant  string  `json:"variant"`
		N        int64   `json:"n"`
		MissRate float64 `json:"missRate"`
	}
	variants := []vrow{}
	if rows, err := s.db.Admin.Query(ctx, `select kind, variant, count(*), avg(case when outcome in ('answered', 'confirmed') then 0 else 1 end)
		from brain_outcomes where day > current_date - $1::int group by 1,2 order by 1,2`, days); err == nil {
		for rows.Next() {
			var x vrow
			rows.Scan(&x.Kind, &x.Variant, &x.N, &x.MissRate)
			variants = append(variants, x)
		}
		rows.Close()
	}
	type corr struct {
		Predicted string `json:"predicted"`
		Corrected string `json:"corrected"`
		N         int64  `json:"n"`
	}
	corrections := []corr{}
	if rows, err := s.db.Admin.Query(ctx, `select predicted, corrected, count(*) from (
			select predicted, corrected from brain_feedback where kind = 'species' and predicted <> corrected and day > current_date - $1::int
			union all
			select species, slice from brain_outcomes where kind = 'pick' and outcome <> 'confirmed' and day > current_date - $1::int
		) x group by 1,2 order by 3 desc limit 200`, days); err == nil {
		for rows.Next() {
			var x corr
			rows.Scan(&x.Predicted, &x.Corrected, &x.N)
			corrections = append(corrections, x)
		}
		rows.Close()
	}
	type help struct {
		Kind string `json:"kind"`
		ID   string `json:"id"`
		Yes  int64  `json:"yes"`
		No   int64  `json:"no"`
	}
	helpful := []help{}
	if rows, err := s.db.Admin.Query(ctx, `select kind, predicted, count(*) filter (where corrected = 'yes'), count(*) filter (where corrected = 'no')
		from brain_feedback where kind in ('answer_helpful', 'diagnose_helpful') and day > current_date - $1::int
		group by 1,2 order by 4 desc, 3 desc limit 200`, days); err == nil {
		for rows.Next() {
			var x help
			rows.Scan(&x.Kind, &x.ID, &x.Yes, &x.No)
			helpful = append(helpful, x)
		}
		rows.Close()
	}
	writeJSON(w, http.StatusOK, map[string]any{"days": days, "misses": misses, "variants": variants, "corrections": corrections, "helpful": helpful})
}
