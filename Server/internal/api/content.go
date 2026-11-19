package api

import (
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Content is everything the app knows that isn't the user's: species, plant knowledge, translations,
// Erty, icons, artwork. It is published as a pack (Server/content/publish.py): manifest.json maps
// logical paths to content hashes, blobs live at b/<hash>.<ext> and never change, so clients and
// Cloudflare cache them forever and only the small manifest is revalidated. Public, no auth.

var blobName = regexp.MustCompile(`^[0-9a-f]{32}\.(json|png|jpg|mov|webp)$`)

var blobTypes = map[string]string{
	".json": "application/json", ".png": "image/png", ".jpg": "image/jpeg", ".mov": "video/quicktime", ".webp": "image/webp",
}

func (s *Server) contentManifest(w http.ResponseWriter, r *http.Request) {
	b, err := os.ReadFile(filepath.Join(s.cfg.ContentDir, "manifest.json"))
	if err != nil {
		writeErr(w, http.StatusNotFound, "no_content")
		return
	}
	sum := sha256.Sum256(b)
	etag := `"` + hex.EncodeToString(sum[:8]) + `"`
	h := w.Header()
	h.Set("ETag", etag)
	h.Set("Cache-Control", "public, max-age=300")
	if strings.Contains(r.Header.Get("If-None-Match"), hex.EncodeToString(sum[:8])) { // Cloudflare weakens it to W/"…-br"
		w.WriteHeader(http.StatusNotModified)
		return
	}
	h.Set("Content-Type", "application/json")
	w.Write(b)
}

func (s *Server) contentBlob(w http.ResponseWriter, r *http.Request) {
	name := r.PathValue("name")
	if !blobName.MatchString(name) {
		writeErr(w, http.StatusNotFound, "not_found")
		return
	}
	f, err := os.Open(filepath.Join(s.cfg.ContentDir, "b", name))
	if err != nil {
		writeErr(w, http.StatusNotFound, "not_found")
		return
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		writeErr(w, http.StatusNotFound, "not_found")
		return
	}
	h := w.Header()
	h.Set("Content-Type", blobTypes[filepath.Ext(name)])
	h.Set("Cache-Control", "public, max-age=31536000, immutable")
	h.Set("ETag", `"`+strings.TrimSuffix(name, filepath.Ext(name))+`"`)
	http.ServeContent(w, r, "", st.ModTime(), f)
}
