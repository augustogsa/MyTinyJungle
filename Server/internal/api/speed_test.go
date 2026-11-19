package api

import (
	"bytes"
	"compress/gzip"
	"encoding/base64"
	"image"
	"image/color"
	"image/jpeg"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/andybalholm/brotli"
)

const webp900 = "UklGRmwEAABXRUJQVlA4IGAEAABQeQCdASqEA1gCPrVaqlCnJSOioAgA4BaJaW7hd2EfhEAAnsA99snIe+2TkPfbJyHvtk5D32ych77ZOQ+2/28zP9vfeaPJff/b33mjyX3/2995o8l9/9vfeaPJff/b2EF2lQLJdrxcnIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D32ych77ZOQ99snIe+2TkPfbJyHvtk5D3pAAP7/hrv/wb5F837v/+tv+IP+II2QLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaLRaJnsuBAYcCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

func TestNormPhoto(t *testing.T) {
	img := image.NewRGBA(image.Rect(0, 0, 1600, 1200))
	for i := range img.Pix {
		img.Pix[i] = 120
	}
	var b bytes.Buffer
	jpeg.Encode(&b, img, nil)
	for name, in := range map[string]string{"jpeg 1600": base64.StdEncoding.EncodeToString(b.Bytes()), "webp 900": webp900} {
		out, err := normPhoto(in)
		if err != nil {
			t.Fatal(name, err)
		}
		raw, _ := base64.StdEncoding.DecodeString(out)
		cfg, f, err := image.DecodeConfig(bytes.NewReader(raw))
		if err != nil || f != "jpeg" || max(cfg.Width, cfg.Height) != photoSide {
			t.Fatalf("%s: %s %dx%d %v", name, f, cfg.Width, cfg.Height, err)
		}
	}
	small := image.NewRGBA(image.Rect(0, 0, 400, 300))
	small.Set(1, 1, color.White)
	b.Reset()
	jpeg.Encode(&b, small, nil)
	in := base64.StdEncoding.EncodeToString(b.Bytes())
	if out, _ := normPhoto(in); out != in {
		t.Fatal("a small JPEG must pass through untouched (same sha256 cache key)")
	}
	if _, err := normPhoto(base64.StdEncoding.EncodeToString([]byte("GIF89a not a photo"))); err == nil {
		t.Fatal("non JPEG/WebP accepted")
	}
}

func TestETagAndCompression(t *testing.T) {
	body := bytes.Repeat([]byte(`{"plants":"monstera"}`), 200)
	h := etag(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write(body)
	}))
	s := &Server{limiter: NewLimiter(), log: slog.New(slog.NewTextHandler(io.Discard, nil))}
	srv := s.wrap(h)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/v1/me/digest", nil)
	req.Header.Set("Accept-Encoding", "br, gzip")
	srv.ServeHTTP(rec, req)
	tag := rec.Header().Get("ETag")
	if rec.Code != 200 || tag == "" || rec.Header().Get("Content-Encoding") != "br" {
		t.Fatalf("%d etag=%q enc=%q", rec.Code, tag, rec.Header().Get("Content-Encoding"))
	}
	got, _ := io.ReadAll(brotli.NewReader(rec.Body))
	if !bytes.Equal(got, body) {
		t.Fatal("brotli body differs")
	}
	rec = httptest.NewRecorder()
	req = httptest.NewRequest("GET", "/v1/me/digest", nil)
	req.Header.Set("If-None-Match", tag)
	srv.ServeHTTP(rec, req)
	if rec.Code != 304 || rec.Body.Len() != 0 {
		t.Fatalf("want 304 empty, got %d %d bytes", rec.Code, rec.Body.Len())
	}
	rec = httptest.NewRecorder()
	req = httptest.NewRequest("GET", "/v1/me/digest", nil)
	req.Header.Set("Accept-Encoding", "gzip")
	srv.ServeHTTP(rec, req)
	zr, err := gzip.NewReader(rec.Body)
	if err != nil {
		t.Fatal(err)
	}
	got, _ = io.ReadAll(zr)
	if !bytes.Equal(got, body) {
		t.Fatal("gzip body differs")
	}
	rec = httptest.NewRecorder()
	req = httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Accept", "text/event-stream")
	req.Header.Set("Accept-Encoding", "gzip")
	srv.ServeHTTP(rec, req)
	if rec.Header().Get("Content-Encoding") != "" {
		t.Fatal("event streams must not be compressed")
	}
}

func TestSituationBucketStable(t *testing.T) {
	a := situation{"room": {"heater", "bathroom"}, "medium": {"water"}}
	b := situation{"medium": {"water"}, "room": {"bathroom", "heater"}}
	if a.bucket() != b.bucket() || normQ("How often?  water ") != normQ("how often water") {
		t.Fatal("cache keys must not depend on order, case or punctuation")
	}
}

type firstWrite struct {
	*httptest.ResponseRecorder
	first time.Duration
	start time.Time
}

func (f *firstWrite) Write(b []byte) (int, error) {
	if f.first == 0 {
		f.first = time.Since(f.start)
	}
	return f.ResponseRecorder.Write(b)
}
func (f *firstWrite) Flush() {}

func TestAskStream(t *testing.T) {
	b := realBrain(t)
	theBrain = b
	s := &Server{cfg: Config{ContentDir: b.dir}, log: slog.New(slog.NewTextHandler(io.Discard, nil))}
	req := httptest.NewRequest("POST", "/v1/brain/ask", strings.NewReader(`{"q":"how often should I water it?","lang":"en","medium":"water","lat":-23.5,"lon":-46.6}`))
	req.Header.Set("Accept", "text/event-stream")
	rec := &firstWrite{ResponseRecorder: httptest.NewRecorder(), start: time.Now()}
	s.brainAsk(rec, req)
	out := rec.Body.String()
	if rec.first > 300*time.Millisecond || !strings.Contains(out, "event: answer") || !strings.Contains(out, "event: done") || !strings.Contains(out, `"water-culture"`) {
		t.Fatalf("first event after %v:\n%s", rec.first, out[:min(600, len(out))])
	}
	t.Logf("first event after %v", rec.first)
}

func TestGzipRequestBody(t *testing.T) {
	s := &Server{limiter: NewLimiter(), log: slog.New(slog.NewTextHandler(io.Discard, nil))}
	var got string
	h := s.wrap(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		got = string(b)
		if r.Header.Get("Content-Encoding") != "" || r.ContentLength != -1 {
			t.Error("header or length not reset")
		}
	}))
	var zb bytes.Buffer
	zw := gzip.NewWriter(&zb)
	zw.Write([]byte(`{"q":"hello"}`))
	zw.Close()
	req := httptest.NewRequest("POST", "/v1/brain/ask", &zb)
	req.Header.Set("Content-Encoding", "gzip")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if got != `{"q":"hello"}` || rec.Header().Get("Accept-Encoding") != "gzip" {
		t.Fatalf("body %q, Accept-Encoding %q", got, rec.Header().Get("Accept-Encoding"))
	}
	req = httptest.NewRequest("POST", "/v1/brain/ask", strings.NewReader("not gzip"))
	req.Header.Set("Content-Encoding", "gzip")
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	if rec.Code != 400 {
		t.Fatalf("bad gzip: %d", rec.Code)
	}
}

func TestShotsAndTips(t *testing.T) {
	if _, err := shots("", nil); err == nil {
		t.Fatal("no photo accepted")
	}
	if _, err := shots("", []shot{{webp900, "selfie"}}); err == nil {
		t.Fatal("unknown kind accepted")
	}
	many := make([]shot, 9)
	for i := range many {
		many[i] = shot{webp900, "leaf"}
	}
	if _, err := shots("", many); err == nil {
		t.Fatal("9 photos accepted")
	}
	ss, err := shots(webp900, []shot{{webp900, "pot"}})
	if err != nil || len(ss) != 2 || ss[0].Kind != "whole" || pick(ss, "pot", "soil") != 1 {
		t.Fatal(err, kindsOf(ss))
	}
	if tips := photoTips("en", 0.9, nil, "leaf"); len(tips) != 0 {
		t.Fatal("tips when confident")
	}
	tips := photoTips("en", 0.4, []string{"leaf"}, "leaf", "underside", "soil", "stem")
	if len(tips) != 2 || tips[0].Kind != "underside" || !strings.Contains(tips[0].Why, "mites") {
		t.Fatal(tips)
	}
}
