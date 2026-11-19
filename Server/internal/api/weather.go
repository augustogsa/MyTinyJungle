package api

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"sync"
	"time"
)

// Weather around the plant (Open-Meteo, free, no key; coordinates rounded to ~10 km and never stored):
// the past 7 days, the 16-day forecast, this month's climate normals (1991–2020) and the season by hemisphere.
// It becomes situation keys for the knowledge base and short reasons that cite the numbers.
type weatherFacts struct {
	Lat        float64 `json:"lat"`
	Month      int     `json:"month"` // 1–12; 0 = now
	TempNow    float64 `json:"tempNow"`
	RHNow      float64 `json:"rhNow"`
	WindNow    float64 `json:"windNow"`
	CloudNow   float64 `json:"cloudNow"`
	RainNow    float64 `json:"rainNow"`
	Rain7      float64 `json:"rain7"` // mm over the past 7 days
	Max7       float64 `json:"max7"`
	Min7       float64 `json:"min7"`
	Rain16     float64 `json:"rain16"`
	RainDays16 int     `json:"rainDays16"` // days with ≥ 2 mm
	Max16      float64 `json:"max16"`
	Min16      float64 `json:"min16"`
	FrostDays  int     `json:"frostDays16"` // min ≤ 0 °C
	HeatDays   int     `json:"heatDays16"`  // max ≥ 32 °C
	RainToday  float64 `json:"rainToday"`
	NormalMax  float64 `json:"normalMax"` // mean daily max for this month, 1991–2020
	NormalMin  float64 `json:"normalMin"`
	NormalRain float64 `json:"normalRain"` // mm per month
	HasNormals bool    `json:"hasNormals"`
}

var weatherCache, normalsCache sync.Map

func getJSON(ctx context.Context, u string, out any) bool {
	cctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(cctx, "GET", u, nil)
	req.Header.Set("User-Agent", "MyTinyJungle-brain/1.0 (support@simpleappscompany.com)")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return false
	}
	defer res.Body.Close()
	return res.StatusCode == 200 && json.NewDecoder(res.Body).Decode(out) == nil
}

// weatherFactsAt reads (and caches for an hour) the weather near the plant. nil when unavailable.
func weatherFactsAt(ctx context.Context, lat, lon float64) *weatherFacts {
	key := fmt.Sprintf("%.1f,%.1f", lat, lon)
	type cached struct {
		at time.Time
		f  *weatherFacts
	}
	if c, ok := weatherCache.Load(key); ok && time.Since(c.(cached).at) < time.Hour {
		return c.(cached).f
	}
	var w struct {
		Current struct {
			T     float64 `json:"temperature_2m"`
			RH    float64 `json:"relative_humidity_2m"`
			Rain  float64 `json:"precipitation"`
			Wind  float64 `json:"wind_speed_10m"`
			Cloud float64 `json:"cloud_cover"`
		}
		Daily struct {
			Time []string  `json:"time"`
			Max  []float64 `json:"temperature_2m_max"`
			Min  []float64 `json:"temperature_2m_min"`
			Rain []float64 `json:"precipitation_sum"`
		}
	}
	u := fmt.Sprintf("https://api.open-meteo.com/v1/forecast?latitude=%.1f&longitude=%.1f&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,cloud_cover&daily=temperature_2m_max,temperature_2m_min,precipitation_sum&past_days=7&forecast_days=16&timezone=auto", lat, lon)
	if !getJSON(ctx, u, &w) || len(w.Daily.Max) < 8 {
		return nil
	}
	f := &weatherFacts{Lat: lat, Month: int(time.Now().Month()), TempNow: w.Current.T, RHNow: w.Current.RH, WindNow: w.Current.Wind, CloudNow: w.Current.Cloud, RainNow: w.Current.Rain,
		Max7: -99, Min7: 99, Max16: -99, Min16: 99}
	d := w.Daily
	for i := range d.Max {
		rain := 0.0
		if i < len(d.Rain) {
			rain = d.Rain[i]
		}
		if i < 7 { // the past week
			f.Rain7 += rain
			f.Max7, f.Min7 = math.Max(f.Max7, d.Max[i]), math.Min(f.Min7, d.Min[i])
			continue
		}
		if i == 7 {
			f.RainToday = rain
		}
		f.Rain16 += rain
		f.Max16, f.Min16 = math.Max(f.Max16, d.Max[i]), math.Min(f.Min16, d.Min[i])
		if rain >= 2 {
			f.RainDays16++
		}
		if d.Min[i] <= 0 {
			f.FrostDays++
		}
		if d.Max[i] >= 32 {
			f.HeatDays++
		}
	}
	f.NormalMax, f.NormalMin, f.NormalRain, f.HasNormals = normalsAt(ctx, lat, lon, f.Month)
	weatherCache.Store(key, cached{time.Now(), f})
	return f
}

// normalsAt: this month's 1991–2020 climate means from Open-Meteo's climate API, cached per cell and month.
func normalsAt(ctx context.Context, lat, lon float64, month int) (mx, mn, rain float64, ok bool) {
	key := fmt.Sprintf("%.1f,%.1f,%d", lat, lon, month)
	if c, hit := normalsCache.Load(key); hit {
		v := c.([3]float64)
		return v[0], v[1], v[2], true
	}
	var w struct {
		Daily struct {
			Time []string  `json:"time"`
			Max  []float64 `json:"temperature_2m_max"`
			Min  []float64 `json:"temperature_2m_min"`
			Rain []float64 `json:"precipitation_sum"`
		}
	}
	u := fmt.Sprintf("https://climate-api.open-meteo.com/v1/climate?latitude=%.1f&longitude=%.1f&start_date=1991-01-01&end_date=2020-12-31&models=EC_Earth3P_HR&daily=temperature_2m_max,temperature_2m_min,precipitation_sum", lat, lon)
	if !getJSON(ctx, u, &w) {
		return 0, 0, 0, false
	}
	var n, sx, sn, sr float64
	for i, t := range w.Daily.Time {
		if len(t) >= 7 && t[5:7] == fmt.Sprintf("%02d", month) && i < len(w.Daily.Max) && i < len(w.Daily.Min) && i < len(w.Daily.Rain) {
			n, sx, sn, sr = n+1, sx+w.Daily.Max[i], sn+w.Daily.Min[i], sr+w.Daily.Rain[i]
		}
	}
	if n == 0 {
		return 0, 0, 0, false
	}
	v := [3]float64{sx / n, sn / n, sr / n * 30.4}
	normalsCache.Store(key, v)
	return v[0], v[1], v[2], true
}

// season by hemisphere; "" in the tropics, where seasons don't follow the calendar.
func seasonAt(lat float64, month int) string {
	if lat > -23.5 && lat < 23.5 {
		return ""
	}
	s := map[int]string{12: "winter", 1: "winter", 2: "winter", 3: "spring", 4: "spring", 5: "spring", 6: "summer", 7: "summer", 8: "summer", 9: "autumn", 10: "autumn", 11: "autumn"}[month]
	if lat < 0 {
		s = map[string]string{"winter": "summer", "summer": "winter", "spring": "autumn", "autumn": "spring"}[s]
	}
	return s
}

func (f *weatherFacts) situation() situation {
	sit := situation{}
	if f == nil {
		return sit
	}
	add := func(k, v string) { sit[k] = append(sit[k], v) }
	if f.RainNow > 0.2 || f.RainToday >= 2 || f.Rain7 >= 15 {
		add("weather", "rainy")
	}
	if f.RHNow >= 75 {
		add("weather", "humid")
	} else if f.RHNow > 0 && f.RHNow <= 35 {
		add("weather", "dry")
	}
	if f.WindNow >= 35 {
		add("weather", "windy")
	}
	if f.WindNow >= 60 {
		add("weather", "storm")
	}
	if f.CloudNow >= 85 {
		add("weather", "cloudy-days")
	}
	if f.HeatDays >= 2 || f.Max7 >= 32 {
		add("weather", "heatwave")
	}
	if f.FrostDays > 0 || f.Min7 <= 0 {
		add("weather", "frost")
	} else if f.TempNow <= 8 || f.Min16 <= 5 {
		add("weather", "cold-snap")
	}
	m := f.Month
	if m == 0 {
		m = int(time.Now().Month())
	}
	if s := seasonAt(f.Lat, m); s != "" {
		add("season", s)
	}
	return sit
}

// weatherAt keeps the old shape: situation keys only.
func weatherAt(ctx context.Context, lat, lon float64) situation {
	return weatherFactsAt(ctx, lat, lon).situation()
}

// notes are short reasons that cite the weather, in the owner's language. outdoor: the plant lives outside.
func (f *weatherFacts) notes(lang string, outdoor bool, sp *species) []string {
	if f == nil {
		return nil
	}
	var out []string
	say := func(tpl string, args ...any) { out = append(out, fmt.Sprintf(theBrain.tr(lang, tpl), args...)) }
	tender := sp == nil || sp.TempMin >= 8
	if outdoor && f.Rain7 >= 15 {
		say("About %d mm of rain fell this past week, so outdoor pots need no extra water for now.", int(math.Round(f.Rain7)))
	}
	if outdoor && f.RainToday >= 5 {
		say("%d mm of rain is forecast today: skip watering outdoor plants.", int(math.Round(f.RainToday)))
	} else if outdoor && f.RainDays16 >= 6 {
		say("Rain is expected on %d of the next 16 days: water outdoor plants only in dry spells.", f.RainDays16)
	}
	if f.FrostDays > 0 && (outdoor || tender) {
		say("Frost is forecast on %d of the next 16 days (down to %d °C): bring tender plants in or cover them.", f.FrostDays, int(math.Round(f.Min16)))
	}
	if f.HeatDays > 0 {
		say("Up to %d °C is forecast in the next 16 days: water early and keep pots out of the midday sun.", int(math.Round(f.Max16)))
	}
	if f.HasNormals && f.Max7 > f.NormalMax+4 {
		say("This past week was about %d °C warmer than usual for the month, so soil dries faster than normal.", int(math.Round(f.Max7-f.NormalMax)))
	}
	if f.HasNormals && f.Max7 < f.NormalMax-4 {
		say("This past week was about %d °C cooler than usual for the month, so water a little less.", int(math.Round(f.NormalMax-f.Max7)))
	}
	if outdoor && f.HasNormals && f.NormalRain > 0 && f.Rain7 < f.NormalRain/8 && f.Max7 >= 20 {
		say("Hardly any rain this week (%d mm, usually about %d mm a week): outdoor pots will need you.", int(math.Round(f.Rain7)), int(math.Round(f.NormalRain/4.3)))
	}
	if f.RHNow > 0 && f.RHNow <= 35 && !outdoor {
		say("The air outside is very dry today (%d%% humidity); with heating or AC on, indoor air gets drier still.", int(math.Round(f.RHNow)))
	}
	return out
}

// resolveWeather prefers weather sent with the request, else reads it near lat/lon.
func resolveWeather(ctx context.Context, given *weatherFacts, lat, lon *float64) *weatherFacts {
	if given != nil {
		if given.Month == 0 {
			given.Month = int(time.Now().Month())
		}
		return given
	}
	if lat == nil || lon == nil || *lat < -90 || *lat > 90 || *lon < -180 || *lon > 180 {
		return nil
	}
	return weatherFactsAt(ctx, math.Round(*lat*10)/10, math.Round(*lon*10)/10)
}

func isOutdoor(sit situation) bool {
	for _, r := range sit["room"] {
		if r == "outdoor" || r == "balcony" {
			return true
		}
	}
	for _, m := range sit["medium"] {
		if m == "ground" {
			return true
		}
	}
	return false
}

func mergeSit(into, from situation) situation {
	if into == nil {
		into = situation{}
	}
	for k, v := range from {
		if _, set := into[k]; !set {
			into[k] = v
		}
	}
	return into
}
