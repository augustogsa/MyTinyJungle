package api

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"mime/multipart"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

// Second opinion for identify when our own model is unsure:
//   Pl@ntNet (dedicated plant ID, ~0.3 s, free plan 500 a day: MTJ_PLANTNET_KEY) with every photo of the scan and
//   its organ, fused with BioCLIP; when Pl@ntNet is out of budget, Gemini (MTJ_GEMINI_KEY) or Claude (MTJ_AI_KEY)
//   with what is left of the request. Answers are cached by the photos' sha256.

type extCand struct {
	Scientific, Common, Genus, Family string
	Confidence                        float64
}

// strongBudget: our model plus the second opinion stay inside the 3 s p95.
const strongBudget = 2900 * time.Millisecond

const plantNetDaily = 500 // free plan; we stop at plantNetReserve left and warn at 80% used
const plantNetReserve = 20

var plantNetQuota struct {
	sync.Mutex
	day             string
	used, remaining int
	warned          bool
}

// plantNetAllowed: a key is set and today's budget isn't spent (Pl@ntNet's own remaining count when known).
func plantNetAllowed() bool {
	if os.Getenv("MTJ_PLANTNET_KEY") == "" {
		return false
	}
	q := &plantNetQuota
	q.Lock()
	defer q.Unlock()
	if d := time.Now().UTC().Format("2006-01-02"); d != q.day {
		q.day, q.used, q.remaining, q.warned = d, 0, plantNetDaily, false
	}
	return q.remaining > plantNetReserve && q.used < plantNetDaily-plantNetReserve
}

func plantNetCount(remaining int) {
	q := &plantNetQuota
	q.Lock()
	defer q.Unlock()
	q.used++
	if remaining >= 0 {
		q.remaining = remaining
	} else {
		q.remaining--
	}
	if !q.warned && (q.used >= plantNetDaily*8/10 || q.remaining <= plantNetDaily*2/10) {
		q.warned = true
		slog.Warn("plantnet_quota_80", "used", q.used, "remaining", q.remaining)
	}
}

// PlantNetUsage for the admin views.
func PlantNetUsage() map[string]any {
	q := &plantNetQuota
	q.Lock()
	defer q.Unlock()
	return map[string]any{"day": q.day, "used": q.used, "remaining": q.remaining, "limit": plantNetDaily}
}

var plantNetOrgan = map[string]string{"leaf": "leaf", "flower": "flower", "whole": "habit", "stem": "bark", "underside": "leaf"}

// plantNet: Pl@ntNet identify with up to 5 photos, each with its organ (auto for other kinds).
func plantNet(ctx context.Context, key string, ss []shot) []extCand {
	var body bytes.Buffer
	mw := multipart.NewWriter(&body)
	n := 0
	for _, s := range ss {
		if n == 5 {
			break
		}
		organ, ok := plantNetOrgan[s.Kind]
		if !ok {
			if s.Kind == "pot" || s.Kind == "soil" || s.Kind == "roots" {
				continue
			}
			organ = "auto"
		}
		raw, err := base64.StdEncoding.DecodeString(s.Photo)
		if err != nil {
			continue
		}
		fw, _ := mw.CreateFormFile("images", fmt.Sprintf("p%d.jpg", n))
		fw.Write(raw)
		mw.WriteField("organs", organ)
		n++
	}
	mw.Close()
	if n == 0 {
		return nil
	}
	req, _ := http.NewRequestWithContext(ctx, "POST", "https://my-api.plantnet.org/v2/identify/all?nb-results=5&lang=en&api-key="+key, &body)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil
	}
	defer res.Body.Close()
	var out struct {
		Results []struct {
			Score   float64
			Species struct {
				ScientificNameWithoutAuthor string
				CommonNames                 []string
				Genus, Family               struct{ ScientificNameWithoutAuthor string }
			}
		}
		Remaining *int `json:"remainingIdentificationRequests"`
	}
	if res.StatusCode == 404 { // "Species not found": a valid answer that counts
		plantNetCount(-1)
		return []extCand{}
	}
	if res.StatusCode != 200 || json.NewDecoder(res.Body).Decode(&out) != nil {
		return nil
	}
	rem := -1
	if out.Remaining != nil {
		rem = *out.Remaining
	}
	plantNetCount(rem)
	c := []extCand{}
	for _, r := range out.Results {
		e := extCand{Scientific: r.Species.ScientificNameWithoutAuthor, Confidence: r.Score,
			Genus: r.Species.Genus.ScientificNameWithoutAuthor, Family: r.Species.Family.ScientificNameWithoutAuthor}
		if len(r.Species.CommonNames) > 0 {
			e.Common = r.Species.CommonNames[0]
		}
		c = append(c, e)
	}
	return c
}

const strongPrompt = "Identify this plant (houseplant, garden plant, herb, vegetable, succulent or flower). Look at leaf shape, " +
	"venation, variegation, growth habit and any flowers. Answer only with JSON: " +
	"{\"candidates\":[{\"scientific\":\"Genus species\",\"common\":\"...\",\"confidence\":0.0}]} with up to three guesses, most likely first; " +
	"confidence is your probability of being right. Name the species, not a cultivar, unless the cultivar is unmistakable."

type strongAnswer struct {
	c   []extCand
	src string
}

// strongID: Pl@ntNet when allowed, else Gemini or Claude on the main photo. source "plantnet", "free" or "claude".
func (s *Server) strongID(ctx context.Context, ss []shot, main string) ([]extCand, string) {
	h := sha256.New()
	for _, x := range ss {
		h.Write([]byte(x.Kind + ":" + x.Photo + "|"))
	}
	ek := answerKey("idstrong", fmt.Sprintf("%x", h.Sum(nil)))
	if v, ok := answers.get(ek); ok {
		r := v.(strongAnswer)
		return r.c, r.src
	}
	var r strongAnswer
	if plantNetAllowed() {
		r = strongAnswer{plantNet(ctx, os.Getenv("MTJ_PLANTNET_KEY"), ss), "plantnet"}
	} else if os.Getenv("MTJ_GEMINI_KEY") != "" {
		t, _ := geminiText(ctx, main, strongPrompt)
		r = strongAnswer{parseExt(t), "free"}
	} else if os.Getenv("MTJ_AI_KEY") != "" {
		t, _ := s.claudeText(ctx, main, strongPrompt)
		r = strongAnswer{parseExt(t), "claude"}
	}
	if r.c != nil {
		answers.put(ek, r)
	}
	return r.c, r.src
}

func strongAvailable() bool {
	return os.Getenv("MTJ_PLANTNET_KEY") != "" || os.Getenv("MTJ_GEMINI_KEY") != "" || os.Getenv("MTJ_AI_KEY") != ""
}

func parseExt(raw string) []extCand {
	i, j := strings.Index(raw, "{"), strings.LastIndex(raw, "}")
	if i < 0 || j <= i {
		return nil
	}
	var g struct{ Candidates []extCand }
	if json.Unmarshal([]byte(raw[i:j+1]), &g) != nil {
		return nil
	}
	return g.Candidates
}

// matchExt maps an outside name onto our catalog: exact = the binomial (or an alias) is ours; otherwise the genus
// entry ("Lithops spp.", "Goeppertia"), the family entry ("Cactaceae"), or the first species of that genus.
// plantNetSynonyms: accepted names Pl@ntNet uses where our catalog keeps the trade name.
var plantNetSynonyms = map[string]string{
	"dracaena reflexa var. angustifolia": "dracaena-marginata", "dracaena marginata": "dracaena-marginata",
	"sansevieria trifasciata": "sansevieria", "schlumbergera x buckleyi": "schlumbergera", "schlumbergera truncata": "schlumbergera",
	"epipremnum pinnatum 'aureum'": "epipremnum-aureum", "calathea ornata": "calathea-ornata", "calathea zebrina": "calathea-zebrina",
	"calathea orbifolia": "goeppertia-orbifolia", "aloe barbadensis": "aloe-vera", "heptapleurum arboricola": "schefflera-arboricola",
	"curio rowleyanus": "senecio-rowleyanus", "chamaedorea elegans": "chamaedorea",
}

// plantNetLumps: names Pl@ntNet uses for several of our entries (Dracaena marginata is now D. reflexa var.
// angustifolia, and Pl@ntNet answers plain D. reflexa for both); our own model picks between them.
var plantNetLumps = map[string][]string{
	"dracaena reflexa": {"dracaena-marginata", "dracaena-reflexa"},
}

func matchExt(c extCand) (sp *species, exact bool) {
	theBrain.species()
	full := strings.ToLower(strings.Join(strings.Fields(strings.ReplaceAll(c.Scientific, "×", "x")), " "))
	if id, ok := plantNetSynonyms[full]; ok {
		speciesDB.RLock()
		x := speciesDB.byID[id]
		speciesDB.RUnlock()
		if x != nil {
			return x, true
		}
	}
	bin := strings.ToLower(strings.Join(strings.Fields(strings.ReplaceAll(c.Scientific, "×", ""))[:min(2, len(strings.Fields(c.Scientific)))], " "))
	genus := strings.ToLower(c.Genus)
	if genus == "" {
		genus = strings.Fields(bin + " x")[0]
	}
	fam := strings.ToLower(c.Family)
	speciesDB.RLock()
	defer speciesDB.RUnlock()
	var genusEntry, famEntry, first *species
	for i := range speciesDB.list {
		x := &speciesDB.list[i]
		if strings.Contains(x.Scientific, "'") {
			continue
		}
		f := strings.Fields(strings.ToLower(strings.ReplaceAll(x.Scientific, "×", "")))
		if len(f) == 0 {
			continue
		}
		if len(f) >= 2 && f[0]+" "+f[1] == bin {
			return x, true
		}
		for _, a := range x.Aliases {
			if a == bin {
				return x, true
			}
		}
		if f[0] == genus {
			if len(f) == 1 || f[1] == "spp." || f[1] == "hybrids" {
				genusEntry = x
			} else if first == nil {
				first = x
			}
		}
		if len(f) == 1 && fam != "" && f[0] == fam {
			famEntry = x
		}
	}
	for _, x := range []*species{genusEntry, famEntry, first} {
		if x != nil {
			return x, false
		}
	}
	return nil, false
}
