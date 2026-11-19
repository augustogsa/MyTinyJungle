package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
)

// The brain: plant diagnosis that runs on our own server first.
//
//  1. Library: answers we already gave for the same species and findings (text only, no photos).
//  2. Our own vision model (llama.cpp + SmolVLM2 on 127.0.0.1:8091) describes what it sees; that text plus
//     the owner's note is matched against our knowledge base (symptoms, pests, diseases, deficiencies),
//     and the answer is built from our own vetted fixes, in the user's language from the content packs.
//  3. Only when that isn't confident: a free external model (Gemini, MTJ_GEMINI_KEY), then Claude (MTJ_AI_KEY).
//     Their answers go into the library so the next similar case stays internal.

type kbEntry struct {
	ID, Kind, Name, Looks string
	Causes, Fixes         []string
	words                 map[string]float64
}

// situation is what we know around the plant: room, season, weather, care. Each field matches a key in a
// knowledge-base scenario's "when".
type situation map[string][]string

type scenario struct {
	ID, Name, Advice string
	When             map[string]json.RawMessage
	Boosts           []string
}

type brain struct {
	mu        sync.RWMutex
	loaded    time.Time
	scenarios []scenario
	entries   []kbEntry
	docs_     []doc
	locales   map[string]map[string]string
	dir       string
}

var wordRx = regexp.MustCompile(`[a-z]+`)

var stop = map[string]bool{"the": true, "and": true, "a": true, "of": true, "on": true, "in": true, "to": true, "or": true, "is": true, "are": true, "with": true, "it": true, "its": true, "my": true, "at": true, "for": true, "be": true, "this": true, "that": true, "plant": true, "plants": true, "leaves": true, "leaf": true, "they": true, "look": true, "looks": true, "there": true, "under": true}

func stem(w string) string {
	for _, suf := range []string{"ing", "ed", "es", "s"} {
		if len(w) > len(suf)+3 && strings.HasSuffix(w, suf) {
			return w[:len(w)-len(suf)]
		}
	}
	return w
}

func kbWords(s string) []string {
	var out []string
	for _, w := range wordRx.FindAllString(strings.ToLower(s), -1) {
		if len(w) > 2 && !stop[w] {
			out = append(out, stem(w))
		}
	}
	return out
}

func (b *brain) file(logical string) []byte {
	m, err := os.ReadFile(filepath.Join(b.dir, "manifest.json"))
	if err != nil {
		return nil
	}
	var man struct {
		Files map[string]struct{ H string } `json:"files"`
	}
	if json.Unmarshal(m, &man) != nil {
		return nil
	}
	f, ok := man.Files[logical]
	if !ok {
		return nil
	}
	d, _ := os.ReadFile(filepath.Join(b.dir, "b", f.H))
	return d
}

// load (re)reads the knowledge base when the content pack changes.
func (b *brain) load() {
	st, err := os.Stat(filepath.Join(b.dir, "manifest.json"))
	b.mu.RLock()
	fresh := err == nil && !st.ModTime().After(b.loaded)
	b.mu.RUnlock()
	if fresh || err != nil {
		return
	}
	var kb struct {
		Symptoms []struct {
			ID, Name, Looks         string
			Causes, Fixes, Keywords []string
		}
		Pests, Diseases, Deficiencies []struct{ ID, Name, Signs, Why, Fix, Prevent, Likes string }
		Scenarios                     []scenario
		Topics                        []struct {
			ID, Title, Kind, Intro string
			Steps                  []struct{ Title, Detail string }
			Keywords               []string
		}
		Glossary []struct{ Term, Meaning string }
		Soils    []struct{ ID, Name, Short, Note, ForGroups string }
		Remedies []json.RawMessage
	}
	if json.Unmarshal(b.file("data/knowledge.json"), &kb) != nil {
		return
	}
	var es []kbEntry
	add := func(e kbEntry, keywords []string) {
		e.words = map[string]float64{}
		for _, t := range kbWords(e.Name) {
			e.words[t] += 2
		}
		for _, t := range kbWords(e.Looks) {
			e.words[t] += 1
		}
		for _, k := range keywords {
			for _, t := range kbWords(k) {
				e.words[t] += 2.5
			}
		}
		es = append(es, e)
	}
	for _, s := range kb.Symptoms {
		add(kbEntry{ID: s.ID, Kind: "symptom", Name: s.Name, Looks: s.Looks, Causes: s.Causes, Fixes: s.Fixes}, s.Keywords)
	}
	for kind, list := range map[string][]struct{ ID, Name, Signs, Why, Fix, Prevent, Likes string }{"pest": kb.Pests, "disease": kb.Diseases, "deficiency": kb.Deficiencies} {
		for _, p := range list {
			fixes := splitSentences(p.Fix)
			if p.Prevent != "" {
				fixes = append(fixes, p.Prevent)
			}
			causes := []string{}
			if p.Why != "" {
				causes = append(causes, p.Why)
			}
			add(kbEntry{ID: p.ID, Kind: kind, Name: p.Name, Looks: p.Signs, Causes: causes, Fixes: fixes}, nil)
		}
	}
	var ds []doc
	for _, t := range kb.Topics {
		text := t.Intro
		for _, st := range t.Steps {
			text += " " + st.Title + ": " + st.Detail
		}
		ds = append(ds, newDoc("topic", t.Title, t.Intro, t.Title+" "+t.Intro+" "+strings.Join(t.Keywords, " ")))
	}
	for _, g := range kb.Glossary {
		ds = append(ds, newDoc("glossary", g.Term, g.Meaning, g.Term+" "+g.Term+" "+g.Meaning))
	}
	for _, so := range kb.Soils {
		ds = append(ds, newDoc("soil", so.Name, strings.TrimSpace(so.Short+". "+so.Note), so.Name+" "+so.Short+" "+so.ForGroups+" soil mix"))
	}
	locales := map[string]map[string]string{}
	for _, l := range []string{"pt-BR", "es", "fr", "de", "ja"} {
		var t struct{ Text map[string]string }
		if json.Unmarshal(b.file("data/locales/"+l+".json"), &t) == nil {
			locales[l] = t.Text
		}
	}
	b.mu.Lock()
	b.entries, b.locales, b.loaded, b.scenarios, b.docs_ = es, locales, st.ModTime(), kb.Scenarios, ds
	b.mu.Unlock()
}

var clauseRx = regexp.MustCompile(`[,.;:]|\band\b|\bbut\b|\bwith\b`)
var negRx = regexp.MustCompile(`^\s*(no|not|none|without|never|nor|isn't|aren't|doesn't|don't|free of)\b`)

// affirmed drops negated clauses ("no holes, no white fuzz") so they don't count as evidence.
func affirmed(s string) string {
	var keep []string
	for _, c := range clauseRx.Split(strings.ToLower(s), -1) {
		if !negRx.MatchString(c) && !strings.Contains(c, " not ") && !strings.Contains(c, " no ") {
			keep = append(keep, c)
		}
	}
	return strings.Join(keep, " ")
}

func splitSentences(s string) []string {
	var out []string
	for _, p := range strings.SplitAfter(s, ". ") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

type match struct {
	e     kbEntry
	score float64
}

// rank scores every knowledge entry against the evidence (note + what the model saw).
// fits says whether every condition of a scenario holds in this situation.
func (sc scenario) fits(sit situation) bool {
	if len(sc.When) == 0 {
		return false
	}
	for k, raw := range sc.When {
		var want []string
		if json.Unmarshal(raw, &want) != nil {
			var one string
			if json.Unmarshal(raw, &one) != nil {
				return false
			}
			want = []string{one}
		}
		have, hit := sit[k], false
		for _, w := range want {
			for _, h := range have {
				hit = hit || w == h
			}
		}
		if !hit {
			return false
		}
	}
	return true
}

// situational returns the scenarios that fit and how much each knowledge entry is boosted by them.
func (b *brain) situational(sit situation) ([]scenario, map[string]float64) {
	b.load()
	b.mu.RLock()
	defer b.mu.RUnlock()
	var fit []scenario
	boost := map[string]float64{}
	for _, sc := range b.scenarios {
		if sc.fits(sit) {
			fit = append(fit, sc)
			w := 0.25 + 0.1*float64(len(sc.When)) // more specific scenarios count more
			for _, id := range sc.Boosts {
				boost[id] += w
			}
		}
	}
	sort.SliceStable(fit, func(i, j int) bool { return len(fit[i].When) > len(fit[j].When) })
	return fit, boost
}

func (b *brain) rank(note, saw string, boost map[string]float64) []match {
	b.load()
	b.mu.RLock()
	defer b.mu.RUnlock()
	ev := map[string]float64{}
	for _, t := range kbWords(affirmed(saw)) {
		ev[t] = 0.6 // what our model saw counts, but less than the owner's own words
	}
	for _, t := range kbWords(affirmed(note)) {
		ev[t] = 1
	}
	var ms []match
	for _, e := range b.entries {
		var s, total float64
		for w, wt := range e.words {
			total += wt
			s += wt * ev[w]
		}
		if s > 0 {
			sc := s / (4 + total*0.15)
			ms = append(ms, match{e, sc * (1 + boost[e.ID])})
		}
	}
	sort.Slice(ms, func(i, j int) bool { return ms[i].score > ms[j].score })
	if len(ms) > 5 {
		ms = ms[:5]
	}
	return ms
}

func (b *brain) tr(lang, s string) string {
	b.mu.RLock()
	defer b.mu.RUnlock()
	if t, ok := b.locales[lang][s]; ok && t != "" {
		return t
	}
	return s
}

// answerFrom builds a diagnosis from our own knowledge, in the user's language.
func (b *brain) answerFrom(m match, lang string) diagnosis {
	conf := "low"
	switch {
	case m.score >= 1.2:
		conf = "high"
	case m.score >= 0.6:
		conf = "medium"
	}
	why := b.tr(lang, m.e.Looks)
	if len(m.e.Causes) > 0 {
		why = strings.TrimSpace(why + " " + b.tr(lang, m.e.Causes[0]))
	}
	var steps []string
	for _, f := range m.e.Fixes {
		if len(steps) == 4 {
			break
		}
		steps = append(steps, b.tr(lang, f))
	}
	urgent := m.e.Kind == "pest" || m.e.ID == "root-rot"
	return diagnosis{Problem: b.tr(lang, m.e.Name), Confidence: conf, Why: why, Steps: steps, Urgent: urgent, Source: "internal"}
}

// see asks our own vision model what is visible. Empty when the model is down or slow.
func see(ctx context.Context, jpegB64 string) string {
	body, _ := json.Marshal(map[string]any{
		"max_tokens": 120, "temperature": 0.1,
		"messages": []any{map[string]any{"role": "user", "content": []any{
			map[string]any{"type": "image_url", "image_url": map[string]string{"url": "data:image/jpeg;base64," + jpegB64}},
			map[string]any{"type": "text", "text": "Describe only the visible problems of this houseplant in one or two short sentences: leaf colour (yellow, brown, black, pale), spots, crispy or mushy edges, holes, webbing, insects, white fuzz, wilting, drooping, soil state. If it looks healthy say healthy."},
		}}},
	})
	cctx, cancel := context.WithTimeout(ctx, 45*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(cctx, "POST", "http://127.0.0.1:8091/v1/chat/completions", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return ""
	}
	defer res.Body.Close()
	var out struct {
		Choices []struct{ Message struct{ Content string } }
	}
	if json.NewDecoder(res.Body).Decode(&out) != nil || len(out.Choices) == 0 {
		return ""
	}
	return strings.TrimSpace(out.Choices[0].Message.Content)
}

func signature(species string, ms []match) string {
	ids := []string{strings.ToLower(species)}
	for i, m := range ms {
		if i == 2 {
			break
		}
		ids = append(ids, m.e.ID)
	}
	return strings.Join(ids, "|")
}

var theBrain = &brain{}

// think runs the tiers, cheapest first. Only Claude costs money, and it is reached only when
// our own model + knowledge base aren't confident and no free model answered.
func (s *Server) think(ctx context.Context, photo, species, note, lang string, sit situation) (diagnosis, error) {
	if lang == "" || strings.HasPrefix(lang, "en") {
		lang = "en"
	}
	if theBrain.dir == "" {
		theBrain.dir = s.cfg.ContentDir
	}
	saw := see(ctx, photo)
	fit, boost := theBrain.situational(sit)
	ms := theBrain.rank(note, saw, boost)
	sig := signature(species, ms)
	ref := sig + "#" + lang
	top := []string{}
	for _, m := range ms {
		top = append(top, m.e.ID+fmt.Sprintf(":%.2f", m.score))
	}
	s.log.Info("brain", "saw", saw, "top", strings.Join(top, " "))

	// 1. Library.
	if len(ms) > 0 {
		var raw []byte
		err := s.db.Auth.QueryRow(ctx, `update ai_library set hits = hits + 1 where sig = $1 and lang = $2 returning answer`, sig, lang).Scan(&raw)
		if d, ok := parseDiagnosis(string(raw)); err == nil && ok {
			d.Source, d.Ref = "library", ref
			return withSituation(d, fit, ms[0].e.ID, lang), nil
		}
	}
	healthy := strings.Contains(strings.ToLower(saw), "healthy") && len(ms) == 0
	// 2. Our own model + knowledge base.
	if len(ms) > 0 && ms[0].score >= 0.6 && (len(ms) == 1 || ms[0].score >= ms[1].score*1.25) {
		d := theBrain.answerFrom(ms[0], lang)
		s.remember(ctx, sig, lang, d)
		d.Ref = ref
		return withSituation(d, fit, ms[0].e.ID, lang), nil
	}
	if healthy && strings.TrimSpace(note) == "" {
		return diagnosis{Problem: theBrain.tr(lang, "Looks healthy"), Confidence: "medium",
			Why: theBrain.tr(lang, "No clear signs of trouble in this photo."), Steps: []string{theBrain.tr(lang, "Keep your usual care and check again in a week.")}, Source: "internal"}, nil
	}
	ctxNote := "lang: " + lang + "\nspecies: " + species + "\nowner's note: " + note
	if saw != "" {
		ctxNote += "\nfirst look: " + saw
	}
	for k, v := range sit {
		ctxNote += "\n" + k + ": " + strings.Join(v, ", ")
	}
	for i, m := range ms {
		if i == 3 {
			break
		}
		ctxNote += "\ncandidate from our knowledge base: " + m.e.Name + " (" + m.e.Looks + ")"
	}
	// 3. Free model.
	if d, ok := askGemini(ctx, photo, ctxNote); ok {
		s.remember(ctx, sig, lang, d)
		d.Ref = ref
		return d, nil
	}
	// 4. Claude, last resort.
	d, err := s.askClaude(ctx, photo, ctxNote)
	if err == nil {
		s.remember(ctx, sig, lang, d)
		d.Ref = ref
	} else if len(ms) > 0 {
		// Never leave the owner empty-handed when we have our own best guess.
		g := theBrain.answerFrom(ms[0], lang)
		g.Confidence, g.Ref = "low", ref
		return g, nil
	}
	return d, err
}

func (s *Server) remember(ctx context.Context, sig, lang string, d diagnosis) {
	if !strings.Contains(sig, "|") {
		return // no knowledge match: too vague to reuse
	}
	b, _ := json.Marshal(d)
	s.db.Auth.Exec(ctx, `insert into ai_library (sig, lang, answer, source) values ($1,$2,$3,$4) on conflict do nothing`, sig, lang, b, d.Source)
}

// askGemini uses Google's free tier when MTJ_GEMINI_KEY is set.
func askGemini(ctx context.Context, photo, note string) (diagnosis, bool) {
	key := os.Getenv("MTJ_GEMINI_KEY")
	if key == "" {
		return diagnosis{}, false
	}
	body, _ := json.Marshal(map[string]any{
		"systemInstruction": map[string]any{"parts": []any{map[string]string{"text": diagnoseSystem}}},
		"contents": []any{map[string]any{"parts": []any{
			map[string]any{"inline_data": map[string]string{"mime_type": "image/jpeg", "data": photo}},
			map[string]string{"text": note},
		}}},
		"generationConfig": map[string]any{"responseMimeType": "application/json"},
	})
	cctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(cctx, "POST", "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", key)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return diagnosis{}, false
	}
	defer res.Body.Close()
	var out struct {
		Candidates []struct {
			Content struct{ Parts []struct{ Text string } }
		}
	}
	if res.StatusCode != 200 || json.NewDecoder(res.Body).Decode(&out) != nil || len(out.Candidates) == 0 || len(out.Candidates[0].Content.Parts) == 0 {
		return diagnosis{}, false
	}
	d, ok := parseDiagnosis(out.Candidates[0].Content.Parts[0].Text)
	d.Source = "free"
	return d, ok
}

// withSituation adds the advice of the most specific scenario that explains this problem (the library stays
// situation-free, so it is added after the cache).
func withSituation(d diagnosis, fit []scenario, id, lang string) diagnosis {
	for _, sc := range fit {
		for _, b := range sc.Boosts {
			if b == id && sc.Advice != "" {
				d.Context = theBrain.tr(lang, sc.Advice)
				return d
			}
		}
	}
	return d
}

var weatherCache sync.Map // "lat,lon" rounded → cached conditions

// weatherAt reads current conditions near the plant from Open-Meteo (free, no key). Coordinates are rounded to
// about 10 km by the caller and never stored.
func weatherAt(ctx context.Context, lat, lon float64) situation {
	key := fmt.Sprintf("%.1f,%.1f", lat, lon)
	type cached struct {
		at  time.Time
		sit situation
	}
	if c, ok := weatherCache.Load(key); ok && time.Since(c.(cached).at) < time.Hour {
		return c.(cached).sit
	}
	cctx, cancel := context.WithTimeout(ctx, 4*time.Second)
	defer cancel()
	u := fmt.Sprintf("https://api.open-meteo.com/v1/forecast?latitude=%.1f&longitude=%.1f&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,cloud_cover&daily=temperature_2m_max,temperature_2m_min&past_days=3&forecast_days=1", lat, lon)
	req, _ := http.NewRequestWithContext(cctx, "GET", u, nil)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil
	}
	defer res.Body.Close()
	var w struct {
		Current struct {
			T     float64 `json:"temperature_2m"`
			RH    float64 `json:"relative_humidity_2m"`
			Rain  float64 `json:"precipitation"`
			Wind  float64 `json:"wind_speed_10m"`
			Cloud float64 `json:"cloud_cover"`
		}
		Daily struct {
			Max []float64 `json:"temperature_2m_max"`
			Min []float64 `json:"temperature_2m_min"`
		}
	}
	if res.StatusCode != 200 || json.NewDecoder(res.Body).Decode(&w) != nil {
		return nil
	}
	sit := situation{}
	add := func(k, v string) { sit[k] = append(sit[k], v) }
	c := w.Current
	if c.Rain > 0.2 {
		add("weather", "rainy")
	}
	if c.RH >= 75 {
		add("weather", "humid")
	} else if c.RH <= 35 {
		add("weather", "dry")
	}
	if c.Wind >= 35 {
		add("weather", "windy")
	}
	if c.Wind >= 60 {
		add("weather", "storm")
	}
	if c.Cloud >= 85 {
		add("weather", "cloudy-days")
	}
	hot, frost := 0, false
	for i := range w.Daily.Max {
		if w.Daily.Max[i] >= 32 {
			hot++
		}
		if i < len(w.Daily.Min) && w.Daily.Min[i] <= 0 {
			frost = true
		}
	}
	if hot >= 2 {
		add("weather", "heatwave")
	}
	if frost {
		add("weather", "frost")
	} else if c.T <= 8 {
		add("weather", "cold-snap")
	}
	month := time.Now().Month()
	south := lat < 0
	season := map[time.Month]string{12: "winter", 1: "winter", 2: "winter", 3: "spring", 4: "spring", 5: "spring", 6: "summer", 7: "summer", 8: "summer", 9: "autumn", 10: "autumn", 11: "autumn"}[month]
	if south {
		season = map[string]string{"winter": "summer", "summer": "winter", "spring": "autumn", "autumn": "spring"}[season]
	}
	if lat > -23.5 && lat < 23.5 {
		season = "" // tropics: seasons don't follow the calendar
	}
	if season != "" {
		add("season", season)
	}
	weatherCache.Store(key, cached{time.Now(), sit})
	return sit
}

type doc struct {
	kind, title, text string
	words             map[string]bool
}

func newDoc(kind, title, text, index string) doc {
	w := map[string]bool{}
	for _, t := range kbWords(index) {
		w[t] = true
	}
	return doc{kind: kind, title: title, text: text, words: w}
}

// docs finds the topics, glossary terms and soils that best match a question, translated.
func (b *brain) docs(q, lang string, n int) []doc {
	b.load()
	b.mu.RLock()
	qs := kbWords(q)
	type hit struct {
		d doc
		s float64
	}
	var hs []hit
	for _, d := range b.docs_ {
		var s float64
		for _, t := range qs {
			if d.words[t] {
				s++
			}
		}
		if s > 0 && s/float64(len(qs)) >= 0.34 {
			hs = append(hs, hit{d, s / (1 + 0.02*float64(len(d.words)))})
		}
	}
	b.mu.RUnlock()
	sort.Slice(hs, func(i, j int) bool { return hs[i].s > hs[j].s })
	var out []doc
	for i, h := range hs {
		if i == n {
			break
		}
		out = append(out, doc{kind: h.d.kind, title: b.tr(lang, h.d.title), text: b.tr(lang, h.d.text)})
	}
	return out
}
