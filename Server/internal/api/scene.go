package api

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"image"
	_ "image/jpeg"
	"math"
	"net/http"
	"strings"
	"time"
)

// Scene: everything a plant photo shows besides the plant's name. Our own models only:
//   - the vision model (Qwen2.5-VL on 127.0.0.1:8091) fills one JSON object constrained by a schema
//     (grammar-enforced, so every value is one we understand),
//   - BioCLIP zero-shot (mtj-id, 127.0.0.1:8092) scores the categorical fields it is good at
//     (pot material, growing medium, room, light source and intensity, growth stage),
//   - image statistics and EXIF give rough lux and colour temperature.
// Agreement between the two models raises a field's confidence, disagreement lowers it. Every field is
// {value, conf}; value "unknown" (or null for numbers) with conf 0 when nothing could be read.

type sv struct {
	Value any     `json:"value"`
	Conf  float64 `json:"conf"`
}

type sceneItem struct {
	Item string  `json:"item"`
	Conf float64 `json:"conf"`
}

type sceneIssue struct {
	Kind  string  `json:"kind"`
	Conf  float64 `json:"conf"`
	Where string  `json:"where"`
}

type scene struct {
	Plant struct {
		HeightCm   sv           `json:"heightCm"`
		LeafCount  sv           `json:"leafCount"`
		Stage      sv           `json:"stage"`
		Issues     []sceneIssue `json:"issues"`
		Artificial sv           `json:"artificial"` // a fake plant
		Multiple   sv           `json:"multiple"`   // several plants in one pot
	} `json:"plant"`
	Pot struct {
		Material   sv `json:"material"`
		Drainage   sv `json:"drainage"`
		DiameterCm sv `json:"diameterCm"`
		Rootbound  sv `json:"rootbound"`
		Cachepot   sv `json:"cachepot"`
	} `json:"pot"`
	Soil struct {
		Medium   sv          `json:"medium"`
		Moisture sv          `json:"moisture"`
		Surface  []sceneItem `json:"surface"`
	} `json:"soil"`
	Light struct {
		Source         sv `json:"source"`
		NaturalPct     sv `json:"naturalPct"`
		DirectSun      sv `json:"directSun"`
		WindowDistance sv `json:"windowDistance"`
		WindowFacing   sv `json:"windowFacing"`
		Intensity      sv `json:"intensity"`
		Lux            sv `json:"lux"`
		Kelvin         sv `json:"kelvin"`
	} `json:"light"`
	Surroundings struct {
		Room         sv          `json:"room"`
		Near         []sceneItem `json:"near"`
		HumidityHint sv          `json:"humidityHint"`
	} `json:"surroundings"`
	saw string // the vision model's words about the leaves, used as diagnosis evidence
}

var sceneEnums = map[string][]string{
	"stage":          {"seedling", "juvenile", "mature"},
	"issue":          {"yellowing", "brown_tips", "brown_spots", "black_spots", "pale", "wilting", "drooping", "curling", "crispy", "mushy", "holes", "webbing", "insects", "white_powder", "white_fluff", "sticky", "mold", "leggy", "sunburn", "variegation_loss", "rot"},
	"where":          {"new_leaves", "old_leaves", "all_leaves", "stem", "soil", "roots", "flowers"},
	"material":       {"plastic", "terracotta", "ceramic_glazed", "glass", "metal", "basket_cachepot", "nursery", "self_watering", "hanging", "none"},
	"yesno":          {"yes", "no"},
	"medium":         {"soil", "chunky", "cactus", "leca", "pon", "sphagnum", "water", "mounted", "terrarium", "ground"},
	"moisture":       {"dry", "moist", "wet"},
	"surface":        {"stones", "pebbles", "eggshells", "bark", "moss", "perlite_top", "sand", "coffee_grounds", "mold", "salt_crust", "fertilizer_pellets", "dead_leaves", "gnats", "mulch"},
	"source":         {"window", "grow_light", "lamp", "mixed", "outdoor"},
	"windowDistance": {"sill", "under_1m", "1_2m", "over_2m", "none_visible"},
	"facing":         {"n", "ne", "e", "se", "s", "sw", "w", "nw"},
	"intensity":      {"low", "medium", "bright_indirect", "direct"},
	"room":           {"living", "bedroom", "bathroom", "kitchen", "office", "balcony", "outdoor"},
	"near":           {"heater", "radiator", "ac_vent", "fireplace", "tv", "draft_door", "curtain_sheer", "other_plants", "pet", "aquarium"},
	"humidity":       {"dry", "normal", "humid"},
}

func withUnknown(xs []string) []string { return append(append([]string{}, xs...), "unknown") }

func sceneSchema() map[string]any {
	e := func(k string) map[string]any {
		return map[string]any{"type": "string", "enum": withUnknown(sceneEnums[k])}
	}
	n := func(maxV int) map[string]any { return map[string]any{"type": "integer", "minimum": 0, "maximum": maxV} }
	list := func(k string, maxN int) map[string]any {
		return map[string]any{"type": "array", "maxItems": maxN, "uniqueItems": true, "items": map[string]any{"type": "string", "enum": sceneEnums[k]}}
	}
	props := map[string]any{
		"leaf_problems": map[string]any{"type": "string", "maxLength": 160},
		"issues": map[string]any{"type": "array", "maxItems": 3, "items": map[string]any{"type": "object",
			"properties": map[string]any{"kind": map[string]any{"type": "string", "enum": sceneEnums["issue"]}, "where": e("where")},
			"required":   []string{"kind", "where"}}},
		"fake_plant": e("yesno"), "several_plants": e("yesno"),
		"height_cm": n(400), "leaf_count": n(300), "stage": e("stage"),
		"pot": e("material"), "drainage_hole": e("yesno"), "pot_cm": n(120), "roots_out": e("yesno"), "cachepot": e("yesno"),
		"medium": e("medium"), "moisture": e("moisture"), "surface": list("surface", 4),
		"light": e("source"), "direct_sun": e("yesno"), "window": e("windowDistance"), "facing": e("facing"), "brightness": e("intensity"),
		"room": e("room"), "near": list("near", 3), "air": e("humidity"),
	}
	order := []string{"fake_plant", "medium", "pot", "drainage_hole", "cachepot", "moisture", "room", "light", "direct_sun", "window", "brightness", "facing", "several_plants", "stage", "height_cm", "leaf_count", "pot_cm", "roots_out", "leaf_problems", "issues", "surface", "near", "air"}
	return map[string]any{"type": "object", "properties": ordered{order, props}, "required": order}
}

// ordered marshals properties in the given order: llama.cpp's grammar writes keys in schema order, so the
// fields that change care most come first and a long answer can never crowd them out.
type ordered struct {
	keys []string
	m    map[string]any
}

func (o ordered) MarshalJSON() ([]byte, error) {
	var b bytes.Buffer
	b.WriteByte('{')
	for i, k := range o.keys {
		if i > 0 {
			b.WriteByte(',')
		}
		kb, _ := json.Marshal(k)
		vb, err := json.Marshal(o.m[k])
		if err != nil {
			return nil, err
		}
		b.Write(kb)
		b.WriteByte(':')
		b.Write(vb)
	}
	b.WriteByte('}')
	return b.Bytes(), nil
}

const scenePrompt = `Look at this plant photo and fill the JSON. leaf_problems: one short sentence on visible problems (yellow, brown tips, spots, crispy, mushy, holes, webbing, insects, white fuzz, wilting) or "healthy". issues: up to 3 visible problems and where. Numbers are estimates, 0 when you cannot tell. Use "unknown" whenever the photo does not show it; never guess the window direction unless the sun's position makes it obvious. drainage_hole only if the pot's base is visible. fake_plant: yes only for plastic or silk plants. cachepot: a decorative outer pot holding an inner pot. medium: "water" when the plant or cutting stands in water (glass, jar, vase, roots in water, no soil), "leca" for round clay balls, "pon" for small mineral granules, "sphagnum" for moss, "mounted" on bark or a board, "terrarium" inside a closed glass case, "ground" planted in a garden bed, "chunky" for bark-rich aroid mix, "cactus" for gritty mix, else "soil". near: only things visible in the photo.`

type vlmScene struct {
	LeafProblems string `json:"leaf_problems"`
	Issues       []struct{ Kind, Where string }
	Fake         string   `json:"fake_plant"`
	Several      string   `json:"several_plants"`
	HeightCm     float64  `json:"height_cm"`
	LeafCount    float64  `json:"leaf_count"`
	Stage        string   `json:"stage"`
	Pot          string   `json:"pot"`
	Drainage     string   `json:"drainage_hole"`
	PotCm        float64  `json:"pot_cm"`
	RootsOut     string   `json:"roots_out"`
	Cachepot     string   `json:"cachepot"`
	Medium       string   `json:"medium"`
	Moisture     string   `json:"moisture"`
	Surface      []string `json:"surface"`
	Light        string   `json:"light"`
	DirectSun    string   `json:"direct_sun"`
	Window       string   `json:"window"`
	Facing       string   `json:"facing"`
	Brightness   string   `json:"brightness"`
	Room         string   `json:"room"`
	Near         []string `json:"near"`
	Air          string   `json:"air"`
}

func askVLMScene(ctx context.Context, jpegB64 string) (vlmScene, bool) {
	var v vlmScene
	body, _ := json.Marshal(map[string]any{
		"max_tokens": 420, "temperature": 0,
		"response_format": map[string]any{"type": "json_schema", "json_schema": map[string]any{"schema": sceneSchema()}},
		"messages": []any{map[string]any{"role": "user", "content": []any{
			map[string]any{"type": "image_url", "image_url": map[string]string{"url": "data:image/jpeg;base64," + jpegB64}},
			map[string]any{"type": "text", "text": scenePrompt},
		}}},
	})
	cctx, cancel := context.WithTimeout(ctx, 75*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(cctx, "POST", "http://127.0.0.1:8091/v1/chat/completions", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return v, false
	}
	defer res.Body.Close()
	var out struct {
		Choices []struct{ Message struct{ Content string } }
	}
	if json.NewDecoder(res.Body).Decode(&out) != nil || len(out.Choices) == 0 {
		return v, false
	}
	return v, json.Unmarshal([]byte(out.Choices[0].Message.Content), &v) == nil
}

// idResult is what mtj-id returns for one photo: species candidates and zero-shot scene probabilities.
type idResult struct {
	Candidates []bioCand
	Scene      map[string]map[string]float64
}

// oneViewKey on a context: BioCLIP looks at the photo as framed only (multi-photo scans, where the other photos
// give the closer looks and the CPU budget is shared).
type oneViewKey struct{}

func askIDRaw(ctx context.Context, jpegB64 string) idResult {
	var out idResult
	in := map[string]any{"photo": jpegB64}
	if ctx.Value(oneViewKey{}) != nil {
		in["views"] = 1
	}
	body, _ := json.Marshal(in)
	cctx, cancel := context.WithTimeout(ctx, 25*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(cctx, "POST", "http://127.0.0.1:8092/", bytes.NewReader(body))
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return out
	}
	defer res.Body.Close()
	json.NewDecoder(res.Body).Decode(&out)
	return out
}

func known(s string) bool { return s != "" && s != "unknown" }

// blend merges the vision model's pick with BioCLIP's probabilities for one categorical field.
func blend(vlm string, clip map[string]float64) sv {
	best, p := "", 0.0
	for k, v := range clip {
		if v > p {
			best, p = k, v
		}
	}
	switch {
	case known(vlm) && vlm == best:
		return sv{vlm, round2(math.Min(0.95, math.Max(p, 0.6)+0.15))}
	case known(vlm) && best != "" && p >= 0.7:
		return sv{best, round2(p * 0.7)}
	case known(vlm):
		c := 0.5
		if q, ok := clip[vlm]; ok {
			c = math.Min(0.8, 0.45+q) // BioCLIP gave it some weight
		}
		return sv{vlm, round2(c)}
	case best != "" && p >= 0.45:
		return sv{best, round2(p * 0.8)}
	}
	return sv{"unknown", 0}
}

func vlmOnly(v string, conf float64) sv {
	if known(v) {
		return sv{v, conf}
	}
	return sv{"unknown", 0}
}

func vlmBool(v string, conf float64) sv {
	switch v {
	case "yes":
		return sv{true, conf}
	case "no":
		return sv{false, conf}
	}
	return sv{"unknown", 0}
}

func vlmNum(n, conf float64) sv {
	if n <= 0 {
		return sv{nil, 0}
	}
	return sv{n, conf}
}

// blendBool merges the vision model's yes/no with BioCLIP's probability of "yes".
func blendBool(vlm string, p float64) sv {
	switch {
	case vlm == "yes" && p >= 0.5:
		return sv{true, round2(math.Min(0.95, p+0.2))}
	case vlm == "yes":
		return sv{true, 0.5}
	case vlm == "no" && p < 0.5:
		return sv{false, round2(math.Min(0.95, 1-p+0.1))}
	case p >= 0.75:
		return sv{true, round2(p * 0.8)}
	case vlm == "no":
		return sv{false, 0.5}
	case p < 0.25: // BioCLIP alone sees a living plant clearly
		return sv{false, round2(math.Min(0.8, (1-p)*0.75))}
	}
	return sv{"unknown", 0}
}

func round2(f float64) float64 { return math.Round(f*100) / 100 }

func valid(k, v string) bool {
	for _, x := range sceneEnums[k] {
		if x == v {
			return true
		}
	}
	return false
}

// buildScene merges both models and the photo's own statistics.
func buildScene(v vlmScene, haveVLM bool, clip map[string]map[string]float64, img []byte) scene {
	var sc scene
	if !haveVLM {
		v = vlmScene{}
	}
	sc.saw = v.LeafProblems
	sc.Plant.HeightCm = vlmNum(v.HeightCm, 0.3)
	sc.Plant.LeafCount = vlmNum(v.LeafCount, 0.3)
	sc.Plant.Stage = blend(v.Stage, clip["stage"])
	sc.Plant.Artificial = blendBool(v.Fake, clip["artificial"]["yes"])
	sc.Plant.Multiple = vlmBool(v.Several, 0.45)
	sc.Plant.Issues = []sceneIssue{}
	for _, is := range v.Issues {
		if valid("issue", is.Kind) {
			w := is.Where
			if !valid("where", w) {
				w = "unknown"
			}
			sc.Plant.Issues = append(sc.Plant.Issues, sceneIssue{is.Kind, 0.55, w})
		}
	}
	sc.Pot.Material = blend(v.Pot, clip["material"])
	sc.Pot.Drainage = vlmOnly(v.Drainage, 0.45)
	if m := sc.Pot.Material.Value; m == "glass" || m == "basket_cachepot" {
		if sc.Pot.Drainage.Value == "unknown" {
			sc.Pot.Drainage = sv{"no", 0.4} // glass and baskets rarely drain
		}
	}
	if m := sc.Pot.Material.Value; m == "nursery" || m == "terracotta" {
		if sc.Pot.Drainage.Value == "unknown" {
			sc.Pot.Drainage = sv{"yes", 0.5}
		}
	}
	sc.Pot.DiameterCm = vlmNum(v.PotCm, 0.3)
	sc.Pot.Rootbound = vlmBool(v.RootsOut, 0.45)
	sc.Pot.Cachepot = vlmBool(v.Cachepot, 0.45)
	if sc.Pot.Material.Value == "basket_cachepot" && sc.Pot.Cachepot.Value == "unknown" {
		sc.Pot.Cachepot = sv{true, sc.Pot.Material.Conf}
	}
	sc.Soil.Medium = blend(v.Medium, clip["medium"])
	sc.Soil.Moisture = vlmOnly(v.Moisture, 0.45)
	sc.Soil.Surface = []sceneItem{}
	for _, s := range v.Surface {
		if valid("surface", s) {
			sc.Soil.Surface = append(sc.Soil.Surface, sceneItem{s, 0.5})
		}
	}
	sc.Light.Source = blend(v.Light, clip["source"])
	sc.Light.DirectSun = vlmBool(v.DirectSun, 0.45)
	sc.Light.WindowDistance = vlmOnly(v.Window, 0.4)
	sc.Light.WindowFacing = vlmOnly(v.Facing, 0.2)
	sc.Light.Intensity = blend(v.Brightness, clip["intensity"])
	if pct, ok := map[any]float64{"window": 85, "outdoor": 100, "grow_light": 0, "lamp": 10, "mixed": 50}[sc.Light.Source.Value]; ok {
		sc.Light.NaturalPct = sv{pct, round2(sc.Light.Source.Conf * 0.6)}
	} else {
		sc.Light.NaturalPct = sv{nil, 0}
	}
	sc.Light.Lux, sc.Light.Kelvin = photoLight(img, sc.Light.Intensity)
	sc.Surroundings.Room = blend(v.Room, clip["room"])
	sc.Surroundings.Near = []sceneItem{}
	for _, s := range v.Near {
		if valid("near", s) {
			sc.Surroundings.Near = append(sc.Surroundings.Near, sceneItem{s, 0.5})
		}
	}
	sc.Surroundings.HumidityHint = vlmOnly(v.Air, 0.35)
	if sc.Surroundings.HumidityHint.Value == "unknown" {
		for _, n := range sc.Surroundings.Near {
			if n.Item == "heater" || n.Item == "radiator" || n.Item == "fireplace" || n.Item == "ac_vent" {
				sc.Surroundings.HumidityHint = sv{"dry", 0.4}
			}
		}
		if sc.Surroundings.Room.Value == "bathroom" {
			sc.Surroundings.HumidityHint = sv{"humid", 0.4}
		}
	}
	return sc
}

// photoLight estimates illuminance (from EXIF exposure when present, else from the light class) and colour
// temperature (McCamy from the photo's mean chromaticity; phone white balance flattens it, hence low conf).
func photoLight(img []byte, intensity sv) (lux, kelvin sv) {
	lux, kelvin = sv{nil, 0}, sv{nil, 0}
	if t, n, iso, ok := exifExposure(img); ok && t > 0 && n > 0 {
		if iso <= 0 {
			iso = 100
		}
		ev100 := math.Log2(n*n/t) - math.Log2(iso/100)
		lux = sv{math.Round(2.5 * math.Pow(2, ev100)), 0.35}
	} else if v, ok := map[any]float64{"low": 150, "medium": 600, "bright_indirect": 2000, "direct": 20000}[intensity.Value]; ok {
		lux = sv{v, round2(0.25 * intensity.Conf)}
	}
	m, _, err := image.Decode(bytes.NewReader(img))
	if err != nil {
		return
	}
	b := m.Bounds()
	step := max(1, max(b.Dx(), b.Dy())/96)
	var r, g, bl, cnt float64
	lin := func(c uint32) float64 {
		x := float64(c) / 65535
		if x <= 0.04045 {
			return x / 12.92
		}
		return math.Pow((x+0.055)/1.055, 2.4)
	}
	for y := b.Min.Y; y < b.Max.Y; y += step {
		for x := b.Min.X; x < b.Max.X; x += step {
			cr, cg, cb, _ := m.At(x, y).RGBA()
			r, g, bl, cnt = r+lin(cr), g+lin(cg), bl+lin(cb), cnt+1
		}
	}
	if cnt == 0 {
		return
	}
	r, g, bl = r/cnt, g/cnt, bl/cnt
	X := 0.4124*r + 0.3576*g + 0.1805*bl
	Y := 0.2126*r + 0.7152*g + 0.0722*bl
	Z := 0.0193*r + 0.1192*g + 0.9505*bl
	if s := X + Y + Z; s > 0 {
		x, y := X/s, Y/s
		nn := (x - 0.3320) / (0.1858 - y)
		cct := 449*nn*nn*nn + 3525*nn*nn + 6823.3*nn + 5520.33
		if cct > 1500 && cct < 12000 {
			kelvin = sv{math.Round(cct/50) * 50, 0.15}
		}
	}
	return
}

// exifExposure reads ExposureTime, FNumber and ISO from a JPEG's EXIF block, if any.
func exifExposure(img []byte) (t, n, iso float64, ok bool) {
	i := 2
	for i+4 < len(img) && img[i] == 0xFF {
		mk, l := img[i+1], int(binary.BigEndian.Uint16(img[i+2:]))
		if mk == 0xE1 && i+4+l <= len(img) && l > 14 && string(img[i+4:i+10]) == "Exif\x00\x00" {
			return parseTIFF(img[i+10 : i+4+l])
		}
		if mk == 0xDA {
			break
		}
		i += 2 + l
	}
	return
}

func parseTIFF(d []byte) (t, n, iso float64, ok bool) {
	if len(d) < 8 {
		return
	}
	var bo binary.ByteOrder = binary.BigEndian
	if string(d[:2]) == "II" {
		bo = binary.LittleEndian
	}
	rat := func(off uint32) float64 {
		if int(off)+8 > len(d) {
			return 0
		}
		den := bo.Uint32(d[off+4:])
		if den == 0 {
			return 0
		}
		return float64(bo.Uint32(d[off:])) / float64(den)
	}
	var walk func(off uint32, depth int)
	walk = func(off uint32, depth int) {
		if depth > 2 || int(off)+2 > len(d) {
			return
		}
		cnt := int(bo.Uint16(d[off:]))
		for k := 0; k < cnt; k++ {
			e := int(off) + 2 + 12*k
			if e+12 > len(d) {
				return
			}
			tag, val := bo.Uint16(d[e:]), bo.Uint32(d[e+8:])
			switch tag {
			case 0x8769:
				walk(val, depth+1)
			case 0x829A:
				t = rat(val)
			case 0x829D:
				n = rat(val)
			case 0x8827:
				iso = float64(bo.Uint16(d[e+8:]))
			}
		}
	}
	walk(bo.Uint32(d[4:]), 0)
	return t, n, iso, t > 0 && n > 0
}

// situation turns what the photo shows (confident fields only) into the knowledge base's situation keys,
// without overriding anything the owner told us.
func (sc scene) situation(into situation) situation {
	if into == nil {
		into = situation{}
	}
	got := situation{}
	add := func(k, v string) {
		for _, x := range got[k] {
			if x == v {
				return
			}
		}
		got[k] = append(got[k], v)
	}
	str := func(f sv, min float64) string {
		if s, ok := f.Value.(string); ok && f.Conf >= min && known(s) {
			return s
		}
		return ""
	}
	if a, ok := sc.Plant.Artificial.Value.(bool); ok && a && sc.Plant.Artificial.Conf >= 0.6 {
		add("plant", "artificial")
	}
	if m, ok := sc.Plant.Multiple.Value.(bool); ok && m && sc.Plant.Multiple.Conf >= 0.45 {
		add("plant", "multiple")
	}
	switch str(sc.Surroundings.Room, 0.5) {
	case "bathroom", "kitchen", "office", "balcony", "outdoor":
		add("room", str(sc.Surroundings.Room, 0.5))
	}
	for _, n := range sc.Surroundings.Near {
		if n.Conf < 0.45 {
			continue
		}
		add("near", n.Item)
		switch n.Item {
		case "heater", "radiator", "fireplace":
			add("room", "heater")
			add("humidity", "low")
		case "ac_vent":
			add("room", "aircon")
		case "draft_door":
			add("room", "draft")
		}
	}
	switch str(sc.Surroundings.HumidityHint, 0.4) {
	case "dry":
		add("humidity", "low")
	case "humid":
		add("humidity", "high")
	}
	if str(sc.Light.Source, 0.5) == "grow_light" {
		add("room", "grow-light")
		add("light", "grow-light")
	}
	switch str(sc.Light.Intensity, 0.5) {
	case "low":
		add("light", "low")
	case "direct":
		add("light", "high")
	}
	switch str(sc.Light.WindowFacing, 0.5) {
	case "n":
		add("room", "window-north")
	case "s":
		add("room", "window-south")
	}
	if str(sc.Pot.Drainage, 0.4) == "no" {
		add("pot", "no-drainage")
	}
	switch str(sc.Pot.Material, 0.5) {
	case "terracotta":
		add("pot", "terracotta")
	case "plastic", "nursery":
		add("pot", "plastic")
	case "self_watering":
		add("pot", "self-watering")
	case "glass":
		add("pot", "glass")
	}
	if c, ok := sc.Pot.Cachepot.Value.(bool); ok && c && sc.Pot.Cachepot.Conf >= 0.4 {
		add("pot", "cachepot")
	}
	if r, ok := sc.Pot.Rootbound.Value.(bool); ok && r && sc.Pot.Rootbound.Conf >= 0.4 {
		add("pot", "too-small")
	}
	if m := str(sc.Soil.Medium, 0.45); m != "" {
		add("medium", m)
		switch m {
		case "leca":
			add("soil", "leca-setup")
		case "cactus":
			add("soil", "cactus")
		case "chunky":
			add("soil", "aroid")
		case "sphagnum":
			add("soil", "sphagnum-mix")
		case "terrarium":
			add("soil", "terrarium-mix")
		case "ground":
			add("room", "outdoor")
		}
	}
	if m := str(sc.Soil.Moisture, 0.4); m != "" {
		add("moisture", m)
	}
	for _, s := range sc.Soil.Surface {
		if s.Conf >= 0.45 {
			add("surface", s.Item)
		}
	}
	for k, v := range got {
		if _, set := into[k]; !set {
			into[k] = v
		}
	}
	return into
}

// evidence adds the issues the photo shows to the vision model's words, for knowledge matching.
func (sc scene) evidence() string {
	words := map[string]string{"yellowing": "yellow leaves", "brown_tips": "brown tips", "brown_spots": "brown spots", "black_spots": "black spots", "pale": "pale leaves", "wilting": "wilting", "drooping": "drooping", "curling": "curling leaves", "crispy": "crispy edges", "mushy": "mushy soft", "holes": "holes in leaves", "webbing": "fine webbing", "insects": "insects bugs", "white_powder": "white powder", "white_fluff": "white cottony fluff", "sticky": "sticky honeydew", "mold": "mould on soil", "leggy": "leggy stretched", "sunburn": "scorched bleached patches", "variegation_loss": "variegation loss", "rot": "rot mushy stem"}
	out := []string{sc.saw}
	for _, is := range sc.Plant.Issues {
		out = append(out, words[is.Kind])
	}
	return strings.Join(out, ". ")
}

// POST /v1/brain/scene {photo, lang}: the whole scene of a plant photo (plant, pot, soil, light, surroundings).
func (s *Server) brainScene(w http.ResponseWriter, r *http.Request) {
	var in struct{ Photo, Lang string }
	if decode(r, &in) != nil || len(in.Photo) == 0 || len(in.Photo) > 1_800_000 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	photo, err := normPhoto(in.Photo)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	ctx, cancel := context.WithTimeout(context.WithoutCancel(r.Context()), 85*time.Second)
	defer cancel()
	sc, _ := readScene(ctx, photo)
	writeJSON(w, http.StatusOK, map[string]any{"scene": sc})
}

// extras are the structured situation fields the apps may send next to (or instead of) situation keys.
type extras struct {
	Medium    string `json:"medium"`    // soil|chunky|cactus|leca|pon|sphagnum|water|mounted|terrarium|ground
	LifeStage string `json:"lifeStage"` // cutting|seedling|acclimating|repotted|dormant|flowering|recovering|unknown_history
	Outdoor   *bool  `json:"outdoor"`
	// Weather the app already has (or a test fixture); otherwise the server reads it from lat/lon.
	Weather  *weatherFacts `json:"weather"`
	PotSetup *struct {
		SelfWatering *bool  `json:"selfWatering"`
		Cachepot     *bool  `json:"cachepot"`
		Drainage     *bool  `json:"drainage"`
		Material     string `json:"material"`
		SizeFit      string `json:"sizeFit"` // too_small|ok|too_big
	} `json:"potSetup"`
}

func (x extras) into(sit situation) situation {
	if sit == nil {
		sit = situation{}
	}
	add := func(k, v string) {
		if v == "" || len(v) > 24 {
			return
		}
		for _, e := range sit[k] {
			if e == v {
				return
			}
		}
		sit[k] = append(sit[k], v)
	}
	if x.Medium != "" {
		sit["medium"] = []string{x.Medium}
	}
	add("lifeStage", x.LifeStage)
	if x.Outdoor != nil && *x.Outdoor {
		add("room", "outdoor")
	}
	if p := x.PotSetup; p != nil {
		if p.SelfWatering != nil && *p.SelfWatering {
			add("pot", "self-watering")
		}
		if p.Cachepot != nil && *p.Cachepot {
			add("pot", "cachepot")
		}
		if p.Drainage != nil && !*p.Drainage {
			add("pot", "no-drainage")
		}
		switch p.Material {
		case "terracotta", "glass", "hanging":
			add("pot", p.Material)
		case "plastic", "nursery":
			add("pot", "plastic")
		case "self_watering":
			add("pot", "self-watering")
		case "basket_cachepot":
			add("pot", "cachepot")
		}
		switch p.SizeFit {
		case "too_small":
			add("pot", "too-small")
		case "too_big":
			add("pot", "too-big")
		}
	}
	return sit
}

// bioclip: species candidates only (batch identify crops).
func bioclip(ctx context.Context, jpegB64 string) []bioCand { return askID(ctx, jpegB64).Candidates }

// askIDBatch: several crops in one BioCLIP call (one batched forward pass).
func askIDBatch(ctx context.Context, jpegs []string) []idResult {
	out := make([]idResult, len(jpegs))
	if len(jpegs) == 0 {
		return out
	}
	body, _ := json.Marshal(map[string]any{"photos": jpegs})
	cctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(cctx, "POST", "http://127.0.0.1:8092/", bytes.NewReader(body))
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return out
	}
	defer res.Body.Close()
	var r struct{ Results []idResult }
	if json.NewDecoder(res.Body).Decode(&r) == nil && len(r.Results) == len(jpegs) {
		return r.Results
	}
	return out
}

// seeWith: a free-form prompt to the local vision model (batch identify boxes).
func seeWith(ctx context.Context, jpegB64, prompt string, maxTokens int) string {
	body, _ := json.Marshal(map[string]any{
		"max_tokens": maxTokens, "temperature": 0.1,
		"messages": []any{map[string]any{"role": "user", "content": []any{
			map[string]any{"type": "image_url", "image_url": map[string]string{"url": "data:image/jpeg;base64," + jpegB64}},
			map[string]any{"type": "text", "text": prompt},
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
