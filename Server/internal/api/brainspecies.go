package api

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
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
	ToxicCats, ToxicDogs, Outdoor                                                    bool
	Pests                                                                            []string
	Problems                                                                         []struct{ Sign, Cause, Fix string }
	Aliases, Tags                                                                    []string
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
		e.ml = mlIndex{}
		for _, l := range mlLangs {
			e.ml.add(l, theBrain.tr(l, p.Sign), 2.5)
			e.ml.add(l, theBrain.tr(l, p.Cause), 0.5)
		}
		es = append(es, e)
	}
	return es
}

// gap records knowledge words of something we couldn't answer well (aggregated per day, nothing personal).
func (s *Server) gap(ctx context.Context, kind, text string) {
	ws := mlWords(text) // any language
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
	if s.db == nil || s.db.Auth == nil {
		return
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
	type fb struct {
		Kind      string `json:"kind"`
		Predicted string `json:"predicted"`
		Corrected string `json:"corrected"`
		N         int64  `json:"n"`
	}
	var fbs []fb
	if rows, err := s.db.Admin.Query(ctx, `select kind, predicted, corrected, count(*) from brain_feedback where day > current_date - 30 group by 1,2,3 order by 4 desc limit 100`); err == nil {
		for rows.Next() {
			var x fb
			rows.Scan(&x.Kind, &x.Predicted, &x.Corrected, &x.N)
			fbs = append(fbs, x)
		}
		rows.Close()
	}
	var learned, pending int64
	s.db.Admin.QueryRow(ctx, `select count(*) filter (where learned_at is not null), count(*) filter (where learned_at is null and photo_ref is not null and kind = 'species') from brain_feedback`).Scan(&learned, &pending)
	writeJSON(w, http.StatusOK, map[string]any{"library": lib, "gaps": gaps, "feedback": fbs, "learnedPhotos": learned, "pendingPhotos": pending})
}

// Confidence thresholds for identify (see clear() in brainIdentify).
const confTop, confLead, confRatio = 0.55, 0.3, 2.5

// POST /v1/brain/identify {photo}: names a plant from a photo with our own model, matched to our species list.
func (s *Server) brainIdentify(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Photo, Lang string
		Photos      []shot `json:"photos"` // multi-photo scan: 1-8 {photo, kind}
		Scene       *bool  `json:"scene"`  // false: species only, with the quick BioCLIP-only scene (no vision model)
		SceneV      int    `json:"sceneV"` // 2: the app reads the {value, conf} scene; older apps fail to decode it, so they get none
	}
	if decode(r, &in) != nil || len(in.Photo) > 1_800_000 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ss, err := shots(in.Photo, in.Photos)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if theBrain.dir == "" {
		theBrain.dir = s.cfg.ContentDir
	}
	// Hard deadlines: the whole identify answers within 6 s whatever happens; our own model gets 3 s, a paid or
	// free external model only what is left (never the vision model: that only warms in the background).
	ctx, cancel := context.WithTimeout(context.WithoutCancel(r.Context()), 6*time.Second)
	defer cancel()
	theBrain.species()
	type cand struct {
		ID         string  `json:"id"`
		Scientific string  `json:"scientific"`
		Name       string  `json:"name"`
		Score      float64 `json:"score"`
	}
	out := []cand{} // never null in the reply
	add := func(id string, score float64) {
		speciesDB.RLock()
		sp := speciesDB.byID[id]
		speciesDB.RUnlock()
		if sp == nil {
			return
		}
		for _, c := range out {
			if c.ID == id {
				return
			}
		}
		name := sp.En
		if strings.HasPrefix(in.Lang, "pt") && sp.Pt != "" {
			name = sp.Pt
		}
		out = append(out, cand{sp.ID, sp.Scientific, name, math.Round(score*100) / 100})
	}
	// 1. Our own species model (BioCLIP over our list), with the stronger outside model started alongside it.
	source := "internal"
	main := pick(ss, "whole", "leaf", "flower", "stem", "other")
	in.Photo = ss[main].Photo
	type strongRes struct {
		c   []extCand
		src string
	}
	var strong chan strongRes
	if strongAvailable() {
		strong = make(chan strongRes, 1)
		sctx, scancel := context.WithTimeout(ctx, strongBudget)
		go func() { defer scancel(); c, src := s.strongID(sctx, in.Photo); strong <- strongRes{c, src} }()
	}
	// Cheap first: BioCLIP + the photo's own stats answer in well under a second. The vision model only warms
	// the whole scene in the background when the species is unsure or the quick scene can't tell the medium,
	// pot or a fake plant; the care-plan or diagnosis that follows then gets it from the cache.
	mctx, mcancel := context.WithTimeout(ctx, 3*time.Second)
	if len(ss) > 1 {
		mctx = context.WithValue(mctx, oneViewKey{}, true)
	}
	sc := fuseScene(mctx, ss)
	ids := fuseSpecies(mctx, ss)
	mcancel()
	_, full := cachedFull(in.Photo)
	if !full && (in.Scene == nil || *in.Scene) && (len(ids) == 0 || ids[0].Score < 0.5 || sc.needsFull()) {
		warmScene(in.Photo)
	}
	for _, c := range ids {
		if c.Score >= 0.05 {
			add(c.ID, c.Score)
		}
	}
	// 2. Calibrated on the eval (209 photos): a lead of 0.55, or 0.3 with 2.5x the runner-up, is right 95%+ of
	// the time. Scores are group sums (a species with its cultivars), so a split between cultivars counts once.
	clear := func() bool {
		return len(out) > 0 && (out[0].Score >= confTop || (out[0].Score >= confLead && (len(out) == 1 || out[0].Score >= confRatio*out[1].Score)))
	}
	// 3. Unsure: the stronger outside model, when one is configured, wins when it is sure (it had the same head start).
	if strong != nil && !clear() {
		r := <-strong
		var ext []cand
		for _, c := range r.c {
			if sp, _ := matchExt(c); sp != nil {
				ext = append(ext, cand{ID: sp.ID, Score: c.Confidence})
			}
		}
		if len(ext) > 0 && (ext[0].Score >= 0.5 || len(out) == 0 || ext[0].ID == out[0].ID) {
			agree := len(out) > 0 && ext[0].ID == out[0].ID
			prev := out
			out = []cand{}
			for _, c := range ext {
				add(c.ID, c.Score)
			}
			for _, c := range prev {
				add(c.ID, c.Score*0.5)
			}
			if agree {
				out[0].Score = math.Max(out[0].Score, prev[0].Score) + 0.3
				out[0].Score = math.Min(1, math.Round(out[0].Score*100)/100)
			}
			source = r.src
		}
	}
	if len(out) > 3 {
		out = out[:3]
	}
	confident := clear()
	if len(out) == 0 {
		s.gap(ctx, "identify", "unknown plant")
	} else if !confident {
		// Possibly out of our catalog: log the nearest genus so the list can grow where people need it.
		speciesDB.RLock()
		g := strings.Fields(speciesDB.byID[out[0].ID].Scientific + " x")[0]
		speciesDB.RUnlock()
		s.gap(ctx, "identify", "unsure "+g)
	}
	depth := "quick"
	if full {
		depth = "full"
	}
	top := 0.0
	if len(out) > 0 {
		top = out[0].Score
	}
	if confident {
		top = max(top, 0.75)
	}
	reply := map[string]any{"candidates": out, "confident": confident, "source": source, "sceneDepth": depth,
		"used": kindsOf(ss), "tips": photoTips(in.Lang, top, kindsOf(ss), "leaf", "whole", "flower", "stem")}
	if in.SceneV >= 2 {
		reply["scene"] = sc
	}
	writeJSON(w, http.StatusOK, reply)
}

// POST /v1/brain/care-plan {species, situation, lat?, lon?}: watering rhythm, light, feeding, repotting and
// warnings for this plant where it actually lives.
func (s *Server) brainCarePlan(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Species   string              `json:"species"`
		Lang      string              `json:"lang"`
		Situation map[string][]string `json:"situation"`
		Lat, Lon  *float64
		Photo     string `json:"photo"`  // optional: what the photo shows joins the situation
		Photos    []shot `json:"photos"` // or several (pot and soil photos tell the medium, drainage and size)
		extras
	}
	if decode(r, &in) != nil || len(in.Species) > 120 || len(in.Photo) > 1_800_000 {
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
	var sc *scene
	var used []string
	if in.Photo != "" || len(in.Photos) > 0 {
		ss, err := shots(in.Photo, in.Photos)
		if err != nil {
			s.fail(w, r, err)
			return
		}
		used = kindsOf(ss)
		ctx, cancel := context.WithTimeout(context.WithoutCancel(r.Context()), 85*time.Second)
		got := fuseScene(ctx, ss, pick(ss, "pot", "soil", "whole"))
		cancel()
		sc = &got
		sit = got.situation(sit)
	}
	sit = in.extras.into(sit)
	wf := resolveWeather(r.Context(), in.extras.Weather, in.Lat, in.Lon)
	sit = mergeSit(sit, wf.situation())
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
	if (sp.ToxicCats || sp.ToxicDogs) && has("near", "pet") {
		notes = append(notes, "A pet is close by and this plant is toxic to pets. Keep it out of reach.")
	}
	if has("pot", "no-drainage") && has("moisture", "wet") {
		notes = append(notes, "The pot has no drainage hole and the soil looks wet: the roots are at risk of rotting.")
	}
	lang := in.Lang
	if lang == "" || strings.HasPrefix(lang, "en") {
		lang = "en"
	}
	for i := range notes {
		notes[i] = theBrain.tr(lang, notes[i])
	}
	fit, _ := theBrain.situational(sit)
	fit = forSpecies(fit, sp)
	var advice, adviceIDs []string
	for i, f := range fit {
		if i == 4 {
			break
		}
		advice = append(advice, theBrain.tr(lang, f.Advice))
		adviceIDs = append(adviceIDs, f.ID)
	}
	feed := sp.FeedWeeks
	if has("season", "winter") {
		feed = 0 // rest
	}
	medium, style, mix, feedKind := "soil", sp.WaterStyle, sp.Mix, sp.Feed
	if m := sit["medium"]; len(m) > 0 {
		medium = m[0]
	}
	if has("lifeStage", "dormant") {
		f *= 1.6
	}
	if has("room", "outdoor", "balcony") && has("weather", "rainy") {
		f *= 1.8 // rain counts as watering
	}
	if wf != nil && isOutdoor(sit) && wf.Rain7 >= 25 {
		f *= 1.3 // a properly wet week on top
	}
	water := [2]int{int(lo*f + 0.5), int(hi*f + 0.5)}
	mc, ok := mediumCare[medium]
	if ok {
		style, water = mc.style, mc.every
		if mc.mix != "" {
			mix = mc.mix
		}
		if mc.feed != "" {
			feedKind = mc.feed
			if feed > 0 || !has("season", "winter") {
				feed = 4
			}
		}
	}
	var care []string
	for _, c := range mc.steps {
		care = append(care, theBrain.tr(lang, c))
	}
	if has("lifeStage", "repotted", "dormant", "recovering", "acclimating", "cutting") || has("plant", "artificial") {
		feed = 0
	}
	type follow struct {
		InDays      int    `json:"inDays"`
		RepeatEvery int    `json:"repeatEveryDays,omitempty"`
		Times       int    `json:"times,omitempty"`
		What        string `json:"what"`
	}
	var follows []follow
	fu := func(in, every, times int, what string) {
		follows = append(follows, follow{in, every, times, theBrain.tr(lang, what)})
	}
	switch medium {
	case "water":
		fu(8, 8, 0, "Swap the water and rinse the glass.")
	case "leca", "pon":
		fu(10, 10, 0, "Check the reservoir and top up with nutrient water.")
	}
	if has("lifeStage", "repotted") {
		fu(35, 0, 0, "Start feeding again: the roots have settled.")
	}
	if has("lifeStage", "acclimating") {
		fu(3, 0, 0, "Check the leaves and soil: a few dropped leaves are normal while it settles in.")
		fu(14, 0, 0, "Settled in? If new growth shows, go back to the normal routine.")
	}
	if has("lifeStage", "cutting") {
		fu(14, 7, 4, "Check for roots and refresh the water or keep the mix just moist.")
	}
	if has("lifeStage", "unknown_history") {
		fu(7, 7, 2, "Check under the leaves for pests before it joins the other plants.")
	}
	for _, p := range sit["treating"] {
		if len(p) < 40 {
			fu(6, 6, 3, "Repeat the pest treatment and check under the leaves.")
			fu(21, 0, 0, "Two clean checks in a row? It can rejoin the other plants.")
			break
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"species": sp.ID, "waterEveryDays": water, "waterStyle": style, "medium": medium, "mediumCare": care,
		"light": sp.Light, "humidityMin": sp.HumidityMin, "tempRange": [2]float64{sp.TempMin, sp.TempMax},
		"feedEveryWeeks": feed, "feed": feedKind, "mix": mix, "repotEveryYears": sp.RepotYears,
		"toxicCats": sp.ToxicCats, "toxicDogs": sp.ToxicDogs, "tip": theBrain.tr(lang, sp.Tip),
		"warnings": notes, "advice": advice, "adviceIds": adviceIDs, "followUps": follows, "weatherNotes": wf.notes(lang, isOutdoor(sit), sp), "situation": sit, "scene": sc,
		"used": used, "tips": carePlanTips(lang, sc, used, in.Medium != "" || len(in.Situation["medium"]) > 0),
	})
}

// carePlanTips: when photos were sent but the medium or pot is still unsure, which photo would settle it.
func carePlanTips(lang string, sc *scene, used []string, mediumGiven bool) []photoTip {
	if sc == nil || len(used) == 0 {
		return []photoTip{}
	}
	conf := min(sc.Soil.Medium.Conf, sc.Pot.Drainage.Conf)
	if mediumGiven {
		conf = sc.Pot.Drainage.Conf
	}
	return photoTips(lang, conf, used, "pot", "soil", "whole")
}

type bioCand struct {
	ID    string  `json:"id"`
	Score float64 `json:"score"`
}

// mediumCare: plants not in soil follow their medium's rhythm, never a soil dry-out rhythm.
// style: refresh (swap the water) | reservoir (top up a reservoir) | soak | mist | closed (terrarium).
var mediumCare = map[string]struct {
	style, mix, feed string
	every            [2]int
	steps            []string
}{
	"water": {"refresh", "water", "hydro-quarter", [2]int{7, 10}, []string{
		"Swap the water every 7–10 days and top it up in between so the roots stay covered.",
		"Feed at quarter strength with a liquid fertiliser once a month.",
		"Rinse the glass if green algae or slime appear, and trim any brown, mushy roots.",
		"Move it into soil once the roots are 5–10 cm long, or keep it in water for good.",
	}},
	"leca": {"reservoir", "leca", "hydro", [2]int{7, 14}, []string{
		"Keep the water reservoir at about a third of the pot's height, with the roots above it.",
		"Let the reservoir run almost dry for a day or two before refilling, so the roots get air.",
		"Add hydro nutrient at every refill and flush with plain water once a month.",
		"Rinse the balls when a white salt crust builds up.",
	}},
	"pon": {"reservoir", "pon", "hydro", [2]int{7, 14}, []string{
		"Keep the water reservoir at about a third of the pot's height, with the roots above it.",
		"Let the reservoir run almost dry for a day or two before refilling, so the roots get air.",
		"Add hydro nutrient at every refill and flush with plain water once a month.",
	}},
	"sphagnum": {"soak", "sphagnum", "", [2]int{5, 8}, []string{
		"Soak the moss when it feels light and only just damp, then let it drain well.",
		"Never let the moss go crispy, and never leave it soggy.",
		"Replace the moss once a year, when it turns slimy.",
	}},
	"mounted": {"mist", "mounted", "", [2]int{2, 4}, []string{
		"Mist daily, or soak the mount for 10–20 minutes two or three times a week.",
		"Let the roots turn silvery dry between soaks.",
		"Keep the air humid: mounted plants dry out fast.",
	}},
	"terrarium": {"closed", "terrarium", "", [2]int{30, 90}, []string{
		"Water only when the glass stops fogging in the morning; a closed terrarium may go months without water.",
		"Open the lid for an hour if the glass stays fogged all day.",
	}},
}

// Scenario subjects: a scenario whose id names a kind of plant ("heater-succulent", "tomato-rain") only applies
// to plants of that kind. Each subject lists words that must appear in the species' id, group, names or tags.
var scenarioSubjects = map[string][]string{
	"succulent": {"succulent", "cactus", "epicactus", "aloe", "haworth", "echeveria", "crassula", "sedum", "senecio", "curio", "kalanchoe"},
	"cactus":    {"cactus", "epicactus"}, "desert": {"cactus", "succulent"},
	"orchid": {"orchid", "phalaenopsis"}, "fern": {"fern", "nephrolepis", "adiantum", "asplenium", "platycerium"},
	"tomato": {"tomato", "solanum lycopersicum"}, "herbs": {"herb"}, "herb": {"herb"}, "basil": {"basil", "ocimum"}, "mint": {"mint", "mentha"},
	"citrus": {"citrus", "lime", "lemon", "mandarin", "orange", "grapefruit"}, "calathea": {"prayer", "calathea", "goeppertia", "maranta", "ctenanthe", "stromanthe"},
	"monstera": {"monstera"}, "alocasia": {"alocasia"}, "fig": {"ficus"}, "ficus": {"ficus"}, "roses": {"rosa", "rose"}, "rose": {"rosa", "rose"},
	"pothos": {"epipremnum", "pothos", "scindapsus"}, "snake": {"sansevieria", "trifasciata", "snake"}, "peace": {"spathiphyllum"},
	"ivy": {"hedera", "ivy"}, "bulbs": {"bulb"}, "veg": {"vegetable"}, "vegetables": {"vegetable"}, "fruit": {"fruit", "citrus", "strawberr", "fig", "olive"},
	"lilies": {"lilium", "lily"}, "box": {"buxus", "box"}, "carnivorous": {"carnivorous"}, "bromeliad": {"bromeliad"}, "palm": {"palm"},
	"violet": {"violet", "saintpaulia"}, "tropical": {"tropical", "aroid", "prayer", "palm", "bromeliad"}, "bonsai": {"bonsai"}, "strawberry": {"strawberr"},
}

// forSpecies keeps the scenarios that fit this plant and puts plant-specific ones first.
func forSpecies(fit []scenario, sp *species) []scenario {
	text := ""
	if sp != nil {
		text = strings.ToLower(strings.Join(append([]string{sp.ID, sp.Group, sp.Scientific, sp.En, sp.Mix}, sp.Tags...), " "))
	}
	var specific, general []scenario
	for _, sc := range fit {
		subject, match := false, false
		for _, part := range strings.Split(sc.ID, "-") {
			if words, ok := scenarioSubjects[part]; ok {
				subject = true
				for _, w := range words {
					match = match || strings.Contains(text, w)
				}
			}
		}
		switch {
		case subject && match:
			specific = append(specific, sc)
		case !subject:
			general = append(general, sc)
		}
	}
	return append(specific, general...)
}
