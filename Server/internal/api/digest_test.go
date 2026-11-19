package api

import (
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestDigest(t *testing.T) {
	now := time.Date(2026, 11, 22, 18, 0, 0, 0, time.UTC) // Sunday
	ts := func(d time.Duration) float64 { return float64(now.Add(d).Unix()) }
	day := 24 * time.Hour
	recs := []rec{
		{"j", "plant", "p1", map[string]any{"name": "Fern", "learnedDryDays": 5.0, "createdAt": ts(-90 * day)}},
		{"j", "plant", "p2", map[string]any{"name": "Old", "createdAt": ts(-90 * day)}},
		{"j", "plant", "p3", map[string]any{"name": "Gone", "isArchived": true, "createdAt": ts(-90 * day)}},
		{"j", "care_event", "e1", map[string]any{"plantID": "p1", "kind": "water", "date": ts(-3 * day)}},
		{"j", "care_event", "e2", map[string]any{"plantID": "p1", "kind": "newLeaf", "date": ts(-1 * day), "photo": "abc"}},
		{"j", "care_event", "e3", map[string]any{"plantID": "p3", "kind": "newLeaf", "date": ts(-1 * day)}},
		{"j", "care_task", "t1", map[string]any{"title": "Repot", "plantID": "p2", "due": ts(2 * day), "done": false}},
		{"j", "care_task", "t2", map[string]any{"title": "Done", "due": ts(day), "done": true}},
	}
	d := buildDigest(recs, now, func(string) speciesCare { return speciesCare{} })
	if d.Week != "2026-11-16" {
		t.Fatalf("week %s", d.Week)
	}
	kinds := func(items []digestItem) string {
		var s []string
		for _, i := range items {
			s = append(s, i.Plant+":"+i.Kind)
		}
		return strings.Join(s, ",")
	}
	// Fern water due in 2 days; Old never watered since creation 90 days ago: overdue, very overdue, quiet.
	if got := kinds(d.Due); !strings.Contains(got, "Fern:water") || !strings.Contains(got, "Old:water") || !strings.Contains(got, "Old:task") || strings.Contains(got, "Done") {
		t.Fatalf("due %s", got)
	}
	if got := kinds(d.Watch); !strings.Contains(got, "Old:overdue_water") || !strings.Contains(got, "Old:quiet") || strings.Contains(got, "Fern") {
		t.Fatalf("watch %s", got)
	}
	if got := kinds(d.Grew); got != "Fern:newLeaf" {
		t.Fatalf("grew %s", got)
	}
	if len(d.Photos) != 1 || d.Photos[0].Media != "/v1/media/j/e2" {
		t.Fatalf("photos %+v", d.Photos)
	}
	title, body, ok := digestPush(d, "pt_BR")
	if !ok || title != "Sua selva essa semana" || body != "3 cuidados pra fazer · 1 planta pra ficar de olho" {
		t.Fatalf("push %q %q", title, body)
	}
	if _, body, _ := digestPush(d, "ja-JP"); !strings.Contains(body, "お世話 3件") {
		t.Fatalf("ja %q", body)
	}
	if _, _, ok := digestPush(digest{}, "en"); ok {
		t.Fatal("empty digest should not push")
	}
	if digestLang("de-AT") != "de" || digestLang("zh") != "en" || digestLang("") != "en" {
		t.Fatal("lang")
	}
}

func TestPaidCapZeroBlocks(t *testing.T) {
	t.Setenv("MTJ_AI_MONTHLY_CAP", "0")
	testServer(t)
	req, _ := http.NewRequest("POST", "https://api.anthropic.com/v1/messages", nil)
	res, err := http.DefaultClient.Transport.RoundTrip(req)
	if err != nil || res.StatusCode != http.StatusForbidden {
		t.Fatalf("got %v %v", res, err)
	}
	b, _ := io.ReadAll(res.Body)
	if !strings.Contains(string(b), "monthly_cap") {
		t.Fatal(string(b))
	}
}
