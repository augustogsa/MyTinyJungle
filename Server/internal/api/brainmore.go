package api

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// POST /v1/diagnose/feedback {ref, helped}: owners teach the library. An answer rated poorly more often
// than well (after a few votes) is dropped, so the next similar case is thought through again.
func (s *Server) diagnoseFeedback(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Ref    string `json:"ref"`
		Helped bool   `json:"helped"`
	}
	if decode(r, &in) != nil || len(in.Ref) > 300 || !strings.Contains(in.Ref, "#") {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	sig, lang, _ := strings.Cut(in.Ref, "#")
	col := "bad"
	if in.Helped {
		col = "good"
	}
	ctx := r.Context()
	s.db.Auth.Exec(ctx, `update ai_library set `+col+` = `+col+` + 1 where sig = $1 and lang = $2`, sig, lang)
	s.db.Auth.Exec(ctx, `delete from ai_library where sig = $1 and lang = $2 and bad >= 3 and bad > good * 2`, sig, lang)
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// POST /v1/brain/ask {q, lang, species?, situation?}: any care question, answered from our own knowledge
// (problems, scenarios, topics, glossary). Free for everyone and never calls a paid model.
func (s *Server) brainAsk(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Q         string              `json:"q"`
		Lang      string              `json:"lang"`
		Species   string              `json:"species"`
		Situation map[string][]string `json:"situation"`
	}
	if decode(r, &in) != nil || len(strings.TrimSpace(in.Q)) < 3 || len(in.Q) > 600 || len(in.Lang) > 12 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	if theBrain.dir == "" {
		theBrain.dir = s.cfg.ContentDir
	}
	lang := in.Lang
	if lang == "" || strings.HasPrefix(lang, "en") {
		lang = "en"
	}
	fit, boost := theBrain.situational(situation(in.Situation))
	type answer struct {
		Kind  string   `json:"kind"`
		Title string   `json:"title"`
		Text  string   `json:"text"`
		Steps []string `json:"steps,omitempty"`
	}
	var out []answer
	sp := theBrain.findSpecies(in.Species)
	for i, m := range theBrain.rank(in.Q, "", boost, speciesEntries(sp)...) {
		if i == 3 || m.score < 0.35 {
			break
		}
		d := theBrain.answerFrom(m, lang)
		out = append(out, answer{m.e.Kind, d.Problem, d.Why, d.Steps})
	}
	for _, d := range theBrain.docs(in.Q, lang, 3) {
		out = append(out, answer{d.kind, d.title, d.text, nil})
	}
	for i, sc := range fit {
		if i == 2 {
			break
		}
		out = append(out, answer{"situation", theBrain.tr(lang, sc.Name), theBrain.tr(lang, sc.Advice), nil})
	}
	if len(out) == 0 {
		s.gap(r.Context(), "ask", in.Q)
	}
	writeJSON(w, http.StatusOK, map[string]any{"answers": out})
}

// PUT /v1/me/weather-watch {lat, lon, lang, on}: a frost or heatwave heads-up for owners with plants outside.
// Only a ~10 km cell is kept.
func (s *Server) weatherWatch(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Lat, Lon float64
		Lang     string
		On       bool
		DeviceID string `json:"deviceId"`
	}
	if decode(r, &in) != nil || in.Lat < -90 || in.Lat > 90 || in.Lon < -180 || in.Lon > 180 || len(in.Lang) > 12 || len(in.DeviceID) != 36 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	var cell, lang any
	if in.On {
		cell, lang = fmt.Sprintf("%.1f,%.1f", math.Round(in.Lat*10)/10, math.Round(in.Lon*10)/10), in.Lang
	}
	c := claimsOf(r)
	err := s.db.AsUser(r.Context(), c.Sub, func(tx pgx.Tx) error {
		_, err := tx.Exec(r.Context(), `update devices set weather_cell = $1, weather_lang = $2 where id = $3 and user_id = $4`, cell, lang, in.DeviceID, c.Sub)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

var weatherText = map[string][2][2]string{ // lang → {frost, heat} → {title, body}
	"en":    {{"Frost tonight", "Bring tender plants inside or cover them before dark."}, {"Heatwave coming", "Water early, shade pots and move tender plants out of the midday sun."}},
	"pt-BR": {{"Geada hoje à noite", "Leva as plantas mais sensíveis pra dentro ou cobre antes de escurecer."}, {"Vem onda de calor", "Rega cedo, faz sombra nos vasos e tira as sensíveis do sol do meio-dia."}},
	"es":    {{"Helada esta noche", "Mete adentro las plantas delicadas o cúbrelas antes de que oscurezca."}, {"Viene una ola de calor", "Riega temprano, da sombra a las macetas y aparta las delicadas del sol del mediodía."}},
	"fr":    {{"Gel cette nuit", "Rentrez les plantes fragiles ou couvrez-les avant la nuit."}, {"Canicule en vue", "Arrosez tôt, ombragez les pots et éloignez les plantes fragiles du soleil de midi."}},
	"de":    {{"Heute Nacht Frost", "Hol empfindliche Pflanzen rein oder deck sie vor Einbruch der Dunkelheit ab."}, {"Hitzewelle im Anmarsch", "Früh gießen, Töpfe beschatten und Empfindliches aus der Mittagssonne holen."}},
	"ja":    {{"今夜は霜の予報", "暗くなる前に、寒さに弱い植物を室内に入れるか覆ってあげましょう。"}, {"猛暑がやってきます", "朝のうちに水やりをして、鉢を日陰に。弱い植物は真昼の日差しから避難させましょう。"}},
}

// weatherLoop checks every watched cell every three hours: frost/heat tonight once a day per device, and
// multi-day patterns over the 16-day forecast once a week per device and pattern.
func (s *Server) weatherLoop(ctx context.Context) {
	t := time.NewTicker(3 * time.Hour)
	defer t.Stop()
	for {
		s.weatherRound(ctx)
		s.weatherPatternsRound(ctx) // multi-day patterns (weatherpatterns.go)
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

func (s *Server) weatherRound(ctx context.Context) {
	if s.pusher == nil {
		return
	}
	rows, err := s.db.Auth.Query(ctx, `select distinct weather_cell from devices where weather_cell is not null and push_token is not null and (weather_alert_on is null or weather_alert_on < current_date)`)
	if err != nil {
		return
	}
	cells, _ := pgx.CollectRows(rows, pgx.RowTo[string])
	for _, cell := range cells {
		var lat, lon float64
		if _, err := fmt.Sscanf(cell, "%f,%f", &lat, &lon); err != nil {
			continue
		}
		kind := forecastRisk(ctx, lat, lon)
		if kind < 0 {
			continue
		}
		drows, err := s.db.Auth.Query(ctx, `update devices set weather_alert_on = current_date where weather_cell = $1 and push_token is not null and (weather_alert_on is null or weather_alert_on < current_date) returning platform, push_token, coalesce(weather_lang, 'en')`, cell)
		if err != nil {
			continue
		}
		type dev struct{ Platform, Token, Lang string }
		devs, _ := pgx.CollectRows(drows, pgx.RowToStructByPos[dev])
		for _, d := range devs {
			txt, ok := weatherText[d.Lang]
			if !ok {
				txt = weatherText["en"]
			}
			s.pusher.alert(ctx, d.Platform, d.Token, txt[kind][0], txt[kind][1], "weather")
		}
	}
}

// forecastRisk: 0 frost (≤ 1 °C tonight), 1 heatwave (≥ 34 °C today or tomorrow), -1 nothing.
func forecastRisk(ctx context.Context, lat, lon float64) int {
	cctx, cancel := context.WithTimeout(ctx, 6*time.Second)
	defer cancel()
	u := fmt.Sprintf("https://api.open-meteo.com/v1/forecast?latitude=%.1f&longitude=%.1f&daily=temperature_2m_max,temperature_2m_min&forecast_days=2&timezone=auto", lat, lon)
	req, _ := http.NewRequestWithContext(cctx, "GET", u, nil)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return -1
	}
	defer res.Body.Close()
	var f struct {
		Daily struct {
			Max []float64 `json:"temperature_2m_max"`
			Min []float64 `json:"temperature_2m_min"`
		}
	}
	if json.NewDecoder(res.Body).Decode(&f) != nil {
		return -1
	}
	for _, m := range f.Daily.Min {
		if m <= 1 {
			return 0
		}
	}
	for _, m := range f.Daily.Max {
		if m >= 34 {
			return 1
		}
	}
	return -1
}
