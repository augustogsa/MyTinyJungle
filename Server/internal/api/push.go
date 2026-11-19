package api

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"sync"
	"time"
)

// pusher wakes other members' devices when a shared jungle changes. Pushes carry no user content:
// iOS gets a silent content-available push (the app syncs and writes its own local notification in
// the user's language); Android gets an FCM data message with the jungle id. Dead tokens are cleared.
type pusher struct {
	cfg  Config
	db   *DB
	log  *slog.Logger
	http *http.Client
	fcm  *playClient
	proj string

	mu    sync.Mutex
	key   *ecdsa.PrivateKey
	jwt   string
	jwtAt time.Time
}

func newPusher(cfg Config, db *DB, log *slog.Logger) *pusher {
	p := &pusher{cfg: cfg, db: db, log: log, http: &http.Client{Timeout: 10 * time.Second}}
	if cfg.FCMSAFile != "" {
		if raw, err := os.ReadFile(cfg.FCMSAFile); err == nil {
			var m map[string]string
			_ = json.Unmarshal(raw, &m)
			p.proj = m["project_id"]
			p.fcm = &playClient{saFile: cfg.FCMSAFile, scope: "https://www.googleapis.com/auth/firebase.messaging", http: p.http}
		}
	}
	return p
}

// jungleChanged notifies every member of the jungle except the author, in the background.
func (p *pusher) jungleChanged(jungleID, author string) {
	if p == nil || p.db == nil || p.db.Admin == nil {
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()
		rows, err := p.db.Admin.Query(ctx, `select d.id, d.platform, d.push_token from devices d
			join jungle_members m on m.user_id = d.user_id
			where m.jungle_id = $1 and d.user_id <> $2 and d.push_token is not null and (m.until is null or m.until > now())`, jungleID, author)
		if err != nil {
			p.log.Error("push query", "err", err)
			return
		}
		type dev struct{ id, platform, token string }
		var devs []dev
		for rows.Next() {
			var d dev
			if rows.Scan(&d.id, &d.platform, &d.token) == nil {
				devs = append(devs, d)
			}
		}
		rows.Close()
		for _, d := range devs {
			var gone bool
			var err error
			if d.platform == "android" {
				gone, err = p.sendFCM(ctx, d.token, jungleID)
			} else {
				gone, err = p.sendAPNs(ctx, d.token, jungleID)
			}
			switch {
			case gone:
				_, _ = p.db.Auth.Exec(ctx, `update devices set push_token = null where id = $1`, d.id)
				p.log.Info("push", "platform", d.platform, "result", "token_gone")
			case err != nil:
				p.log.Warn("push", "platform", d.platform, "err", err)
			default:
				p.log.Info("push", "platform", d.platform, "result", "sent")
			}
		}
	}()
}

func (p *pusher) apnsJWT() (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.jwt != "" && time.Since(p.jwtAt) < 40*time.Minute {
		return p.jwt, nil
	}
	if p.key == nil {
		raw, err := os.ReadFile(p.cfg.APNsKeyFile)
		if err != nil {
			return "", err
		}
		blk, _ := pem.Decode(raw)
		if blk == nil {
			return "", fmt.Errorf("apns: bad key")
		}
		k, err := x509.ParsePKCS8PrivateKey(blk.Bytes)
		if err != nil {
			return "", err
		}
		ek, ok := k.(*ecdsa.PrivateKey)
		if !ok {
			return "", fmt.Errorf("apns: not ec")
		}
		p.key = ek
	}
	enc := base64.RawURLEncoding
	hb, _ := json.Marshal(map[string]string{"alg": "ES256", "kid": p.cfg.APNsKeyID})
	cb, _ := json.Marshal(map[string]any{"iss": p.cfg.APNsTeamID, "iat": time.Now().Unix()})
	in := enc.EncodeToString(hb) + "." + enc.EncodeToString(cb)
	sum := sha256.Sum256([]byte(in))
	r, s, err := ecdsa.Sign(rand.Reader, p.key, sum[:])
	if err != nil {
		return "", err
	}
	sig := make([]byte, 64)
	r.FillBytes(sig[:32])
	s.FillBytes(sig[32:])
	p.jwt, p.jwtAt = in+"."+enc.EncodeToString(sig), time.Now()
	return p.jwt, nil
}

// sendAPNs tries production, then the sandbox (development builds register sandbox tokens).
func (p *pusher) sendAPNs(ctx context.Context, token, jungleID string) (gone bool, err error) {
	if p.cfg.APNsKeyFile == "" {
		return false, nil
	}
	tok, err := p.apnsJWT()
	if err != nil {
		return false, err
	}
	body, _ := json.Marshal(map[string]any{"aps": map[string]any{"content-available": 1}, "jungle": jungleID})
	for _, host := range []string{"api.push.apple.com", "api.sandbox.push.apple.com"} {
		req, _ := http.NewRequestWithContext(ctx, http.MethodPost, "https://"+host+"/3/device/"+token, bytes.NewReader(body))
		req.Header.Set("authorization", "bearer "+tok)
		req.Header.Set("apns-topic", p.cfg.AppleBundleID)
		req.Header.Set("apns-push-type", "background")
		req.Header.Set("apns-priority", "5")
		req.Header.Set("apns-collapse-id", "jungle-"+jungleID)
		res, err := p.http.Do(req)
		if err != nil {
			return false, err
		}
		var reason struct{ Reason string }
		_ = json.NewDecoder(res.Body).Decode(&reason)
		res.Body.Close()
		switch {
		case res.StatusCode == 200:
			return false, nil
		case res.StatusCode == 400 && reason.Reason == "BadDeviceToken":
			continue // maybe a sandbox token
		case res.StatusCode == 410:
			return true, nil
		default:
			return false, fmt.Errorf("apns %d %s", res.StatusCode, reason.Reason)
		}
	}
	return true, nil
}

func (p *pusher) sendFCM(ctx context.Context, token, jungleID string) (gone bool, err error) {
	if p.fcm == nil || p.proj == "" {
		return false, nil
	}
	at, err := p.fcm.accessToken(ctx)
	if err != nil {
		return false, err
	}
	body, _ := json.Marshal(map[string]any{"message": map[string]any{
		"token": token, "data": map[string]string{"jungle": jungleID},
		"android": map[string]any{"priority": "high", "collapse_key": "jungle-" + jungleID},
	}})
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, "https://fcm.googleapis.com/v1/projects/"+p.proj+"/messages:send", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+at)
	req.Header.Set("Content-Type", "application/json")
	res, err := p.http.Do(req)
	if err != nil {
		return false, err
	}
	defer res.Body.Close()
	switch res.StatusCode {
	case 200:
		return false, nil
	case 404:
		return true, nil // UNREGISTERED
	default:
		return false, fmt.Errorf("fcm %d", res.StatusCode)
	}
}
