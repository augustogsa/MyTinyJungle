package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/anthropics/anthropic-sdk-go/v2"
	"github.com/anthropics/anthropic-sdk-go/v2/option"
	"github.com/jackc/pgx/v5"
)

// AI plant diagnosis for Plus: one photo plus context in, a short structured diagnosis out.
// Enabled when MTJ_AI_KEY is set (MyTinyJungle's own Anthropic key). Photos are never stored.

const (
	diagnoseModel  = "claude-opus-5-5"
	diagnosePerDay = 20
)

const diagnoseSystem = `You are a houseplant doctor inside the My Tiny Jungle app. Look at the photo and the owner's note.
Answer ONLY with a JSON object: {"problem": short name, "confidence": "low"|"medium"|"high", "why": one or two sentences on what you see,
"steps": [up to 4 short, concrete care steps], "urgent": true|false}. Write every text value in the language given by "lang".
If the photo shows no plant or is too unclear, set problem to a short note asking for a clearer photo of the affected leaves.`

type diagnosis struct {
	Problem    string   `json:"problem"`
	Confidence string   `json:"confidence"`
	Why        string   `json:"why"`
	Steps      []string `json:"steps"`
	Urgent     bool     `json:"urgent"`
	Source     string   `json:"source,omitempty"` // library | internal | free | claude
	Context    string   `json:"context,omitempty"`
	Ref        string   `json:"ref,omitempty"` // send back with /v1/diagnose/feedback // what the plant's situation has to do with it
	// Our knowledge ids behind the answer, best first (up to 3), and the runners-up by name.
	IDs          []string   `json:"ids,omitempty"`
	Alternatives []string   `json:"alternatives,omitempty"`
	Used         []string   `json:"used,omitempty"` // photo kinds that went into the answer
	Tips         []photoTip `json:"tips,omitempty"` // the next most useful photos when unsure
	Scene        *scene     `json:"scene,omitempty"`
	Weather      []string   `json:"weather,omitempty"` // reasons from the local weather, in the owner's language
}

func (s *Server) aiClient() *anthropic.Client {
	key := os.Getenv("MTJ_AI_KEY")
	if key == "" {
		return nil
	}
	c := anthropic.NewClient(option.WithAPIKey(key), option.WithRequestTimeout(90*time.Second))
	return &c
}

func (s *Server) diagnose(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Photo   string `json:"photo"`  // base64 JPEG/WebP ≤ 768 px
		Photos  []shot `json:"photos"` // or a multi-photo scan: 1-8 {photo, kind}
		Species string `json:"species"`
		Note    string `json:"note"`
		Lang    string `json:"lang"`
		// Optional situation: room, humidity, temp, light, watered, soil, pot, event, season, weather
		// (values as in the knowledge base's scenarios). Lat/lon are rounded to ~10 km here and only used
		// to read the local weather; they are never stored.
		Situation map[string][]string `json:"situation"`
		Lat       *float64            `json:"lat"`
		Lon       *float64            `json:"lon"`
		extras
	}
	if decode(r, &in) != nil || len(in.Photo) > 1_800_000 || len(in.Species) > 120 || len(in.Note) > 600 || len(in.Lang) > 12 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ss, err := shots(in.Photo, in.Photos)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	// The vision model reads the leaf (underside first: pests) and the soil (moisture, mould, gnats).
	lead := pick(ss, "underside", "leaf", "whole", "stem", "flower", "other")
	full := []int{lead}
	if i := pick(ss, "soil"); ss[i].Kind == "soil" && i != lead {
		full = append(full, i)
	}
	in.Photo = ss[lead].Photo
	photoIDs := ""
	for _, x := range ss {
		photoIDs += fmt.Sprintf("%s:%x,", x.Kind, photoKey(x.Photo))
	}
	ctx, c := r.Context(), claimsOf(r)
	// Plus only, and a daily cap; the use is counted before the call so retries can't exceed it.
	err = s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		es, err := activeEntitlements(r, tx)
		if err != nil {
			return err
		}
		if len(es) == 0 {
			return apiError{http.StatusPaymentRequired, "plus_required"}
		}
		var n int
		if err := tx.QueryRow(ctx, `insert into ai_usage (user_id) values ($1) on conflict (user_id, day) do update set n = ai_usage.n + 1 returning n`, c.Sub).Scan(&n); err != nil {
			return err
		}
		if n > diagnosePerDay {
			return apiError{http.StatusTooManyRequests, "daily_limit"}
		}
		return nil
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	sit := situation{}
	for k, v := range in.Situation {
		if len(k) <= 12 && len(v) <= 12 {
			sit[k] = v
		}
	}
	sit = in.extras.into(sit)
	wf := resolveWeather(ctx, in.extras.Weather, in.Lat, in.Lon)
	sit = mergeSit(sit, wf.situation())
	tctx, tcancel := context.WithTimeout(context.WithoutCancel(ctx), 90*time.Second)
	defer tcancel()
	// Same photo, note, species, language and situation: the same answer (weather notes are added after).
	key := answerKey("dx", photoIDs, in.Species, strings.TrimSpace(strings.ToLower(in.Note)), in.Lang, sit.bucket())
	var d diagnosis
	if v, ok := answers.get(key); ok {
		d = v.(diagnosis)
		perfCache("diagnose", true)
	} else {
		perfCache("diagnose", false)
		var given *scene
		if len(ss) > 1 {
			fs := fuseScene(tctx, ss, full...)
			given = &fs
		}
		d, err = s.think(tctx, in.Photo, given, in.Species, in.Note, in.Lang, sit)
		if err != nil {
			s.fail(w, r, err)
			return
		}
		answers.put(key, d)
	}
	if len(d.Steps) > 4 {
		d.Steps = d.Steps[:4]
	}
	lang := in.Lang
	if lang == "" || strings.HasPrefix(lang, "en") {
		lang = "en"
	}
	d.Used = kindsOf(ss)
	d.Tips = photoTips(lang, confNum(d.Confidence), d.Used, "underside", "leaf", "soil", "stem", "whole", "roots")
	d.Weather = wf.notes(lang, isOutdoor(sit), theBrainWith(s).findSpecies(in.Species))
	writeJSON(w, http.StatusOK, d)
}

// askClaude is the last resort: Claude sees the photo plus our best knowledge-base candidates.
func (s *Server) askClaude(ctx context.Context, photo, note string) (diagnosis, error) {
	client := s.aiClient()
	if client == nil {
		return diagnosis{}, apiError{http.StatusServiceUnavailable, "ai_unavailable"}
	}
	cctx, cancel := context.WithCancel(ctx)
	defer cancel()
	resp, err := client.Messages.New(cctx, anthropic.MessageNewParams{
		Model:     diagnoseModel,
		MaxTokens: 2000,
		System:    []anthropic.TextBlockParam{{Text: diagnoseSystem}},
		Messages: []anthropic.MessageParam{anthropic.NewUserMessage(
			anthropic.NewImageBlockBase64("image/jpeg", photo),
			anthropic.NewTextBlock(note),
		)},
	})
	if err != nil {
		s.log.Error("diagnose", "err", err)
		return diagnosis{}, apiError{http.StatusBadGateway, "ai_failed"}
	}
	if resp.StopReason == anthropic.StopReasonRefusal {
		return diagnosis{}, apiError{http.StatusUnprocessableEntity, "ai_declined"}
	}
	var text strings.Builder
	for _, b := range resp.Content {
		if t, ok := b.AsAny().(anthropic.TextBlock); ok {
			text.WriteString(t.Text)
		}
	}
	d, ok := parseDiagnosis(text.String())
	if !ok {
		return diagnosis{}, apiError{http.StatusBadGateway, "ai_failed"}
	}
	d.Source = "claude"
	return d, nil
}

func parseDiagnosis(raw string) (diagnosis, bool) {
	if i, j := strings.Index(raw, "{"), strings.LastIndex(raw, "}"); i >= 0 && j > i {
		raw = raw[i : j+1]
	}
	var d diagnosis
	if json.Unmarshal([]byte(raw), &d) != nil || d.Problem == "" {
		return d, false
	}
	return d, true
}

// claudeText sends a photo and prompt to Claude; false when no key or no answer.
func (s *Server) claudeText(ctx context.Context, photo, prompt string) (string, bool) {
	client := s.aiClient()
	if client == nil {
		return "", false
	}
	resp, err := client.Messages.New(ctx, anthropic.MessageNewParams{
		Model:     diagnoseModel,
		MaxTokens: 1000,
		Messages: []anthropic.MessageParam{anthropic.NewUserMessage(
			anthropic.NewImageBlockBase64("image/jpeg", photo),
			anthropic.NewTextBlock(prompt),
		)},
	})
	if err != nil {
		return "", false
	}
	var text strings.Builder
	for _, b := range resp.Content {
		if t, ok := b.AsAny().(anthropic.TextBlock); ok {
			text.WriteString(t.Text)
		}
	}
	return text.String(), text.Len() > 0
}
