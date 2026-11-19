package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"
)

// Species knowledge: 600+ plants with needs, pests and typical problems. The brain uses it to
// (1) favour problems a species is known for, (2) spot where a plant's situation clashes with its needs,
// (3) name a plant from a photo, and (4) build a care plan for the plant's real conditions.

type species struct {
	ID, Scientific, En, Pt, Family, Light, Mix, Feed, Growth, Tip, Group, WaterStyle string
	DryMin, DryMax, HumidityMin, TempMin, TempMax, FeedWeeks, RepotYears             float64
	ToxicCats, ToxicDogs                                                             bool
	Pests                                                                            []string
	Problems                                                                         []struct{ Sign, Cause, Fix string }
	Aliases                                                                          []string
}

var speciesDB struct {
	sync.RWMutex
	at   time.Time
	list []species
	byID map[string]*species
}

func (b *brain) species() {
	b.load()
	speciesDB.RLock()
	fresh := !speciesDB.at.Before(b.loaded) && speciesDB.list != nil
	speciesDB.RUnlock()
	if fresh {
		return
	}
	var list []species
	if json.Unmarshal(b.file("data/species.json"), &list) != nil {
		return
	}
	by := map[string]*species{}
	for i := range list {
		by[list[i].ID] = &list[i]
	}
	speciesDB.Lock()
	speciesDB.list, speciesDB.byID, speciesDB.at = list, by, b.loaded
	speciesDB.Unlock()
}

// findSpecies resolves an id, common or scientific name.
func (b *brain) findSpecies(q string) *species {
	b.species()
	q = strings.ToLower(strings.TrimSpace(q))
	if q == "" {
		return nil
	}
	speciesDB.RLock()
	defer speciesDB.RUnlock()
	if s, ok := speciesDB.byID[q]; ok {
		return s
	}
	for i := range speciesDB.list {
		s := &speciesDB.list[i]
		if strings.ToLower(s.Scientific) == q || strings.ToLower(s.En) == q || strings.ToLower(s.Pt) == q {
			return s
		}
		for _, a := range s.Aliases {
			if a == q {
				return s
			}
		}
	}
	for i := range speciesDB.list {
		s := &speciesDB.list[i]
		if g := strings.Fields(strings.ToLower(s.Scientific)); len(g) > 0 && strings.Contains(q, g[0]) {
			return s
		}
	}
	return nil
}

// clashes are what a plant's situation does against its needs, each with the problems it makes likely.
func clashes(sp *species, sit situation) (notes []string, boost map[string]float64) {
	boost = map[string]float64{}
	has := func(k, v string) bool {
		for _, x := range sit[k] {
			if x == v {
				return true
			}
		}
		return false
	}
	add := func(note string, ids ...string) {
		notes = append(notes, note)
		for _, id := range ids {
			boost[id] += 0.4
		}
	}
	if sp == nil {
		return
	}
	dry := has("humidity", "low") || has("room", "heater") || has("room", "aircon") || has("weather", "dry")
	if sp.HumidityMin >= 50 && dry {
		add("This plant likes humid air and the air around it is dry.", "brown-tips", "crispy-edges", "spider-mites")
	}
	cold := has("temp", "cold") || has("room", "draft") || has("weather", "frost") || has("weather", "cold-snap")
	if sp.TempMin >= 15 && cold {
		add("It is a warm-climate plant and gets cold where it is.", "cold-damage", "droop-cold", "black-patches")
	}
	if (has("temp", "hot") || has("weather", "heatwave")) && sp.TempMax > 0 && sp.TempMax <= 28 {
		add("It struggles above its comfort temperature.", "wilting-heat", "scorch", "brown-tips")
	}
	if (sp.Light == "bright" || sp.Light == "direct") && (has("light", "low") || has("room", "dark") || has("room", "window-north")) {
		add("It needs much more light than it gets.", "leggy", "small-leaves", "variegation-loss", "yellow-lower")
	}
	if (sp.Light == "low" || sp.Light == "medium") && (has("light", "high") || has("room", "window-south")) {
		add("Strong sun is too much for it.", "scorch", "bleached", "sunburn")
	}
	if sp.DryMin >= 10 && has("watered", "recent") && (has("pot", "no-drainage") || has("pot", "too-big") || has("pot", "self-watering")) {
		add("It wants to dry out a lot between waterings and its pot holds water.", "root-rot", "droop-wet", "yellow-all", "fungus-gnats")
	}
	return
}

// speciesEntries adds the species' own known problems as knowledge entries for this one diagnosis.
func speciesEntries(sp *species) []kbEntry {
	if sp == nil {
		return nil
	}
	var es []kbEntry
	for i, p := range sp.Problems {
		e := kbEntry{ID: fmt.Sprintf("%s#%d", sp.ID, i), Kind: "species", Name: p.Sign, Looks: p.Sign, Causes: []string{p.Cause}, Fixes: splitSentences(p.Fix), words: map[string]float64{}}
		for _, t := range kbWords(p.Sign) {
			e.words[t] += 2.5
		}
		for _, t := range kbWords(p.Cause) {
			e.words[t] += 0.5
		}
		es = append(es, e)
	}
	return es
}

// gap records knowledge words of something we couldn't answer well (aggregated per day, nothing personal).
func (s *Server) gap(ctx context.Context, kind, text string) {
	ws := kbWords(text)
	sort.Strings(ws)
	uniq := ws[:0]
	for i, w := range ws {
		if i == 0 || w != ws[i-1] {
			uniq = append(uniq, w)
		}
	}
	if len(uniq) == 0 {
		return
	}
	if len(uniq) > 8 {
		uniq = uniq[:8]
	}
	s.db.Auth.Exec(context.WithoutCancel(ctx), `insert into brain_gaps (kind, words, n) values ($1, $2, 1) on conflict (day, kind, words) do update set n = brain_gaps.n + 1`, kind, strings.Join(uniq, " "))
}

// GET /v1/admin/brain: library size and use by source, plus the top gaps of the last 30 days.
func (s *Server) adminBrain(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	type row struct {
		Source string `json:"source"`
		N      int64  `json:"answers"`
		Hits   int64  `json:"hits"`
		Good   int64  `json:"good"`
		Bad    int64  `json:"bad"`
	}
	var lib []row
	if rows, err := s.db.Admin.Query(ctx, `select source, count(*), sum(hits), sum(good), sum(bad) from ai_library group by source order by 2 desc`); err == nil {
		for rows.Next() {
			var x row
			rows.Scan(&x.Source, &x.N, &x.Hits, &x.Good, &x.Bad)
			lib = append(lib, x)
		}
		rows.Close()
	}
	type g struct {
		Kind  string `json:"kind"`
		Words string `json:"words"`
		N     int64  `json:"n"`
	}
	var gaps []g
	if rows, err := s.db.Admin.Query(ctx, `select kind, words, sum(n) from brain_gaps where day > current_date - 30 group by 1,2 order by 3 desc limit 100`); err == nil {
		for rows.Next() {
			var x g
			rows.Scan(&x.Kind, &x.Words, &x.N)
			gaps = append(gaps, x)
		}
		rows.Close()
	}
	writeJSON(w, http.StatusOK, map[string]any{"library": lib, "gaps": gaps})
}

// POST /v1/brain/identify {photo}: names a plant from a photo with our own model, matched to our species list.
func (s *Server) brainIdentify(w http.ResponseWriter, r *http.Request) {
	var in struct{ Photo, Lang string }
	if decode(r, &in) != nil || len(in.Photo) == 0 || len(in.Photo) > 1_800_000 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	if theBrain.dir == "" {
		theBrain.dir = s.cfg.ContentDir
	}
	ctx, cancel := context.WithTimeout(context.WithoutCancel(r.Context()), 60*time.Second)
	defer cancel()
	said := ask(ctx, in.Photo, "What houseplant is this? Answer with the most likely scientific name and common name only, like: Monstera deliciosa (Swiss cheese plant). If unsure give two options separated by ' or '.", 40)
	theBrain.species()
	type cand struct {
		ID         string  `json:"id"`
		Scientific string  `json:"scientific"`
		Name       string  `json:"name"`
		Score      float64 `json:"score"`
	}
	var out []cand
	low := strings.ToLower(said)
	speciesDB.RLock()
	for _, sp := range speciesDB.list {
		sc := 0.0
		sci := strings.ToLower(sp.Scientific)
		switch {
		case sci != "" && strings.Contains(low, sci):
			sc = 1
		case sp.En != "" && strings.Contains(low, strings.ToLower(sp.En)):
			sc = 0.7
		case func() bool {
			for _, a := range sp.Aliases {
				if len(a) > 5 && strings.Contains(low, a) {
					return true
				}
			}
			return false
		}():
			sc = 0.6
		default:
			if g := strings.Fields(sci); len(g) > 0 && len(g[0]) > 3 && strings.Contains(low, g[0]) {
				sc = 0.4
			}
		}
		if sc > 0 {
			name := sp.En
			if strings.HasPrefix(in.Lang, "pt") && sp.Pt != "" {
				name = sp.Pt
			}
			out = append(out, cand{sp.ID, sp.Scientific, name, sc})
		}
	}
	speciesDB.RUnlock()
	sort.Slice(out, func(i, j int) bool { return out[i].Score > out[j].Score })
	if len(out) > 3 {
		out = out[:3]
	}
	if len(out) == 0 {
		s.gap(ctx, "identify", said)
	}
	writeJSON(w, http.StatusOK, map[string]any{"candidates": out, "seen": said})
}

// POST /v1/brain/care-plan {species, situation, lat?, lon?}: watering rhythm, light, feeding, repotting and
// warnings for this plant where it actually lives.
func (s *Server) brainCarePlan(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Species   string              `json:"species"`
		Lang      string              `json:"lang"`
		Situation map[string][]string `json:"situation"`
		Lat, Lon  *float64
	}
	if decode(r, &in) != nil || len(in.Species) > 120 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	if theBrain.dir == "" {
		theBrain.dir = s.cfg.ContentDir
	}
	sp := theBrain.findSpecies(in.Species)
	if sp == nil {
		s.gap(r.Context(), "species", in.Species)
		s.fail(w, r, apiError{http.StatusNotFound, "unknown_species"})
		return
	}
	sit := situation(in.Situation)
	if sit == nil {
		sit = situation{}
	}
	if in.Lat != nil && in.Lon != nil {
		for k, v := range weatherAt(r.Context(), *in.Lat, *in.Lon) {
			if _, ok := sit[k]; !ok {
				sit[k] = v
			}
		}
	}
	has := func(k string, vs ...string) bool {
		for _, x := range sit[k] {
			for _, v := range vs {
				if x == v {
					return true
				}
			}
		}
		return false
	}
	lo, hi := sp.DryMin, sp.DryMax
	if lo == 0 {
		lo, hi = 7, 10
	}
	f := 1.0 // drying speed adjustments
	if has("season", "winter") {
		f *= 1.5
	}
	if has("season", "summer") || has("weather", "heatwave") || has("temp", "hot") {
		f *= 0.75
	}
	if has("room", "heater", "aircon") || has("humidity", "low") || has("weather", "dry") {
		f *= 0.85
	}
	if has("humidity", "high") || has("room", "bathroom") || has("weather", "humid", "rainy") {
		f *= 1.15
	}
	if has("pot", "terracotta") {
		f *= 0.8
	}
	if has("pot", "plastic", "self-watering") {
		f *= 1.1
	}
	if has("light", "low") || has("room", "dark", "window-north") {
		f *= 1.25
	}
	if has("light", "high") || has("room", "window-south", "outdoor", "balcony") {
		f *= 0.85
	}
	notes, _ := clashes(sp, sit)
	lang := in.Lang
	if lang == "" || strings.HasPrefix(lang, "en") {
		lang = "en"
	}
	for i := range notes {
		notes[i] = theBrain.tr(lang, notes[i])
	}
	fit, _ := theBrain.situational(sit)
	var advice []string
	for i, sc := range fit {
		if i == 3 {
			break
		}
		advice = append(advice, theBrain.tr(lang, sc.Advice))
	}
	feed := sp.FeedWeeks
	if has("season", "winter") {
		feed = 0 // rest
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"species": sp.ID, "waterEveryDays": [2]int{int(lo*f + 0.5), int(hi*f + 0.5)}, "waterStyle": sp.WaterStyle,
		"light": sp.Light, "humidityMin": sp.HumidityMin, "tempRange": [2]float64{sp.TempMin, sp.TempMax},
		"feedEveryWeeks": feed, "feed": sp.Feed, "mix": sp.Mix, "repotEveryYears": sp.RepotYears,
		"toxicCats": sp.ToxicCats, "toxicDogs": sp.ToxicDogs, "tip": theBrain.tr(lang, sp.Tip),
		"warnings": notes, "advice": advice, "situation": sit,
	})
}

// ask is a free-form prompt to our own vision model.
func ask(ctx context.Context, jpegB64, prompt string, maxTokens int) string {
	return seeWith(ctx, jpegB64, prompt, maxTokens)
}
