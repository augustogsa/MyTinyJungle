package api

import (
	"encoding/json"
	"strings"
	"testing"
	"time"
)

func TestDetectPatterns(t *testing.T) {
	day := func(i int) time.Time { return time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC).AddDate(0, 0, i) }
	f := &forecast16{Past: 7}
	for i := 0; i < 23; i++ {
		f.Days = append(f.Days, day(i))
		f.Max = append(f.Max, 22)
		f.Min = append(f.Min, 8)
		f.Rain = append(f.Rain, 0)
	}
	if p := detectPatterns(f); len(p) != 0 {
		t.Fatalf("calm: %v", p)
	}
	for i := 8; i <= 12; i++ {
		f.Max[i] = 33
	}
	f.Min[10] = -1
	for i := 16; i <= 19; i++ {
		f.Rain[i] = 15
	}
	var kinds []string
	for _, p := range detectPatterns(f) {
		kinds = append(kinds, p.Kind)
	}
	if strings.Join(kinds, ",") != "hot_dry_week,first_frost,heavy_rain" {
		t.Fatalf("got %v", kinds)
	}
	f.Min[2] = -2 // frost last week: not the first one
	for _, p := range detectPatterns(f) {
		if p.Kind == "first_frost" {
			t.Fatal("frost after an earlier frost reported as first")
		}
	}
	for _, l := range []string{"en", "pt-BR", "es", "fr", "de", "ja"} {
		for _, k := range []string{"hot_dry_week", "first_frost", "heavy_rain"} {
			if patternText[l][k][0] == "" || patternText[l][k][1] == "" {
				t.Fatalf("missing text %s %s", l, k)
			}
		}
	}
}

func TestMoisture(t *testing.T) {
	for raw, ok := range map[string]bool{`{}`: true, `{"moisture":null}`: true, `{"moisture":{"method":"meter","value":4}}`: true,
		`{"moisture":{"method":"finger","value":2}}`: true, `{"moisture":{"method":"finger","value":3}}`: false,
		`{"moisture":{"method":"meter","value":11}}`: false, `{"moisture":{"method":"eye","value":1}}`: false, `{"moisture":{"method":"meter"}}`: false} {
		if validMoisture(json.RawMessage(raw)) != ok {
			t.Fatalf("%s want %v", raw, ok)
		}
	}
	now := time.Date(2026, 11, 20, 12, 0, 0, 0, time.UTC)
	ts := func(d float64) float64 { return float64(now.Add(time.Duration(d * 24 * float64(time.Hour))).Unix()) }
	care := func(string) speciesCare { return speciesCare{dry: 10} }
	base := []rec{{"j", "plant", "p", map[string]any{"createdAt": ts(-60)}}, {"j", "care_event", "w", map[string]any{"plantID": "p", "kind": "water", "date": ts(-4)}}}
	plain := schedules(base, now, care)["p"].NextWater
	if !plain.Equal(epoch(ts(-4)).Add(10 * 24 * time.Hour)) {
		t.Fatalf("plain %v", plain)
	}
	dry := schedules(append(base, rec{"j", "care_event", "m", map[string]any{"plantID": "p", "kind": "soilCheck", "date": ts(-1), "moisture": map[string]any{"method": "meter", "value": 2.0}}}), now, care)["p"]
	if !dry.NextWater.Equal(epoch(ts(-1))) || dry.Moisture != 0 {
		t.Fatalf("dry %v", dry.NextWater)
	}
	wet := schedules(append(base, rec{"j", "care_event", "m", map[string]any{"plantID": "p", "kind": "soilCheck", "date": ts(-0.5), "soil": "wet"}}), now, care)["p"]
	if !wet.NextWater.Equal(plain) {
		t.Fatalf("wet keeps later date: %v", wet.NextWater)
	}
	wet2 := schedules(append(base, rec{"j", "care_event", "m", map[string]any{"plantID": "p", "kind": "soilCheck", "date": ts(-0.1), "moisture": map[string]any{"method": "finger", "value": 2.0}}}), now, func(string) speciesCare { return speciesCare{dry: 4} })["p"]
	if !wet2.NextWater.Equal(epoch(ts(-0.1)).Add(48 * time.Hour)) {
		t.Fatalf("wet pushes later: %v", wet2.NextWater)
	}
}

func TestDigestNext(t *testing.T) {
	now := time.Date(2026, 11, 22, 18, 0, 0, 0, time.UTC) // Sunday
	ts := func(d int) float64 { return float64(now.AddDate(0, 0, d).Unix()) }
	recs := []rec{
		{"j", "plant", "p1", map[string]any{"name": "Fern", "learnedDryDays": 3.0, "createdAt": ts(-90)}},
		{"j", "care_event", "e1", map[string]any{"plantID": "p1", "kind": "water", "date": ts(-1)}},
		{"j", "care_task", "t1", map[string]any{"title": "Repot", "plantID": "p1", "due": ts(3), "done": false}},
	}
	d := buildDigest(recs, now, func(string) speciesCare { return speciesCare{} })
	if d.Next == nil || d.Next.Week != "2026-11-23" {
		t.Fatalf("next %+v", d.Next)
	}
	water, task := 0, 0
	for _, it := range d.Next.Due {
		switch it.Kind {
		case "water":
			water++
		case "task":
			task++
		}
	}
	if water < 2 || task != 1 {
		t.Fatalf("next due %+v", d.Next.Due)
	}
}

func TestParseBoxes(t *testing.T) {
	b := parseBoxes(`[{"bbox_2d":[10,20,200,300],"label":"plant"},{"bbox_2d":[12,22,198,305]},{"bbox_2d":[400,50,700,400]}]`, 756, 500)
	if len(b) != 2 || b[0].X > b[1].X {
		t.Fatalf("boxes %+v", b)
	}
	if len(parseBoxes("no plants here", 756, 500)) != 0 {
		t.Fatal("phantom boxes")
	}
	if g := gridBoxes(1200, 800); len(g) != 6 {
		t.Fatalf("grid %d", len(g))
	}
}

func TestRoutesRegister(t *testing.T) { _ = testServer(t).Handler() }
