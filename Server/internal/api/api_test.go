package api

import (
	"crypto/ed25519"
	"crypto/rand"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func testServer(t *testing.T) *Server {
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	cfg := Config{Issuer: "https://api.mytinyjungle.com", AccessTTL: time.Minute, SigningKid: "k1", MediaKey: make([]byte, 32)}
	return New(cfg, &DB{}, priv, map[string]ed25519.PublicKey{"k1": pub}, slog.New(slog.DiscardHandler))
}

func TestStale(t *testing.T) {
	now := time.Now()
	v := int64(5)
	if stale(&v, 5, now, now.Add(-time.Hour)) {
		t.Fatal("same base version must win")
	}
	if !stale(nil, 5, now, now.Add(-time.Hour)) {
		t.Fatal("older blind write must lose")
	}
	if stale(nil, 5, now, now.Add(time.Second)) {
		t.Fatal("newer write must win")
	}
}

func TestSealOpen(t *testing.T) {
	k := make([]byte, 32)
	_, _ = rand.Read(k)
	c, _ := seal(k, "j/a", []byte("leaf"))
	if p, err := open(k, "j/a", c); err != nil || string(p) != "leaf" {
		t.Fatal("round trip failed")
	}
	if _, err := open(k, "j/b", c); err == nil {
		t.Fatal("swapped path accepted")
	}
}

func TestLimiter(t *testing.T) {
	l := NewLimiter()
	for i := 0; i < 3; i++ {
		if !l.Allow("a", 3) {
			t.Fatal("under limit refused")
		}
	}
	if l.Allow("a", 3) || !l.Allow("b", 3) {
		t.Fatal("limit not per key")
	}
}

func TestAuthGate(t *testing.T) {
	s := testServer(t)
	h := s.Handler()
	for _, p := range []string{"/v1/me", "/v1/sync/pull", "/v1/jungles"} {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest("GET", p, nil))
		if rec.Code != 401 {
			t.Fatalf("%s -> %d", p, rec.Code)
		}
	}
	// A valid token passes the gate (handler then needs the DB, so only check it is not 401).
	tok, _ := s.issueAccess("11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222")
	called := false
	gate := s.user(func(w http.ResponseWriter, r *http.Request) { called = claimsOf(r).Sub != "" })
	req := httptest.NewRequest("GET", "/x", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	gate.ServeHTTP(httptest.NewRecorder(), req)
	if !called {
		t.Fatal("valid token rejected")
	}
	// Token signed by another key is rejected.
	_, other, _ := ed25519.GenerateKey(rand.Reader)
	s2 := testServer(t)
	s2.priv = other
	bad, _ := s2.issueAccess("11111111-1111-4111-8111-111111111111", "d")
	req.Header.Set("Authorization", "Bearer "+bad)
	rec := httptest.NewRecorder()
	gate.ServeHTTP(rec, req)
	if rec.Code != 401 {
		t.Fatal("foreign token accepted")
	}
}

func TestAdminClosedWithoutAccess(t *testing.T) {
	h := testServer(t).Handler()
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest("GET", "/v1/admin/stats", nil))
	if rec.Code == 200 {
		t.Fatal("admin open")
	}
}

func TestDecodeRejectsUnknownFields(t *testing.T) {
	r := httptest.NewRequest("POST", "/", strings.NewReader(`{"a":1,"evil":2}`))
	var v struct{ A int }
	if decode(r, &v) == nil {
		t.Fatal("unknown field accepted")
	}
}

func TestSecurityHeaders(t *testing.T) {
	rec := httptest.NewRecorder()
	testServer(t).Handler().ServeHTTP(rec, httptest.NewRequest("GET", "/v1/me", nil))
	if rec.Header().Get("X-Content-Type-Options") != "nosniff" || rec.Header().Get("Cache-Control") != "no-store" {
		t.Fatal("headers missing")
	}
}

func TestAppleRootPinned(t *testing.T) {
	if appleRoot.Subject.CommonName != "Apple Root CA - G3" {
		t.Fatal(appleRoot.Subject.CommonName)
	}
}

func TestContent(t *testing.T) {
	s := testServer(t)
	dir := t.TempDir()
	s.cfg.ContentDir = dir
	_ = os.MkdirAll(dir+"/b", 0o755)
	_ = os.WriteFile(dir+"/manifest.json", []byte(`{"v":1}`), 0o644)
	_ = os.WriteFile(dir+"/b/0123456789abcdef0123456789abcdef.png", []byte("png"), 0o644)
	h := s.Handler()
	do := func(path, inm string) *httptest.ResponseRecorder {
		r := httptest.NewRequest("GET", path, nil)
		if inm != "" {
			r.Header.Set("If-None-Match", inm)
		}
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		return w
	}
	m := do("/v1/content/manifest", "")
	if m.Code != 200 || m.Body.String() != `{"v":1}` || m.Header().Get("ETag") == "" {
		t.Fatalf("manifest %d", m.Code)
	}
	if do("/v1/content/manifest", m.Header().Get("ETag")).Code != 304 {
		t.Fatal("etag not honoured")
	}
	b := do("/v1/content/b/0123456789abcdef0123456789abcdef.png", "")
	if b.Code != 200 || !strings.Contains(b.Header().Get("Cache-Control"), "immutable") || b.Header().Get("Content-Type") != "image/png" {
		t.Fatalf("blob %d %v", b.Code, b.Header())
	}
	for _, bad := range []string{"../manifest.json", "x.png", "0123456789abcdef0123456789abcdef.sh"} {
		if do("/v1/content/b/"+bad, "").Code == 200 {
			t.Fatal("served " + bad)
		}
	}
}

func TestCBORAndAttestRejects(t *testing.T) {
	// {"fmt": "none"} as CBOR.
	v, rest, err := cborDecode([]byte{0xa1, 0x63, 'f', 'm', 't', 0x64, 'n', 'o', 'n', 'e'}, 0)
	if err != nil || len(rest) != 0 || v.(map[any]any)["fmt"] != "none" {
		t.Fatalf("cbor: %v %v", v, err)
	}
	if _, err := verifyAppAttest([]byte{0xa1, 0x63, 'f', 'm', 't', 0x64, 'n', 'o', 'n', 'e'}, make([]byte, 32), []byte("c"), time.Now()); err == nil {
		t.Fatal("accepted a non-Apple attestation")
	}
	if _, _, err := cborDecode([]byte{0x5b, 0xff}, 0); err == nil {
		t.Fatal("accepted truncated cbor")
	}
}

func TestBrainMatchesKnowledge(t *testing.T) {
	dir := t.TempDir()
	kb := `{"symptoms":[{"id":"yellow-lower","name":"Yellow lower leaves","looks":"Older leaves near the base turn yellow.","causes":["Too much water"],"fixes":["Water less."],"keywords":["yellow","bottom leaves"]}],
"pests":[{"id":"spider-mites","name":"Spider mites","signs":"Fine webbing, dusty speckled leaves.","fix":"Shower the plant. Repeat weekly."}]}`
	loc := `{"text":{"Spider mites":"Ácaros","Shower the plant.":"Dale una ducha."}}`
	os.MkdirAll(filepath.Join(dir, "b"), 0o755)
	os.WriteFile(filepath.Join(dir, "b", "k.json"), []byte(kb), 0o644)
	os.WriteFile(filepath.Join(dir, "b", "l.json"), []byte(loc), 0o644)
	os.WriteFile(filepath.Join(dir, "manifest.json"), []byte(`{"files":{"data/knowledge.json":{"h":"k.json"},"data/locales/es.json":{"h":"l.json"}}}`), 0o644)
	b := &brain{dir: dir}
	ms := b.rank("there is fine webbing under the leaves and they look dusty", "no yellow leaves, healthy", nil)
	if len(ms) == 0 || ms[0].e.ID != "spider-mites" {
		t.Fatalf("rank: %+v", ms)
	}
	d := b.answerFrom(ms[0], "es")
	if d.Problem != "Ácaros" || d.Steps[0] != "Dale una ducha." || !d.Urgent {
		t.Fatalf("answer: %+v", d)
	}
}
