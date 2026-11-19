package api

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
)

// Multi-day weather patterns from Open-Meteo's 16-day forecast (plus the last 7 days, to tell a first frost):
//   hot_dry_week  ≥ 4 of the next 7 days at ≥ 30 °C with < 5 mm rain in total
//   first_frost   a night ≤ 0 °C within 5 days after a frost-free week
//   heavy_rain    ≥ 3 days in a row with ≥ 10 mm
// One push per device per pattern per ISO week (weather_pattern_sent). Cells are cached 3 h in memory.

type weatherPattern struct {
	Kind string    `json:"kind"` // hot_dry_week | first_frost | heavy_rain
	From time.Time `json:"from"` // first day of the pattern (local date at 00:00 UTC)
	To   time.Time `json:"to"`
}

type forecast16 struct {
	Days []time.Time
	Max  []float64
	Min  []float64
	Rain []float64
	Past int // leading days that are history
}

var fcCache = struct {
	sync.Mutex
	m map[string]struct {
		at time.Time
		f  *forecast16
	}
}{m: map[string]struct {
	at time.Time
	f  *forecast16
}{}}

func fetchForecast16(ctx context.Context, cell string) *forecast16 {
	fcCache.Lock()
	if c, ok := fcCache.m[cell]; ok && time.Since(c.at) < 3*time.Hour {
		fcCache.Unlock()
		return c.f
	}
	fcCache.Unlock()
	var lat, lon float64
	if _, err := fmt.Sscanf(cell, "%f,%f", &lat, &lon); err != nil {
		return nil
	}
	cctx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	u := fmt.Sprintf("https://api.open-meteo.com/v1/forecast?latitude=%.1f&longitude=%.1f&daily=temperature_2m_max,temperature_2m_min,precipitation_sum&forecast_days=16&past_days=7&timezone=auto", lat, lon)
	req, _ := http.NewRequestWithContext(cctx, "GET", u, nil)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil
	}
	defer res.Body.Close()
	var raw struct {
		Daily struct {
			Time []string  `json:"time"`
			Max  []float64 `json:"temperature_2m_max"`
			Min  []float64 `json:"temperature_2m_min"`
			Rain []float64 `json:"precipitation_sum"`
		}
	}
	if res.StatusCode != 200 || json.NewDecoder(res.Body).Decode(&raw) != nil {
		return nil
	}
	f := &forecast16{Max: raw.Daily.Max, Min: raw.Daily.Min, Rain: raw.Daily.Rain, Past: 7}
	for _, t := range raw.Daily.Time {
		d, _ := time.Parse("2006-01-02", t)
		f.Days = append(f.Days, d)
	}
	if n := len(f.Days); len(f.Max) != n || len(f.Min) != n || len(f.Rain) != n || n <= f.Past {
		return nil
	}
	fcCache.Lock()
	fcCache.m[cell] = struct {
		at time.Time
		f  *forecast16
	}{time.Now(), f}
	fcCache.Unlock()
	return f
}

// detectPatterns finds the patterns in a forecast. Index Past is today.
func detectPatterns(f *forecast16) []weatherPattern {
	if f == nil {
		return nil
	}
	var out []weatherPattern
	n, t := len(f.Days), f.Past
	// Hot dry week: next 7 days from tomorrow.
	if t+7 < n {
		hot, rain, first, last := 0, 0.0, -1, -1
		for i := t + 1; i <= t+7; i++ {
			rain += f.Rain[i]
			if f.Max[i] >= 30 {
				hot++
				if first < 0 {
					first = i
				}
				last = i
			}
		}
		if hot >= 4 && rain < 5 {
			out = append(out, weatherPattern{"hot_dry_week", f.Days[first], f.Days[last]})
		}
	}
	// First frost within 5 days after a frost-free past week.
	frostBefore := false
	for i := 0; i < t; i++ {
		if f.Min[i] <= 0 {
			frostBefore = true
		}
	}
	if !frostBefore {
		for i := t; i <= t+5 && i < n; i++ {
			if f.Min[i] <= 0 {
				out = append(out, weatherPattern{"first_frost", f.Days[i], f.Days[i]})
				break
			}
		}
	}
	// Heavy rain run: 3+ consecutive days ≥ 10 mm anywhere ahead.
	for i := t; i < n; i++ {
		j := i
		for j < n && f.Rain[j] >= 10 {
			j++
		}
		if j-i >= 3 {
			out = append(out, weatherPattern{"heavy_rain", f.Days[i], f.Days[j-1]})
			break
		}
		if j > i {
			i = j
		}
	}
	return out
}

var patternText = map[string]map[string][2]string{ // lang → kind → {title, body}
	"en": {
		"hot_dry_week": {"Hot, dry week ahead", "Several days over 30 °C and almost no rain. Check pots daily, water early and give outdoor plants some shade."},
		"first_frost":  {"First frost this week", "Nights drop below 0 °C soon. Plan to bring tender plants inside or cover them."},
		"heavy_rain":   {"Days of heavy rain coming", "Several wet days in a row. Lift pots off saucers, skip watering outdoors and check drainage."},
	},
	"pt-BR": {
		"hot_dry_week": {"Vem aí uma semana quente e seca", "Vários dias acima de 30 °C e quase sem chuva. Dá uma olhada nos vasos todo dia, rega cedo e faz sombra pras plantas de fora."},
		"first_frost":  {"Primeira geada da semana", "As noites vão ficar abaixo de 0 °C. Já se planeja pra levar as sensíveis pra dentro ou cobrir."},
		"heavy_rain":   {"Vem chuva forte por uns dias", "Vários dias seguidos de chuva. Tira os pratinhos, não rega as plantas de fora e confere a drenagem."},
	},
	"es": {
		"hot_dry_week": {"Se viene una semana caliente y seca", "Varios días por encima de 30 °C y casi sin lluvia. Revisa las macetas cada día, riega temprano y da sombra a las de afuera."},
		"first_frost":  {"Primera helada de la semana", "Las noches bajarán de 0 °C pronto. Prepárate para meter adentro o cubrir las plantas delicadas."},
		"heavy_rain":   {"Vienen días de lluvia fuerte", "Varios días seguidos de lluvia. Quita los platos, no riegues afuera y revisa el drenaje."},
	},
	"fr": {
		"hot_dry_week": {"Semaine chaude et sèche en vue", "Plusieurs jours au-dessus de 30 °C et presque pas de pluie. Vérifie les pots chaque jour, arrose tôt et ombrage les plantes dehors."},
		"first_frost":  {"Premières gelées cette semaine", "Les nuits passent bientôt sous 0 °C. Prévois de rentrer ou de couvrir les plantes fragiles."},
		"heavy_rain":   {"Plusieurs jours de fortes pluies", "Plusieurs jours de pluie d'affilée. Retire les soucoupes, n'arrose pas dehors et vérifie le drainage."},
	},
	"de": {
		"hot_dry_week": {"Heiße, trockene Woche voraus", "Mehrere Tage über 30 °C und kaum Regen. Töpfe täglich prüfen, früh gießen und Pflanzen draußen beschatten."},
		"first_frost":  {"Erster Frost diese Woche", "Die Nächte fallen bald unter 0 °C. Plane ein, Empfindliches reinzuholen oder abzudecken."},
		"heavy_rain":   {"Tage mit Starkregen kommen", "Mehrere nasse Tage am Stück. Untersetzer weg, draußen nicht gießen und den Abfluss prüfen."},
	},
	"ja": {
		"hot_dry_week": {"暑く乾いた一週間になりそう", "30 °C超えの日が続き、雨はほとんどありません。毎日鉢をチェックし、朝のうちに水やりを。屋外の植物には日よけを。"},
		"first_frost":  {"今週、初霜の予報", "まもなく夜は0 °Cを下回ります。寒さに弱い植物を室内に入れるか、覆う準備をしましょう。"},
		"heavy_rain":   {"強い雨が数日続きます", "雨の日が続きます。受け皿を外し、屋外の水やりはお休みして、水はけを確認しましょう。"},
	},
}

func isoWeekStart(t time.Time) time.Time {
	t = t.UTC().Truncate(24 * time.Hour)
	return t.AddDate(0, 0, -((int(t.Weekday()) + 6) % 7))
}

// weatherPatternsRound pushes new multi-day patterns to watching devices, deduped per device, pattern and week.
func (s *Server) weatherPatternsRound(ctx context.Context) {
	if s.pusher == nil || s.db == nil || s.db.Auth == nil {
		return
	}
	rows, err := s.db.Auth.Query(ctx, `select distinct weather_cell from devices where weather_cell is not null and push_token is not null`)
	if err != nil {
		return
	}
	cells, _ := pgx.CollectRows(rows, pgx.RowTo[string])
	week := isoWeekStart(s.now())
	for _, cell := range cells {
		for _, p := range detectPatterns(fetchForecast16(ctx, cell)) {
			drows, err := s.db.Auth.Query(ctx, `with d as (
					select id, platform, push_token, coalesce(weather_lang, 'en') lang from devices where weather_cell = $1 and push_token is not null),
				ins as (insert into weather_pattern_sent (device_id, pattern, week) select id, $2, $3 from d on conflict do nothing returning device_id)
				select d.platform, d.push_token, d.lang from d join ins on ins.device_id = d.id`, cell, p.Kind, week)
			if err != nil {
				continue
			}
			type dev struct{ Platform, Token, Lang string }
			devs, _ := pgx.CollectRows(drows, pgx.RowToStructByPos[dev])
			for _, d := range devs {
				txt := patternText[digestLang(d.Lang)][p.Kind]
				s.pusher.alertLink(ctx, d.Platform, d.Token, txt[0], txt[1], "weather_"+p.Kind, "mytinyjungle://digest")
			}
		}
	}
	_, _ = s.db.Auth.Exec(ctx, `delete from weather_pattern_sent where week < current_date - 35`)
}

// userPatterns returns the patterns over the given window for the cells of the user's watching devices.
func (s *Server) userPatterns(ctx context.Context, q querier, uid string, from, to time.Time) []weatherPattern {
	rows, err := q.Query(ctx, `select distinct weather_cell from devices where user_id = $1 and weather_cell is not null`, uid)
	if err != nil {
		return []weatherPattern{}
	}
	cells, _ := pgx.CollectRows(rows, pgx.RowTo[string])
	out := []weatherPattern{}
	seen := map[string]bool{}
	for _, cell := range cells {
		for _, p := range detectPatterns(fetchForecast16(ctx, cell)) {
			if p.To.Before(from) || !p.From.Before(to) || seen[p.Kind] {
				continue
			}
			seen[p.Kind] = true
			out = append(out, p)
		}
	}
	return out
}
