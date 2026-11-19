package api

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"slices"

	"github.com/jackc/pgx/v5"
)

const maxMedia = 12 << 20

var mediaTypes = []string{"image/jpeg", "image/heic", "image/png", "image/webp"}

// seal encrypts with AES-256-GCM; the object path is bound as associated data so files can't be swapped.
func seal(key []byte, aad string, plain []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, _ := cipher.NewGCM(block)
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, err
	}
	return gcm.Seal(nonce, nonce, plain, []byte(aad)), nil
}

func open(key []byte, aad string, sealed []byte) ([]byte, error) {
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, _ := cipher.NewGCM(block)
	if len(sealed) < gcm.NonceSize() {
		return nil, errors.New("short")
	}
	return gcm.Open(nil, sealed[:gcm.NonceSize()], sealed[gcm.NonceSize():], []byte(aad))
}

func (s *Server) mediaPath(jungle, id string) (string, string) {
	return filepath.Join(s.cfg.MediaDir, jungle, id), jungle + "/" + id
}

func (s *Server) putMedia(w http.ResponseWriter, r *http.Request) {
	jungle, id := r.PathValue("jungle"), r.PathValue("id")
	ct := r.Header.Get("Content-Type")
	if !isUUID(jungle) || !isUUID(id) || !slices.Contains(mediaTypes, ct) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxMedia))
	if err != nil {
		s.fail(w, r, err)
		return
	}
	ctx, c := r.Context(), claimsOf(r)
	path, aad := s.mediaPath(jungle, id)
	err = s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		// RLS rejects the insert unless the user can reach the jungle.
		if _, err := tx.Exec(ctx, `insert into media (jungle_id, id, content_type, bytes, created_by) values ($1,$2,$3,$4,$5)
			on conflict (jungle_id, id) do update set content_type = excluded.content_type, bytes = excluded.bytes`,
			jungle, id, ct, len(body), c.Sub); err != nil {
			return apiError{http.StatusForbidden, "forbidden"}
		}
		sealed, err := seal(s.cfg.MediaKey, aad, body)
		if err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
			return err
		}
		tmp := path + ".tmp"
		if err := os.WriteFile(tmp, sealed, 0o600); err != nil {
			return err
		}
		return os.Rename(tmp, path)
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"ok": true, "bytes": len(body)})
}

func (s *Server) getMedia(w http.ResponseWriter, r *http.Request) {
	jungle, id := r.PathValue("jungle"), r.PathValue("id")
	if !isUUID(jungle) || !isUUID(id) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx, c := r.Context(), claimsOf(r)
	var ct string
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select content_type from media where jungle_id = $1 and id = $2`, jungle, id).Scan(&ct)
	})
	if isNoRows(err) {
		writeErr(w, http.StatusNotFound, "not_found")
		return
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	path, aad := s.mediaPath(jungle, id)
	sealed, err := os.ReadFile(path)
	if err != nil {
		writeErr(w, http.StatusNotFound, "not_found")
		return
	}
	plain, err := open(s.cfg.MediaKey, aad, sealed)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	w.Header().Set("Content-Type", ct)
	w.Header().Set("Cache-Control", "private, max-age=86400, immutable")
	_, _ = w.Write(plain)
}

func (s *Server) deleteMedia(w http.ResponseWriter, r *http.Request) {
	jungle, id := r.PathValue("jungle"), r.PathValue("id")
	ctx, c := r.Context(), claimsOf(r)
	if !isUUID(jungle) || !isUUID(id) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from media where jungle_id = $1 and id = $2`, jungle, id)
		if err == nil && tag.RowsAffected() == 0 {
			return apiError{http.StatusNotFound, "not_found"}
		}
		if err == nil {
			path, _ := s.mediaPath(jungle, id)
			_ = os.Remove(path)
		}
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
