package api

import (
	"encoding/json"
	"testing"
	"time"
)

func TestBrainConfigMerge(t *testing.T) {
	var overlay map[string]any
	json.Unmarshal([]byte(`{
		"base": {"identify": {"timeoutS": 9}, "flags": {"serverIdentify": false}},
		"lang": {"pt": {"identify": {"bands": [{"id": "x", "min": 0, "word": "Pode ser"}]}}, "pt-BR": {"scan": {"cap": 6}}},
		"experiments": [{"name": "cap", "variants": [{"name": "a", "weight": 1}, {"name": "b", "weight": 1, "set": {"scan": {"floor": 0.3}}}]}]
	}`), &overlay)
	cfg, exps := buildBrainConfig(overlay, "pt-BR", "")
	id := cfg["identify"].(map[string]any)
	if id["timeoutS"].(float64) != 9 || id["maxCandidates"].(int) != 3 {
		t.Fatalf("identify %v", id)
	}
	if cfg["flags"].(map[string]any)["serverIdentify"] != false || cfg["flags"].(map[string]any)["onDeviceVision"] != true {
		t.Fatal("flags")
	}
	if len(id["bands"].([]any)) != 1 || cfg["scan"].(map[string]any)["cap"].(float64) != 6 {
		t.Fatal("lang overlay")
	}
	if exps["cap"] != "a" {
		t.Fatalf("no device is control: %v", exps)
	}
	en, _ := buildBrainConfig(overlay, "en", "")
	if len(en["identify"].(map[string]any)["bands"].([]any)) != 3 || en["scan"].(map[string]any)["cap"].(int) != 8 {
		t.Fatal("en must keep defaults")
	}
	seen := map[string]bool{}
	for _, d := range []string{"d1", "d2", "d3", "d4", "d5", "d6", "d7", "d8", "d9", "d10", "d11", "d12"} {
		_, e1 := buildBrainConfig(overlay, "en", d)
		_, e2 := buildBrainConfig(overlay, "en", d)
		if e1["cap"] != e2["cap"] {
			t.Fatal("variant not stable")
		}
		seen[e1["cap"]] = true
	}
	if !seen["a"] || !seen["b"] {
		t.Fatalf("both variants should show up: %v", seen)
	}
}

func TestLiveCards(t *testing.T) {
	now := time.Date(2026, 11, 20, 0, 0, 0, 0, time.UTC)
	cards := []any{
		map[string]any{"id": "a"},
		map[string]any{"id": "old", "until": "2026-11-01T00:00:00Z"},
		map[string]any{"id": "later", "from": "2026-12-01T00:00:00Z"},
		map[string]any{"id": "pt", "langs": []any{"pt"}},
	}
	if got := liveCards(cards, "pt-BR", now); len(got) != 2 {
		t.Fatalf("pt %v", got)
	}
	if got := liveCards(cards, "de", now); len(got) != 1 {
		t.Fatalf("de %v", got)
	}
}

func TestReadOutcome(t *testing.T) {
	o := outcomeRow{kind: "identify"}
	readOutcome(&o, 200, []byte(`{"candidates":[{"id":"monstera-deliciosa","score":0.42}]}`))
	if o.outcome != "low" || o.species != "monstera-deliciosa" || *o.conf != 0.42 {
		t.Fatalf("%+v", o)
	}
	o = outcomeRow{kind: "identify"}
	readOutcome(&o, 200, []byte(`{"candidates":[]}`))
	if o.outcome != "empty" {
		t.Fatal(o.outcome)
	}
	o = outcomeRow{kind: "diagnose"}
	readOutcome(&o, 200, []byte(`{"confidence":"high","ids":["overwatering"],"source":"library"}`))
	if o.outcome != "answered" || o.slice != ";top=overwatering;src=library" {
		t.Fatalf("%+v", o)
	}
	o = outcomeRow{kind: "ask"}
	readOutcome(&o, 429, nil)
	if o.outcome != "error_429" {
		t.Fatal(o.outcome)
	}
}

func TestWithExtras(t *testing.T) {
	var overlay map[string]any
	json.Unmarshal([]byte(`{"base":{"ask":{"extras":{"overwatering":{"chips":["How often?"],"actions":[{"label":"Check soil","link":"mytinyjungle://scan?purpose=doctor"}]}}}}}`), &overlay)
	cfg, _ := buildBrainConfig(overlay, "en", "")
	in := []askAnswer{{ID: "overwatering", Kind: "symptom"}, {ID: "x"}}
	out := withExtras(in, cfg)
	if len(out[0].Chips) != 1 || out[0].Actions[0].Link == "" || len(in[0].Chips) != 0 || out[1].Chips != nil {
		t.Fatalf("%+v", out)
	}
}
