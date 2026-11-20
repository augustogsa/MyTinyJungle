package api

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"net/http"
	"os"
	"strings"
	"time"
)

// Stronger second opinion for identify: Pl@ntNet (dedicated plant ID), Gemini 2.5 Flash or Claude, whichever MTJ
// key is set in /opt/mtj/secrets/api.env (MTJ_PLANTNET_KEY, MTJ_GEMINI_KEY, MTJ_AI_KEY). It starts with our own
// model, in parallel, and gets strongBudget from the start of the request; its answer only counts when our model
// is unsure, and each answer is cached per photo.

const strongBudget = 2500 * time.Millisecond

type extCand struct {
	Scientific, Common string
	Confidence         float64
}

func strongAvailable() bool {
	return os.Getenv("MTJ_PLANTNET_KEY") != "" || os.Getenv("MTJ_GEMINI_KEY") != "" || os.Getenv("MTJ_AI_KEY") != ""
}

const strongPrompt = "Identify this plant (houseplant, garden plant, herb, vegetable, succulent or flower). Look at leaf shape, " +
	"venation, variegation, growth habit and any flowers. Answer only with JSON: " +
	"{\"candidates\":[{\"scientific\":\"Genus species\",\"common\":\"...\",\"confidence\":0.0}]} with up to three guesses, most likely first; " +
	"confidence is your probability of being right. Name the species, not a cultivar, unless the cultivar is unmistakable."

// strongID asks the best configured outside model; source is "plantnet", "free" or "claude".
func (s *Server) strongID(ctx context.Context, photo string) ([]extCand, string) {
	ek := answerKey("idstrong", fmt.Sprintf("%x", photoKey(photo)))
	if v, ok := answers.get(ek); ok {
		r := v.(strongAnswer)
		return r.c, r.src
	}
	type res struct {
		c   []extCand
		src string
	}
	ch := make(chan res, 3)
	n := 0
	if k := os.Getenv("MTJ_PLANTNET_KEY"); k != "" {
		n++
		go func() { ch <- res{plantNet(ctx, k, photo), "plantnet"} }()
	}
	if os.Getenv("MTJ_GEMINI_KEY") != "" {
		n++
		go func() {
			t, _ := geminiText(ctx, photo, strongPrompt)
			ch <- res{parseExt(t), "free"}
		}()
	} else if os.Getenv("MTJ_AI_KEY") != "" {
		n++
		go func() {
			t, _ := s.claudeText(ctx, photo, strongPrompt)
			ch <- res{parseExt(t), "claude"}
		}()
	}
	var best res
	for ; n > 0; n-- {
		select {
		case r := <-ch:
			if len(r.c) > 0 && (len(best.c) == 0 || r.c[0].Confidence > best.c[0].Confidence) {
				best = r
			}
		case <-ctx.Done():
			n = 0
		}
	}
	if len(best.c) > 0 {
		answers.put(ek, strongAnswer{best.c, best.src})
	}
	return best.c, best.src
}

type strongAnswer struct {
	c   []extCand
	src string
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

// plantNet: Pl@ntNet identify API (organs auto); scores are probabilities over its flora.
func plantNet(ctx context.Context, key, photo string) []extCand {
	raw, err := base64.StdEncoding.DecodeString(photo)
	if err != nil {
		return nil
	}
	var body bytes.Buffer
	mw := multipart.NewWriter(&body)
	fw, _ := mw.CreateFormFile("images", "plant.jpg")
	fw.Write(raw)
	mw.WriteField("organs", "auto")
	mw.Close()
	req, _ := http.NewRequestWithContext(ctx, "POST", "https://my-api.plantnet.org/v2/identify/all?nb-results=3&lang=en&api-key="+key, &body)
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
			}
		}
	}
	if res.StatusCode != 200 || json.NewDecoder(res.Body).Decode(&out) != nil {
		return nil
	}
	var c []extCand
	for _, r := range out.Results {
		e := extCand{Scientific: r.Species.ScientificNameWithoutAuthor, Confidence: r.Score}
		if len(r.Species.CommonNames) > 0 {
			e.Common = r.Species.CommonNames[0]
		}
		c = append(c, e)
	}
	return c
}

// matchExt maps an outside name onto our catalog: the species, else the genus entry or the first species of that
// genus (nearest care), ok=false when nothing of that genus is in the catalog.
func matchExt(c extCand) (*species, bool) {
	if sp := theBrain.findSpecies(c.Scientific); sp != nil {
		return sp, true
	}
	if sp := theBrain.findSpecies(c.Common); sp != nil {
		return sp, true
	}
	g := strings.ToLower(strings.Fields(c.Scientific + " x")[0])
	speciesDB.RLock()
	defer speciesDB.RUnlock()
	var first *species
	for i := range speciesDB.list {
		sp := &speciesDB.list[i]
		f := strings.Fields(strings.ToLower(strings.ReplaceAll(sp.Scientific, "×", "")))
		if len(f) == 0 || f[0] != g {
			continue
		}
		if len(f) == 1 || strings.HasSuffix(sp.Scientific, "spp.") {
			return sp, false
		}
		if first == nil {
			first = sp
		}
	}
	return first, false
}
