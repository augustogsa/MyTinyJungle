package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"math"
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
	ml                    mlIndex // translated name + looks per language
	phrases               [][]string
}

// keywordPhrases tokenizes keyword phrases both ways (English stems and multilingual folding).
func keywordPhrases(kws []string) [][]string {
	var out [][]string
	for _, k := range kws {
		if t := kbWords(k); len(t) > 0 && isASCII(k) { // the English tokenizer cuts "düngen" into "ngen"
			out = append(out, t)
		}
		if t := mlWords(k); len(t) > 0 {
			out = append(out, t)
		}
	}
	return out
}

func isASCII(s string) bool {
	for i := 0; i < len(s); i++ {
		if s[i] >= 0x80 {
			return false
		}
	}
	return true
}

func uniq(ws []string) []string {
	seen := map[string]bool{}
	out := ws[:0:0]
	for _, w := range ws {
		if !seen[w] {
			seen[w] = true
			out = append(out, w)
		}
	}
	return out
}

// phraseBonus rewards a keyword phrase whose every word is in the question, longer phrases more.
func phraseBonus(phrases [][]string, have func(string) bool) float64 {
	best := 0.0
	for _, ph := range phrases {
		all := true
		for _, t := range ph {
			all = all && have(t)
		}
		if all {
			best = max(best, 0.3+0.25*float64(min(len(ph), 4)))
		}
	}
	return best
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
		Pests, Diseases, Deficiencies []struct {
			ID, Name, Signs, Why, Fix, Prevent, Likes string
			Keywords                                  []string
		}
		Scenarios []scenario
		Topics    []struct {
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
	locales := map[string]map[string]string{}
	for _, l := range mlLangs {
		var t struct{ Text map[string]string }
		if json.Unmarshal(b.file("data/locales/"+l+".json"), &t) == nil {
			locales[l] = t.Text
		}
	}
	var es []kbEntry
	add := func(e kbEntry, keywords []string) {
		e.ml = mlIndex{}
		for _, l := range mlLangs {
			e.ml.add(l, trWith(locales, l, e.Name), 2)
			e.ml.add(l, trWith(locales, l, e.Looks), 1)
		}
		for _, k := range keywords { // keywords hold a few non-English phrasings too
			for _, l := range mlLangs {
				e.ml.add(l, k, 1)
			}
		}
		e.phrases = keywordPhrases(append([]string{e.Name}, keywords...))
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
	for kind, list := range map[string][]struct {
		ID, Name, Signs, Why, Fix, Prevent, Likes string
		Keywords                                  []string
	}{"pest": kb.Pests, "disease": kb.Diseases, "deficiency": kb.Deficiencies} {
		for _, p := range list {
			fixes := splitSentences(p.Fix)
			if p.Prevent != "" {
				fixes = append(fixes, p.Prevent)
			}
			causes := []string{}
			if p.Why != "" {
				causes = append(causes, p.Why)
			}
			add(kbEntry{ID: p.ID, Kind: kind, Name: p.Name, Looks: p.Signs, Causes: causes, Fixes: fixes}, p.Keywords)
		}
	}
	var ds []doc
	for _, t := range kb.Topics {
		text := t.Intro
		for _, st := range t.Steps {
			text += " " + st.Title + ": " + st.Detail
		}
		d := newDoc("topic", t.Title, t.Intro, t.Title+" "+t.Intro+" "+strings.Join(t.Keywords, " "))
		d.id, d.keywords, d.phrases = t.ID, t.Keywords, keywordPhrases(t.Keywords)
		ds = append(ds, d)
	}
	for _, g := range kb.Glossary {
		d := newDoc("glossary", g.Term, g.Meaning, g.Term+" "+g.Term+" "+g.Meaning)
		d.id = "glossary:" + strings.ToLower(g.Term)
		ds = append(ds, d)
	}
	for _, so := range kb.Soils {
		d := newDoc("soil", so.Name, strings.TrimSpace(so.Short+". "+so.Note), so.Name+" "+so.Short+" "+so.ForGroups+" soil mix")
		d.id = "soil:" + so.ID
		ds = append(ds, d)
	}
	for i := range ds {
		ds[i].ml = mlIndex{}
		for _, l := range mlLangs {
			ds[i].ml.add(l, trWith(locales, l, ds[i].title), 2)
			ds[i].ml.add(l, trWith(locales, l, ds[i].text), 1)
			for _, k := range ds[i].keywords {
				ds[i].ml.add(l, k, 1)
			}
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

func (b *brain) rank(lang, note, saw string, boost map[string]float64, extra ...kbEntry) []match {
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
	evL := map[string]float64{} // the owner's note in their own language
	if lang != "en" {
		for _, t := range mlWords(note) {
			evL[t] = 1
		}
	}
	score := func(words map[string]float64, ev map[string]float64) float64 {
		var s, total float64
		for w, wt := range words {
			total += wt
			s += wt * ev[w]
		}
		if s == 0 {
			return 0
		}
		return s / (4 + total*0.15)
	}
	noteW := map[string]bool{}
	for _, t := range kbWords(affirmed(note)) {
		noteW[t] = true
	}
	for t := range evL {
		noteW[t] = true
	}
	have := func(t string) bool { return noteW[t] }
	var ms []match
	for _, e := range append(extra, b.entries...) {
		sc := score(e.words, ev)
		if len(evL) > 0 {
			sc = max(sc, score(e.ml[lang], evL))
		}
		sc += phraseBonus(e.phrases, have)
		if sc > 0 {
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
func (s *Server) think(ctx context.Context, photo string, given *scene, species, note, lang string, sit situation) (diagnosis, error) {
	if lang == "" || strings.HasPrefix(lang, "en") {
		lang = "en"
	}
	if theBrain.dir == "" {
		theBrain.dir = s.cfg.ContentDir
	}
	var sc scene
	if given != nil {
		sc = *given
	} else {
		sc, _ = readScene(ctx, photo)
	}
	saw := sc.evidence()
	sit = sc.situation(sit)
	fit, boost := theBrain.situational(sit)
	sp := theBrain.findSpecies(species)
	mediumBoost(sit, boost)
	fit = forSpecies(fit, sp)
	notes, cb := clashes(sp, sit)
	for k, v := range cb {
		boost[k] += v
	}
	if sp != nil {
		for _, id := range sp.Pests {
			boost[id] += 0.15 // pests this species is known to get
		}
	}
	ms := theBrain.rank(lang, note, saw, boost, speciesEntries(sp)...)
	d, err := s.thinkTiers(ctx, photo, species, note, lang, sit, saw, fit, notes, ms)
	var ids, alts []string
	for i, m := range ms {
		if i == 3 {
			break
		}
		ids = append(ids, m.e.ID)
		if i > 0 {
			alts = append(alts, theBrain.tr(lang, m.e.Name))
		}
	}
	d.IDs, d.Alternatives, d.Scene = ids, alts, &sc
	return d, err
}

func (s *Server) thinkTiers(ctx context.Context, photo, species, note, lang string, sit situation, saw string, fit []scenario, notes []string, ms []match) (diagnosis, error) {
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
		d = withSituation(d, fit, ms[0].e.ID, lang)
		if d.Context == "" && len(notes) > 0 {
			d.Context = theBrain.tr(lang, notes[0])
		}
		return d, nil
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
		s.gap(ctx, "diagnose", note+" "+affirmed(saw))
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
	t, ok := geminiText(ctx, photo, diagnoseSystem+"\n\n"+note)
	if !ok {
		return diagnosis{}, false
	}
	d, ok := parseDiagnosis(t)
	d.Source = "free"
	return d, ok
}

// geminiModel: MTJ_GEMINI_MODEL, else gemini-3.6-flash (the fastest correct model measured from the VPS).
func geminiModel() string {
	if m := os.Getenv("MTJ_GEMINI_MODEL"); m != "" {
		return m
	}
	return "gemini-3.6-flash"
}

// geminiText sends a photo and prompt to Gemini's free tier; false when no key or no answer.
func geminiText(ctx context.Context, photo, prompt string) (string, bool) {
	key := os.Getenv("MTJ_GEMINI_KEY")
	if key == "" {
		return "", false
	}
	body, _ := json.Marshal(map[string]any{
		"contents": []any{map[string]any{"parts": []any{
			map[string]any{"inline_data": map[string]string{"mime_type": "image/jpeg", "data": photo}},
			map[string]string{"text": prompt},
		}}},
		// Minimal thinking: measured fastest for photo questions (gemini-2.5-flash is retired for new keys).
		"generationConfig": map[string]any{"responseMimeType": "application/json", "thinkingConfig": map[string]any{"thinkingLevel": "minimal"}},
	})
	cctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(cctx, "POST", "https://generativelanguage.googleapis.com/v1beta/models/"+geminiModel()+":generateContent", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", key)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", false
	}
	defer res.Body.Close()
	var out struct {
		Candidates []struct {
			Content struct{ Parts []struct{ Text string } }
		}
	}
	if res.StatusCode != 200 || json.NewDecoder(res.Body).Decode(&out) != nil || len(out.Candidates) == 0 || len(out.Candidates[0].Content.Parts) == 0 {
		return "", false
	}
	return out.Candidates[0].Content.Parts[0].Text, true
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

type doc struct {
	id, kind, title, text string
	words                 map[string]bool
	keywords              []string
	ml                    mlIndex
	phrases               [][]string
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
	qs := uniq(kbWords(q))
	var qL []string
	if lang != "en" {
		qL = uniq(mlWords(q))
	}
	type hit struct {
		d doc
		s float64
	}
	var hs []hit
	// Rare words weigh more: "adubo" says more than "planta" or "tempo".
	N := float64(len(b.docs_))
	idf := func(df int) float64 { return math.Log((N + 1) / (float64(df) + 1)) }
	wE, wL := make([]float64, len(qs)), make([]float64, len(qL))
	for _, d := range b.docs_ {
		for i, t := range qs {
			if d.words[t] {
				wE[i]++
			}
		}
		for i, t := range qL {
			if d.ml[lang][t] > 0 {
				wL[i]++
			}
		}
	}
	var totE, totL float64
	for i := range wE {
		wE[i] = idf(int(wE[i]))
		totE += wE[i]
	}
	for i := range wL {
		wL[i] = idf(int(wL[i]))
		totL += wL[i]
	}
	for _, d := range b.docs_ {
		var s, sw float64
		for i, t := range qs {
			if d.words[t] {
				s++
				sw += wE[i]
			}
		}
		best := 0.0
		if s > 0 && s/float64(len(qs)) >= 0.34 && totE > 0 {
			best = s * (sw / totE) * float64(len(qs)) / s / (1 + 0.02*float64(len(d.words)))
		}
		if len(qL) > 0 {
			var sl, slw float64
			for i, t := range qL {
				if d.ml[lang][t] > 0 {
					sl++
					slw += wL[i]
				}
			}
			if sl > 0 && sl/float64(len(qL)) >= 0.25 && totL > 0 {
				best = max(best, (slw/totL)*float64(len(qL))/(1+0.02*float64(len(d.ml[lang]))))
			}
		}
		qw := map[string]bool{}
		for _, t := range qs {
			qw[t] = true
		}
		for _, t := range qL {
			qw[t] = true
		}
		best += phraseBonus(d.phrases, func(t string) bool { return qw[t] })
		if best > 0 {
			hs = append(hs, hit{d, best})
		}
	}
	b.mu.RUnlock()
	sort.Slice(hs, func(i, j int) bool { return hs[i].s > hs[j].s })
	var out []doc
	for i, h := range hs {
		if i == n {
			break
		}
		out = append(out, doc{id: h.d.id, kind: h.d.kind, title: b.tr(lang, h.d.title), text: b.tr(lang, h.d.text)})
	}
	return out
}

// mediumBoost: a plant in water, LECA or PON can't be thirsty for soil watering; favour hydro problems.
func mediumBoost(sit situation, boost map[string]float64) {
	for _, m := range sit["medium"] {
		switch m {
		case "water", "leca", "pon":
			for _, id := range []string{"droop-dry", "underwatering-signs", "wrinkled", "soil-dries-fast", "brown-crispy-whole", "succulent-wrinkled", "revive-dry"} {
				boost[id] -= 0.9
			}
			for _, id := range []string{"hydro-algae", "hydro-brown-roots", "leca-roots-rot", "leca-white-crust", "cutting-rotting", "root-rot"} {
				boost[id] += 0.35
			}
		}
	}
}
