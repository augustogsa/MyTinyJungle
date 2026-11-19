package api

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/color"
	"image/jpeg"
	_ "image/png"
	"math"
	"net/http"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

// POST /v1/brain/identify-batch {photo, lang}: one photo of a shelf or windowsill. Our vision model
// (127.0.0.1:8091) marks each plant; when it can't, the photo is split into a grid and empty cells are
// dropped. Each crop is named by BioCLIP over our species list. Internal models only, never paid.
// Every crop identified counts against the identify daily quota; when the quota runs out, the rest
// are skipped and truncated is true.

const maxBatchCrops = 8

type batchBox struct {
	X float64 `json:"x"` // left, fraction of width
	Y float64 `json:"y"` // top, fraction of height
	W float64 `json:"w"`
	H float64 `json:"h"`
}

type idCand struct {
	ID         string  `json:"id"`
	Scientific string  `json:"scientific"`
	Name       string  `json:"name"`
	Score      float64 `json:"score"`
}

type batchItem struct {
	Box        batchBox `json:"box"`
	Candidates []idCand `json:"candidates"`
	Confident  bool     `json:"confident"`
}

func (s *Server) brainIdentifyBatch(w http.ResponseWriter, r *http.Request) {
	var in struct{ Photo, Lang string }
	if decode(r, &in) != nil || len(in.Photo) == 0 || len(in.Photo) > 1_800_000 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	raw, err := base64.StdEncoding.DecodeString(in.Photo)
	if err != nil {
		s.fail(w, r, bad("invalid_photo"))
		return
	}
	img, _, err := image.Decode(bytes.NewReader(raw))
	if err != nil || img.Bounds().Dx() < 64 || img.Bounds().Dy() < 64 {
		s.fail(w, r, bad("invalid_photo"))
		return
	}
	if theBrain.dir == "" {
		theBrain.dir = s.cfg.ContentDir
	}
	theBrain.species()
	ctx, cancel := context.WithTimeout(context.WithoutCancel(r.Context()), 85*time.Second)
	defer cancel()
	c := claimsOf(r)

	detector := "model"
	boxes := detectPlants(ctx, img)
	if len(boxes) == 0 {
		detector, boxes = "grid", gridBoxes(img.Bounds().Dx(), img.Bounds().Dy())
	}
	// The request itself paid for one identify (guard); each further crop costs one more.
	allowed := 1 + s.chargeQuota(ctx, c, "identify", len(boxes)-1)
	items := []batchItem{}
	truncated := false
	used := 0
	var crops []string
	var cropBoxes []batchBox
	for _, b := range boxes {
		if len(crops) >= allowed {
			truncated = true
			break
		}
		if crop := cropJPEG(img, b); crop != "" {
			crops, cropBoxes = append(crops, crop), append(cropBoxes, b)
		}
	}
	used = len(crops)
	for i, res := range askIDBatch(ctx, crops) { // one batched forward pass for all crops
		b := cropBoxes[i]
		var cands []idCand
		for _, bc := range res.Candidates {
			if bc.Score < 0.05 {
				continue
			}
			if cd, ok := speciesCand(bc.ID, bc.Score, in.Lang); ok {
				cands = append(cands, cd)
			}
			if len(cands) == 3 {
				break
			}
		}
		// Grid cells with no clear plant are empty shelf.
		if detector == "grid" && (len(cands) == 0 || cands[0].Score < 0.15) {
			continue
		}
		if cands == nil {
			cands = []idCand{}
		}
		items = append(items, batchItem{Box: b, Candidates: cands, Confident: len(cands) > 0 && cands[0].Score >= 0.5})
	}
	if len(items) == 0 {
		s.gap(ctx, "identify", "unknown plant")
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items, "detector": detector, "charged": used, "truncated": truncated})
}

func speciesCand(id string, score float64, lang string) (idCand, bool) {
	speciesDB.RLock()
	sp := speciesDB.byID[id]
	speciesDB.RUnlock()
	if sp == nil {
		return idCand{}, false
	}
	name := sp.En
	if strings.HasPrefix(lang, "pt") && sp.Pt != "" {
		name = sp.Pt
	}
	return idCand{sp.ID, sp.Scientific, name, math.Round(score*100) / 100}, true
}

// chargeQuota adds up to n calls of kind for the user and device and returns how many fit under the daily limit.
func (s *Server) chargeQuota(ctx context.Context, c Claims, kind string, n int) int {
	if n <= 0 {
		return 0
	}
	if s.db == nil || s.db.Auth == nil {
		return n
	}
	limit := 0
	for _, q := range dailyQuota {
		if q.kind == kind {
			limit = q.n
		}
	}
	subjects := []string{"u:" + c.Sub}
	if c.Dev != "" {
		subjects = append(subjects, "d:"+c.Dev)
	}
	var used int
	_ = s.db.Auth.QueryRow(ctx, `select coalesce(max(n), 0) from api_quota where day = current_date and kind = $1 and subject = any($2)`, kind, subjects).Scan(&used)
	take := min(n, max(0, limit-used))
	if take == 0 {
		return 0
	}
	for _, sub := range subjects {
		_, _ = s.db.Auth.Exec(ctx, `insert into api_quota (subject, kind, n) values ($1, $2, $3)
			on conflict (day, subject, kind) do update set n = api_quota.n + $3`, sub, kind, take)
	}
	return take
}

var numRe = regexp.MustCompile(`-?\d+(?:\.\d+)?`)

// detectPlants asks the local vision model for one box per plant. The photo is sent at ≤ 756 px so pixel
// answers can be mapped back; fractions and 0–1000 answers are accepted too.
func detectPlants(ctx context.Context, img image.Image) []batchBox {
	small := downscale(img, 756)
	var buf bytes.Buffer
	if jpeg.Encode(&buf, small, &jpeg.Options{Quality: 85}) != nil {
		return nil
	}
	sw, sh := float64(small.Bounds().Dx()), float64(small.Bounds().Dy())
	ans := seeWith(ctx, base64.StdEncoding.EncodeToString(buf.Bytes()),
		"Detect every separate potted plant in this photo. Output only JSON: [{\"bbox_2d\":[x1,y1,x2,y2],\"label\":\"plant\"}], one entry per plant, coordinates in pixels of this image.", 400)
	return parseBoxes(ans, sw, sh)
}

func parseBoxes(ans string, sw, sh float64) []batchBox {
	var quads [][4]float64
	var js []struct {
		Box []float64 `json:"bbox_2d"`
	}
	if i, j := strings.Index(ans, "["), strings.LastIndex(ans, "]"); i >= 0 && j > i && json.Unmarshal([]byte(ans[i:j+1]), &js) == nil {
		for _, b := range js {
			if len(b.Box) == 4 {
				quads = append(quads, [4]float64{b.Box[0], b.Box[1], b.Box[2], b.Box[3]})
			}
		}
	}
	if len(quads) == 0 { // loose answer: groups of four numbers
		var ns []float64
		for _, m := range numRe.FindAllString(ans, 64) {
			f, _ := strconv.ParseFloat(m, 64)
			ns = append(ns, f)
		}
		for i := 0; i+3 < len(ns); i += 4 {
			quads = append(quads, [4]float64{ns[i], ns[i+1], ns[i+2], ns[i+3]})
		}
	}
	peak := 0.0
	for _, q := range quads {
		for _, v := range q {
			peak = math.Max(peak, v)
		}
	}
	sx, sy := 1.0, 1.0
	switch {
	case peak <= 1:
	case peak <= math.Max(sw, sh)+2:
		sx, sy = sw, sh
	default:
		sx, sy = 1000, 1000
	}
	var out []batchBox
	for _, q := range quads {
		x0, y0, x1, y1 := q[0]/sx, q[1]/sy, q[2]/sx, q[3]/sy
		if x1 < x0 {
			x0, x1 = x1, x0
		}
		if y1 < y0 {
			y0, y1 = y1, y0
		}
		x0, y0, x1, y1 = clamp01(x0-0.03), clamp01(y0-0.03), clamp01(x1+0.03), clamp01(y1+0.03)
		b := batchBox{x0, y0, x1 - x0, y1 - y0}
		if a := b.W * b.H; a < 0.015 || a > 0.95 {
			continue
		}
		dup := false
		for _, o := range out {
			if iou(o, b) > 0.5 {
				dup = true
				break
			}
		}
		if !dup {
			out = append(out, b)
		}
	}
	sort.SliceStable(out, func(i, j int) bool { // reading order: rows top to bottom, then left to right
		if math.Abs(out[i].Y-out[j].Y) > 0.15 {
			return out[i].Y < out[j].Y
		}
		return out[i].X < out[j].X
	})
	if len(out) > maxBatchCrops {
		out = out[:maxBatchCrops]
	}
	return out
}

func clamp01(v float64) float64 { return math.Max(0, math.Min(1, v)) }

func iou(a, b batchBox) float64 {
	ix := math.Max(0, math.Min(a.X+a.W, b.X+b.W)-math.Max(a.X, b.X))
	iy := math.Max(0, math.Min(a.Y+a.H, b.Y+b.H)-math.Max(a.Y, b.Y))
	in := ix * iy
	u := a.W*a.H + b.W*b.H - in
	if u <= 0 {
		return 0
	}
	return in / u
}

// gridBoxes splits the photo by its shape: 3×2 landscape, 2×3 portrait, 2×2 square-ish.
func gridBoxes(w, h int) []batchBox {
	cols, rows := 2, 2
	switch {
	case float64(w) >= float64(h)*1.3:
		cols, rows = 3, 2
	case float64(h) >= float64(w)*1.3:
		cols, rows = 2, 3
	}
	var out []batchBox
	for r := 0; r < rows; r++ {
		for c := 0; c < cols; c++ {
			out = append(out, batchBox{float64(c) / float64(cols), float64(r) / float64(rows), 1 / float64(cols), 1 / float64(rows)})
		}
	}
	return out
}

func cropJPEG(img image.Image, b batchBox) string {
	bd := img.Bounds()
	rect := image.Rect(bd.Min.X+int(b.X*float64(bd.Dx())), bd.Min.Y+int(b.Y*float64(bd.Dy())),
		bd.Min.X+int((b.X+b.W)*float64(bd.Dx())), bd.Min.Y+int((b.Y+b.H)*float64(bd.Dy()))).Intersect(bd)
	if rect.Dx() < 32 || rect.Dy() < 32 {
		return ""
	}
	sub := image.NewRGBA(image.Rect(0, 0, rect.Dx(), rect.Dy()))
	for y := 0; y < rect.Dy(); y++ {
		for x := 0; x < rect.Dx(); x++ {
			sub.Set(x, y, img.At(rect.Min.X+x, rect.Min.Y+y))
		}
	}
	var buf bytes.Buffer
	if jpeg.Encode(&buf, downscale(sub, 640), &jpeg.Options{Quality: 88}) != nil {
		return ""
	}
	return base64.StdEncoding.EncodeToString(buf.Bytes())
}

// downscale shrinks so the longer side is at most maxSide (box filter); smaller images are returned as is.
func downscale(img image.Image, maxSide int) image.Image {
	bd := img.Bounds()
	w, h := bd.Dx(), bd.Dy()
	if w <= maxSide && h <= maxSide {
		return img
	}
	f := float64(max(w, h)) / float64(maxSide)
	nw, nh := max(1, int(float64(w)/f)), max(1, int(float64(h)/f))
	out := image.NewRGBA(image.Rect(0, 0, nw, nh))
	for y := 0; y < nh; y++ {
		y0, y1 := int(float64(y)*f), max(int(float64(y)*f)+1, int(float64(y+1)*f))
		for x := 0; x < nw; x++ {
			x0, x1 := int(float64(x)*f), max(int(float64(x)*f)+1, int(float64(x+1)*f))
			var r, g, b, n uint32
			for yy := y0; yy < y1 && yy < h; yy += max(1, (y1-y0)/3) {
				for xx := x0; xx < x1 && xx < w; xx += max(1, (x1-x0)/3) {
					cr, cg, cb, _ := img.At(bd.Min.X+xx, bd.Min.Y+yy).RGBA()
					r, g, b, n = r+cr, g+cg, b+cb, n+1
				}
			}
			if n > 0 {
				out.Set(x, y, color.RGBA{uint8(r / n >> 8), uint8(g / n >> 8), uint8(b / n >> 8), 255})
			}
		}
	}
	return out
}
