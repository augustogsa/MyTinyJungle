package api

import (
	"context"
	"sort"
	"sync"
)

// Multi-photo scans: up to 8 photos of one plant, each with a kind. Every photo is normalised and cached by its
// own sha256; the request is charged once whatever the count.
//   species: BioCLIP on every photo, fused by a weighted mean (leaf, flower and whole weigh most);
//   scene:   the vision model reads the most telling photo for the question (pot/soil for care, underside/leaf
//            and soil for a diagnosis), the rest add their quick scene; pot and soil fields come from pot and
//            soil photos, leaf issues from all of them;
//   tips:    when confidence is below 0.7, the next most useful photo to add.

type shot struct {
	Photo string `json:"photo"`
	Kind  string `json:"kind"`
}

var shotKinds = map[string]float64{ // weight in the species vote
	"leaf": 1, "flower": 1, "whole": 1, "stem": 0.6, "underside": 0.5, "other": 0.5, "roots": 0.2, "pot": 0.15, "soil": 0.05,
}

// shots validates and normalises photo or photos (1-8). The first photo is the primary one.
func shots(single string, list []shot) ([]shot, error) {
	if single != "" {
		list = append([]shot{{single, "whole"}}, list...)
	}
	if len(list) == 0 || len(list) > 8 {
		return nil, bad("invalid_request")
	}
	out := make([]shot, len(list))
	for i, s := range list {
		if s.Kind == "" {
			s.Kind = "other"
		}
		if _, ok := shotKinds[s.Kind]; !ok || len(s.Photo) == 0 || len(s.Photo) > 1_800_000 {
			return nil, bad("invalid_request")
		}
		p, err := normPhoto(s.Photo)
		if err != nil {
			return nil, err
		}
		out[i] = shot{p, s.Kind}
	}
	return out, nil
}

func kindsOf(ss []shot) []string {
	k := make([]string, len(ss))
	for i, s := range ss {
		k[i] = s.Kind
	}
	return k
}

// fuseSpecies: BioCLIP per photo (in parallel, cached), then a weighted mean of each species' score.
func fuseSpecies(ctx context.Context, ss []shot) []bioCand {
	res := make([]idResult, len(ss))
	var wg sync.WaitGroup
	for i, s := range ss {
		wg.Add(1)
		go func() { defer wg.Done(); res[i] = askID(ctx, s.Photo) }()
	}
	wg.Wait()
	if len(ss) == 1 {
		return res[0].Candidates
	}
	sum, total := map[string]float64{}, 0.0
	first := map[string]int{}
	for i, r := range res {
		if len(r.Candidates) == 0 {
			continue
		}
		w := shotKinds[ss[i].Kind]
		total += w
		for j, c := range r.Candidates {
			sum[c.ID] += w * c.Score
			if _, ok := first[c.ID]; !ok {
				first[c.ID] = i*10 + j
			}
		}
	}
	if total == 0 {
		return nil
	}
	out := make([]bioCand, 0, len(sum))
	for id, v := range sum {
		out = append(out, bioCand{ID: id, Score: v / total})
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].Score != out[j].Score {
			return out[i].Score > out[j].Score
		}
		return first[out[i].ID] < first[out[j].ID]
	})
	if len(out) > 5 {
		out = out[:5]
	}
	return out
}

// pick returns the first photo whose kind is in prefer (in that order), else the first photo.
func pick(ss []shot, prefer ...string) int {
	for _, k := range prefer {
		for i, s := range ss {
			if s.Kind == k {
				return i
			}
		}
	}
	return 0
}

// fuseScene: the whole scene of the most telling photos (vision model, up to two in parallel) merged with the
// quick scene of the rest. Fields come from the photo kinds that show them best.
func fuseScene(ctx context.Context, ss []shot, full ...int) scene {
	scs := make([]scene, len(ss))
	isFull := map[int]bool{}
	for _, i := range full {
		isFull[i] = true
	}
	var wg sync.WaitGroup
	for i, s := range ss {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if isFull[i] {
				scs[i], _ = readScene(ctx, s.Photo)
			} else {
				scs[i], _ = quickScene(ctx, s.Photo)
			}
		}()
	}
	wg.Wait()
	base := pick(ss, "whole", "leaf", "other", "stem", "flower")
	if len(full) > 0 && !isFull[base] {
		base = full[0]
	}
	out := scs[base]
	if len(ss) == 1 {
		return out
	}
	// best: the most confident value among photos of the preferred kinds (any photo when none of those kinds).
	best := func(get func(*scene) *sv, kinds ...string) {
		want := map[string]bool{}
		for _, k := range kinds {
			want[k] = true
		}
		var bv *sv
		for _, strict := range []bool{true, false} {
			for i := range scs {
				if strict && !want[ss[i].Kind] {
					continue
				}
				v := get(&scs[i])
				if known(svStr(v.Value)) && (bv == nil || v.Conf > bv.Conf) {
					c := *v
					bv = &c
				}
			}
			if bv != nil {
				break
			}
		}
		if bv != nil {
			*get(&out) = *bv
		}
	}
	best(func(s *scene) *sv { return &s.Soil.Medium }, "soil", "pot")
	best(func(s *scene) *sv { return &s.Soil.Moisture }, "soil")
	best(func(s *scene) *sv { return &s.Pot.Material }, "pot")
	best(func(s *scene) *sv { return &s.Pot.Drainage }, "pot")
	best(func(s *scene) *sv { return &s.Pot.DiameterCm }, "pot")
	best(func(s *scene) *sv { return &s.Pot.Rootbound }, "pot", "roots")
	best(func(s *scene) *sv { return &s.Plant.Artificial }, "leaf", "whole")
	// Issues and surface items: the union, highest confidence per kind.
	iss := map[string]sceneIssue{}
	surf := map[string]sceneItem{}
	for _, sc := range scs {
		for _, x := range sc.Plant.Issues {
			if y, ok := iss[x.Kind]; !ok || x.Conf > y.Conf {
				iss[x.Kind] = x
			}
		}
		for _, x := range sc.Soil.Surface {
			if y, ok := surf[x.Item]; !ok || x.Conf > y.Conf {
				surf[x.Item] = x
			}
		}
	}
	out.Plant.Issues, out.Soil.Surface = nil, nil
	for _, x := range iss {
		out.Plant.Issues = append(out.Plant.Issues, x)
	}
	for _, x := range surf {
		out.Soil.Surface = append(out.Soil.Surface, x)
	}
	sort.Slice(out.Plant.Issues, func(i, j int) bool { return out.Plant.Issues[i].Conf > out.Plant.Issues[j].Conf })
	sort.Slice(out.Soil.Surface, func(i, j int) bool { return out.Soil.Surface[i].Conf > out.Soil.Surface[j].Conf })
	return out
}

func svStr(v any) string {
	s, _ := v.(string)
	if s == "" && v != nil {
		return "x" // numbers and booleans count as known
	}
	return s
}

type photoTip struct {
	Kind string `json:"kind"`
	Why  string `json:"why"`
}

var tipText = map[string]string{
	"leaf":      "Add a sharp close-up of one leaf in daylight",
	"underside": "Add a close-up of a leaf underside to check for mites",
	"flower":    "Add a photo of a flower if it has one",
	"whole":     "Add a photo of the whole plant from a step back",
	"stem":      "Add a close-up of the stem where it meets the soil",
	"soil":      "Add a photo of the soil surface to check moisture, mould and gnats",
	"pot":       "Add a photo of the pot from the side to see its size and drainage",
	"roots":     "Add a photo of the roots if you can slide the plant out",
}

// photoTips: up to two photos worth adding, most useful first, when confidence is below 0.7.
func photoTips(lang string, conf float64, have []string, order ...string) []photoTip {
	out := []photoTip{}
	if conf >= 0.7 {
		return out
	}
	got := map[string]bool{}
	for _, k := range have {
		got[k] = true
	}
	for _, k := range order {
		if !got[k] && len(out) < 2 {
			out = append(out, photoTip{k, theBrain.tr(lang, tipText[k])})
		}
	}
	return out
}

func confNum(c string) float64 {
	switch c {
	case "high":
		return 0.85
	case "medium":
		return 0.6
	}
	return 0.3
}
