package api

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	_ "embed"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/simpleappscompany/mytinyjungle/server/internal/jwt"
)

//go:embed AppleRootCA-G3.cer
var appleRootDER []byte

var appleRoot = func() *x509.Certificate {
	c, err := x509.ParseCertificate(appleRootDER)
	if err != nil {
		panic(err)
	}
	return c
}()

const (
	appleLeafOID  = "1.2.840.113635.100.6.11.1"
	appleInterOID = "1.2.840.113635.100.6.2.1"
)

type appleTxn struct {
	OriginalTransactionID string `json:"originalTransactionId"`
	ProductID             string `json:"productId"`
	BundleID              string `json:"bundleId"`
	ExpiresDate           int64  `json:"expiresDate"`
	RevocationDate        int64  `json:"revocationDate"`
	AppAccountToken       string `json:"appAccountToken"`
	Environment           string `json:"environment"`
	SignedDate            int64  `json:"signedDate"`
}

func (s *Server) verifyAppleJWS(token string, v any) error {
	p, err := jwt.VerifyX5C(token, appleRoot, appleLeafOID, appleInterOID, s.now())
	if err != nil {
		return err
	}
	return json.Unmarshal(p, v)
}

func msTime(ms int64) *time.Time {
	if ms == 0 {
		return nil
	}
	t := time.UnixMilli(ms).UTC()
	return &t
}

// upsertAppleTxn maps a verified transaction to an entitlement. uid binds it to an account when the
// transaction carries no appAccountToken (older purchases); a token always wins.
func (s *Server) upsertAppleTxn(ctx context.Context, t appleTxn, uid string, status string) error {
	if t.BundleID != s.cfg.AppleBundleID || t.OriginalTransactionID == "" {
		return bad("wrong_bundle")
	}
	owner := strings.ToLower(t.AppAccountToken)
	if owner == "" {
		owner = uid
	}
	exp := msTime(t.ExpiresDate)
	if status == "" {
		status = "active"
		if t.RevocationDate != 0 {
			status = "revoked"
		} else if exp != nil && exp.Before(s.now()) {
			status = "expired"
		}
	}
	var ownerArg any
	if isUUID(owner) {
		ownerArg = owner
	}
	_, err := s.db.Auth.Exec(ctx, `insert into entitlements (store, original_transaction_id, user_id, product_id, expires_at, status, environment)
		values ('app_store',$1,(select id from users where id = $2),$3,$4,$5,$6)
		on conflict (store, original_transaction_id) do update set user_id = coalesce(excluded.user_id, entitlements.user_id),
		  product_id = excluded.product_id, expires_at = excluded.expires_at, status = excluded.status,
		  environment = excluded.environment, updated_at = now()`,
		t.OriginalTransactionID, ownerArg, t.ProductID, exp, status, t.Environment)
	return err
}

// appleTransaction: the app posts Transaction.jwsRepresentation right after a purchase or restore.
func (s *Server) appleTransaction(w http.ResponseWriter, r *http.Request) {
	var in struct {
		SignedTransaction string `json:"signedTransaction"`
	}
	if err := decode(r, &in); err != nil {
		s.fail(w, r, err)
		return
	}
	var t appleTxn
	if err := s.verifyAppleJWS(in.SignedTransaction, &t); err != nil {
		writeErr(w, http.StatusUnprocessableEntity, "unverified_transaction")
		return
	}
	uid := claimsOf(r).Sub
	if t.AppAccountToken != "" && !strings.EqualFold(t.AppAccountToken, uid) {
		writeErr(w, http.StatusForbidden, "other_account")
		return
	}
	if err := s.upsertAppleTxn(r.Context(), t, uid, ""); err != nil {
		s.fail(w, r, err)
		return
	}
	s.entitlementsFor(w, r)
}

func (s *Server) entitlementsFor(w http.ResponseWriter, r *http.Request) {
	var es []entitlementOut
	err := s.db.AsUser(r.Context(), claimsOf(r).Sub, func(tx pgx.Tx) error {
		var err error
		es, err = activeEntitlements(r, tx)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"plus": len(es) > 0, "entitlements": es})
}

// appleNotification: App Store Server Notifications V2. Unverified payloads are kept (for forensics) but never acted on.
func (s *Server) appleNotification(w http.ResponseWriter, r *http.Request) {
	var in struct {
		SignedPayload string `json:"signedPayload"`
	}
	if err := decode(r, &in); err != nil || in.SignedPayload == "" {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	var n struct {
		NotificationType string `json:"notificationType"`
		Subtype          string `json:"subtype"`
		Data             struct {
			BundleID              string `json:"bundleId"`
			SignedTransactionInfo string `json:"signedTransactionInfo"`
			Status                int    `json:"status"`
		} `json:"data"`
	}
	ctx := r.Context()
	if err := s.verifyAppleJWS(in.SignedPayload, &n); err != nil {
		_, _ = s.db.Auth.Exec(ctx, `insert into store_notifications (store, verified, payload) values ('app_store', false, $1)`,
			map[string]string{"error": err.Error()})
		writeErr(w, http.StatusUnauthorized, "unverified")
		return
	}
	raw, _ := json.Marshal(n)
	_, _ = s.db.Auth.Exec(ctx, `insert into store_notifications (store, notification_type, verified, payload) values ('app_store',$1,true,$2)`,
		n.NotificationType+"/"+n.Subtype, raw)
	if n.Data.SignedTransactionInfo != "" {
		var t appleTxn
		if err := s.verifyAppleJWS(n.Data.SignedTransactionInfo, &t); err == nil {
			status := ""
			switch n.NotificationType {
			case "REFUND", "REVOKE":
				status = "revoked"
			case "EXPIRED", "GRACE_PERIOD_EXPIRED":
				status = "expired"
			case "DID_FAIL_TO_RENEW":
				if n.Subtype == "GRACE_PERIOD" {
					status = "grace"
				}
			}
			if err := s.upsertAppleTxn(ctx, t, "", status); err != nil {
				s.log.Error("apple upsert", "err", err.Error())
			}
		}
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// ---------- Google Play ----------

type playClient struct {
	pkg, saFile string
	mu          sync.Mutex
	token       string
	tokenExp    time.Time
	http        *http.Client
}

func newPlayClient(pkg, sa string) *playClient {
	return &playClient{pkg: pkg, saFile: sa, http: &http.Client{Timeout: 10 * time.Second}}
}

// accessToken: OAuth2 JWT-bearer grant with the service account (androidpublisher scope).
func (p *playClient) accessToken(ctx context.Context) (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.token != "" && time.Until(p.tokenExp) > time.Minute {
		return p.token, nil
	}
	raw, err := os.ReadFile(p.saFile)
	if err != nil {
		return "", err
	}
	var sa struct{ ClientEmail, PrivateKey, TokenURI string }
	var m map[string]string
	if err := json.Unmarshal(raw, &m); err != nil {
		return "", err
	}
	sa.ClientEmail, sa.PrivateKey, sa.TokenURI = m["client_email"], m["private_key"], m["token_uri"]
	blk, _ := pem.Decode([]byte(sa.PrivateKey))
	if blk == nil {
		return "", errors.New("play: bad key")
	}
	k, err := x509.ParsePKCS8PrivateKey(blk.Bytes)
	if err != nil {
		return "", err
	}
	rk, ok := k.(*rsa.PrivateKey)
	if !ok {
		return "", errors.New("play: not rsa")
	}
	now := time.Now()
	enc := base64.RawURLEncoding
	hb, _ := json.Marshal(map[string]string{"alg": "RS256", "typ": "JWT"})
	cb, _ := json.Marshal(map[string]any{"iss": sa.ClientEmail, "scope": "https://www.googleapis.com/auth/androidpublisher",
		"aud": sa.TokenURI, "iat": now.Unix(), "exp": now.Add(time.Hour).Unix()})
	in := enc.EncodeToString(hb) + "." + enc.EncodeToString(cb)
	sum := sha256.Sum256([]byte(in))
	sig, err := rsa.SignPKCS1v15(nil, rk, crypto.SHA256, sum[:])
	if err != nil {
		return "", err
	}
	form := url.Values{"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"}, "assertion": {in + "." + enc.EncodeToString(sig)}}
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, sa.TokenURI, strings.NewReader(form.Encode()))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	res, err := p.http.Do(req)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()
	var tr struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.NewDecoder(res.Body).Decode(&tr); err != nil || tr.AccessToken == "" {
		return "", fmt.Errorf("play: token %d", res.StatusCode)
	}
	p.token, p.tokenExp = tr.AccessToken, now.Add(time.Duration(tr.ExpiresIn)*time.Second)
	return p.token, nil
}

type playSub struct {
	SubscriptionState          string `json:"subscriptionState"`
	LatestOrderID              string `json:"latestOrderId"`
	LinkedPurchaseToken        string `json:"linkedPurchaseToken"`
	ExternalAccountIdentifiers struct {
		ObfuscatedExternalAccountID string `json:"obfuscatedExternalAccountId"`
	} `json:"externalAccountIdentifiers"`
	LineItems []struct {
		ProductID  string    `json:"productId"`
		ExpiryTime time.Time `json:"expiryTime"`
	} `json:"lineItems"`
	TestPurchase *struct{} `json:"testPurchase"`
}

func (p *playClient) subscription(ctx context.Context, token string) (playSub, error) {
	var sub playSub
	at, err := p.accessToken(ctx)
	if err != nil {
		return sub, err
	}
	u := "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" + url.PathEscape(p.pkg) +
		"/purchases/subscriptionsv2/tokens/" + url.PathEscape(token)
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	req.Header.Set("Authorization", "Bearer "+at)
	res, err := p.http.Do(req)
	if err != nil {
		return sub, err
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		return sub, fmt.Errorf("play: subscription %d", res.StatusCode)
	}
	return sub, json.NewDecoder(res.Body).Decode(&sub)
}

func (s *Server) upsertPlay(ctx context.Context, token, uid string) error {
	sub, err := s.play.subscription(ctx, token)
	if err != nil {
		return err
	}
	owner := sub.ExternalAccountIdentifiers.ObfuscatedExternalAccountID
	if owner == "" {
		owner = uid
	}
	if uid != "" && owner != uid {
		return apiError{http.StatusForbidden, "other_account"}
	}
	status := map[string]string{
		"SUBSCRIPTION_STATE_ACTIVE": "active", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD": "grace",
		"SUBSCRIPTION_STATE_CANCELED": "active", // cancelled but paid until expiry
	}[sub.SubscriptionState]
	if status == "" {
		status = "expired"
	}
	var product string
	var exp *time.Time
	for _, li := range sub.LineItems {
		if exp == nil || li.ExpiryTime.After(*exp) {
			e := li.ExpiryTime
			product, exp = li.ProductID, &e
		}
	}
	env := "production"
	if sub.TestPurchase != nil {
		env = "test"
	}
	var ownerArg any
	if isUUID(owner) {
		ownerArg = owner
	}
	_, err = s.db.Auth.Exec(ctx, `insert into entitlements (store, original_transaction_id, user_id, product_id, expires_at, status, environment)
		values ('play',$1,(select id from users where id = $2),$3,$4,$5,$6)
		on conflict (store, original_transaction_id) do update set user_id = coalesce(excluded.user_id, entitlements.user_id),
		  product_id = excluded.product_id, expires_at = excluded.expires_at, status = excluded.status, updated_at = now()`,
		hashHex(token), ownerArg, product, exp, status, env)
	return err
}

func hashHex(s string) string { h := sha256.Sum256([]byte(s)); return fmt.Sprintf("%x", h[:16]) }

func (s *Server) playPurchase(w http.ResponseWriter, r *http.Request) {
	if s.play == nil {
		writeErr(w, http.StatusServiceUnavailable, "play_not_configured")
		return
	}
	var in struct {
		PurchaseToken string `json:"purchaseToken"`
	}
	if err := decode(r, &in); err != nil || len(in.PurchaseToken) < 10 || len(in.PurchaseToken) > 1000 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	if err := s.upsertPlay(r.Context(), in.PurchaseToken, claimsOf(r).Sub); err != nil {
		var ae apiError
		if errors.As(err, &ae) {
			s.fail(w, r, err)
			return
		}
		writeErr(w, http.StatusUnprocessableEntity, "unverified_purchase")
		return
	}
	s.entitlementsFor(w, r)
}

// playRTDN: Pub/Sub push. The OIDC token proves Google sent it, from our configured service account.
func (s *Server) playRTDN(w http.ResponseWriter, r *http.Request) {
	if s.play == nil || s.cfg.PlayRTDNAud == "" {
		writeErr(w, http.StatusServiceUnavailable, "play_not_configured")
		return
	}
	tok, _ := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
	p, err := jwt.VerifyRS256(tok, s.google.Key)
	var c struct {
		jwt.Std
		Email         string `json:"email"`
		EmailVerified bool   `json:"email_verified"`
	}
	if err != nil || json.Unmarshal(p, &c) != nil ||
		c.Check([]string{"https://accounts.google.com", "accounts.google.com"}, []string{s.cfg.PlayRTDNAud}, s.now()) != nil ||
		!c.EmailVerified || c.Email != s.cfg.PlayRTDNEmail {
		writeErr(w, http.StatusUnauthorized, "unverified")
		return
	}
	var push struct {
		Message struct {
			Data string `json:"data"`
		} `json:"message"`
	}
	if err := decode(r, &push); err != nil {
		s.fail(w, r, err)
		return
	}
	data, _ := base64.StdEncoding.DecodeString(push.Message.Data)
	var n struct {
		PackageName              string `json:"packageName"`
		SubscriptionNotification *struct {
			NotificationType int    `json:"notificationType"`
			PurchaseToken    string `json:"purchaseToken"`
		} `json:"subscriptionNotification"`
	}
	if json.Unmarshal(data, &n) != nil {
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true}) // not JSON: ack so Pub/Sub stops retrying
		return
	}
	kind := "other"
	if n.SubscriptionNotification != nil {
		kind = fmt.Sprintf("subscription/%d", n.SubscriptionNotification.NotificationType)
	}
	_, _ = s.db.Auth.Exec(r.Context(), `insert into store_notifications (store, notification_type, verified, payload) values ('play',$1,true,$2)`,
		kind, data)
	if n.PackageName == s.cfg.PlayPackage && n.SubscriptionNotification != nil {
		if err := s.upsertPlay(r.Context(), n.SubscriptionNotification.PurchaseToken, ""); err != nil {
			s.log.Error("play upsert", "err", err.Error())
			writeErr(w, http.StatusInternalServerError, "retry") // Pub/Sub retries
			return
		}
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}
