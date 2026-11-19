package api

import (
	"encoding/json"
	"net/http"
	"net/url"
	"os"
	"strings"
)

// Sign in with Apple on Android: Apple's web flow through our Services ID. The app opens /start in a custom
// tab, Apple posts back to /callback, and we hand the identity token to the app through its own URL scheme.
// Nothing is stored here; the app then signs in with /v1/auth/signin as usual (nonce checked there).

const appleCallback = "https://api.mytinyjungle.com/v1/auth/apple/callback"

func appleServicesID() string {
	if v := os.Getenv("MTJ_APPLE_SERVICES_ID"); v != "" {
		return v
	}
	return "com.simpleappscompany.mytinyjungle.signin"
}

func (s *Server) appleStart(w http.ResponseWriter, r *http.Request) {
	st, n := r.URL.Query().Get("state"), r.URL.Query().Get("nonce")
	if len(st) < 8 || len(st) > 128 || len(n) < 8 || len(n) > 128 {
		writeErr(w, http.StatusBadRequest, "invalid_request")
		return
	}
	q := url.Values{"client_id": {appleServicesID()}, "redirect_uri": {appleCallback}, "response_type": {"code id_token"},
		"response_mode": {"form_post"}, "scope": {"name email"}, "state": {st}, "nonce": {n}}
	http.Redirect(w, r, "https://appleid.apple.com/auth/authorize?"+strings.ReplaceAll(q.Encode(), "+", "%20"), http.StatusFound)
}

func (s *Server) appleCallback(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 64<<10)
	if r.ParseForm() != nil {
		writeErr(w, http.StatusBadRequest, "invalid_request")
		return
	}
	frag := url.Values{"state": {r.PostForm.Get("state")}}
	if e := r.PostForm.Get("error"); e != "" {
		frag.Set("error", e) // e.g. user_cancelled_authorize
	} else {
		frag.Set("id_token", r.PostForm.Get("id_token"))
		var u struct {
			Name struct{ FirstName, LastName string } `json:"name"`
		}
		if json.Unmarshal([]byte(r.PostForm.Get("user")), &u) == nil {
			frag.Set("name", strings.TrimSpace(u.Name.FirstName+" "+u.Name.LastName))
		} else {
			frag.Set("name", "")
		}
	}
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Referrer-Policy", "no-referrer")
	w.Header().Set("Location", "com.simpleappscompany.mytinyjungle:/auth/apple#"+strings.ReplaceAll(frag.Encode(), "+", "%20"))
	w.WriteHeader(http.StatusFound)
}
