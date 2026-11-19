package api

import (
	"crypto/ed25519"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type Config struct {
	Socket         string // unix socket path; empty → Addr
	Addr           string
	AuthDSN        string
	AppDSN         string
	AdminDSN       string
	Issuer         string
	AccessTTL      time.Duration
	RefreshTTL     time.Duration
	KeysDir        string // <kid>.key files, 32-byte ed25519 seeds in hex
	SigningKid     string
	AppleAud       []string
	GoogleAud      []string
	AccessTeam     string // Cloudflare Access team domain, e.g. simpleapps.cloudflareaccess.com
	AccessAud      string // Access application AUD tag
	AdminEmails    []string
	MediaDir       string
	MediaKey       []byte // 32 bytes
	AppleBundleID  string
	PlayPackage    string
	PlaySAFile     string
	PlayRTDNAud    string
	PlayRTDNEmail  string
	Release        string
	SocketGroupGID int
}

func env(k, d string) string {
	if v, ok := os.LookupEnv(k); ok && v != "" {
		return v
	}
	return d
}

func list(k string) []string {
	var out []string
	for _, s := range strings.Split(os.Getenv(k), ",") {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}

func LoadConfig() (Config, error) {
	c := Config{
		Socket:        env("MTJ_SOCKET", ""),
		Addr:          env("MTJ_ADDR", "127.0.0.1:3300"),
		AuthDSN:       os.Getenv("MTJ_AUTH_DSN"),
		AppDSN:        os.Getenv("MTJ_APP_DSN"),
		AdminDSN:      os.Getenv("MTJ_ADMIN_DSN"),
		Issuer:        "https://api.mytinyjungle.com",
		AccessTTL:     30 * time.Minute,
		RefreshTTL:    90 * 24 * time.Hour,
		KeysDir:       env("MTJ_KEYS_DIR", "/opt/mtj/secrets/keys"),
		SigningKid:    os.Getenv("MTJ_SIGNING_KID"),
		AppleAud:      list("MTJ_APPLE_AUDIENCES"),
		GoogleAud:     list("MTJ_GOOGLE_AUDIENCES"),
		AccessTeam:    os.Getenv("MTJ_ACCESS_TEAM"),
		AccessAud:     os.Getenv("MTJ_ACCESS_AUD"),
		AdminEmails:   list("MTJ_ADMIN_EMAILS"),
		MediaDir:      env("MTJ_MEDIA_DIR", "/var/lib/mtj/media"),
		AppleBundleID: env("MTJ_APPLE_BUNDLE_ID", "com.simpleappscompany.mytinyjungle"),
		PlayPackage:   os.Getenv("MTJ_PLAY_PACKAGE"),
		PlaySAFile:    os.Getenv("MTJ_PLAY_SA_FILE"),
		PlayRTDNAud:   os.Getenv("MTJ_PLAY_RTDN_AUDIENCE"),
		PlayRTDNEmail: os.Getenv("MTJ_PLAY_RTDN_EMAIL"),
		Release:       env("MTJ_RELEASE", "dev"),
	}
	if mk := os.Getenv("MTJ_MEDIA_KEY"); mk != "" {
		b, err := hex.DecodeString(mk)
		if err != nil || len(b) != 32 {
			return c, fmt.Errorf("MTJ_MEDIA_KEY must be 64 hex chars")
		}
		c.MediaKey = b
	}
	if c.AuthDSN == "" || c.AppDSN == "" || c.AdminDSN == "" || c.SigningKid == "" || len(c.MediaKey) == 0 {
		return c, fmt.Errorf("missing MTJ_AUTH_DSN / MTJ_APP_DSN / MTJ_ADMIN_DSN / MTJ_SIGNING_KID / MTJ_MEDIA_KEY")
	}
	return c, nil
}

// LoadKeys reads every <kid>.key in dir. The signing kid must be among them; the others stay valid for
// verification so tokens survive a rotation.
func LoadKeys(dir, signing string) (ed25519.PrivateKey, map[string]ed25519.PublicKey, error) {
	files, err := filepath.Glob(filepath.Join(dir, "*.key"))
	if err != nil {
		return nil, nil, err
	}
	pubs := map[string]ed25519.PublicKey{}
	var priv ed25519.PrivateKey
	for _, f := range files {
		raw, err := os.ReadFile(f)
		if err != nil {
			return nil, nil, err
		}
		seed, err := hex.DecodeString(strings.TrimSpace(string(raw)))
		if err != nil || len(seed) != ed25519.SeedSize {
			return nil, nil, fmt.Errorf("bad key %s", f)
		}
		k := ed25519.NewKeyFromSeed(seed)
		kid := strings.TrimSuffix(filepath.Base(f), ".key")
		pubs[kid] = k.Public().(ed25519.PublicKey)
		if kid == signing {
			priv = k
		}
	}
	if priv == nil {
		return nil, nil, fmt.Errorf("signing key %q not found in %s", signing, dir)
	}
	return priv, pubs, nil
}
