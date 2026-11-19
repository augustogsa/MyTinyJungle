// Package jwt is a small, dependency-free JWS/JWT implementation covering exactly what the API needs:
// EdDSA (our own tokens), RS256 (Apple/Google/Cloudflare identity tokens) and ES256 with an x5c chain
// (App Store signed payloads).
package jwt

import (
	"crypto"
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"slices"
	"strings"
	"time"
)

var b64 = base64.RawURLEncoding

type Header struct {
	Alg string   `json:"alg"`
	Kid string   `json:"kid,omitempty"`
	Typ string   `json:"typ,omitempty"`
	X5c []string `json:"x5c,omitempty"`
}

var (
	ErrMalformed = errors.New("jwt: malformed")
	ErrSignature = errors.New("jwt: bad signature")
	ErrExpired   = errors.New("jwt: expired")
	ErrClaims    = errors.New("jwt: claims rejected")
)

// Split parses the three parts without verifying anything.
func Split(token string) (h Header, payload []byte, signingInput string, sig []byte, err error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return h, nil, "", nil, ErrMalformed
	}
	hb, err1 := b64.DecodeString(parts[0])
	payload, err2 := b64.DecodeString(parts[1])
	sig, err3 := b64.DecodeString(parts[2])
	if err1 != nil || err2 != nil || err3 != nil || json.Unmarshal(hb, &h) != nil {
		return h, nil, "", nil, ErrMalformed
	}
	return h, payload, parts[0] + "." + parts[1], sig, nil
}

// SignEdDSA produces a compact JWS over claims.
func SignEdDSA(key ed25519.PrivateKey, kid string, claims any) (string, error) {
	hb, _ := json.Marshal(Header{Alg: "EdDSA", Kid: kid, Typ: "JWT"})
	pb, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	in := b64.EncodeToString(hb) + "." + b64.EncodeToString(pb)
	return in + "." + b64.EncodeToString(ed25519.Sign(key, []byte(in))), nil
}

// VerifyEdDSA checks the signature with the key named by kid and returns the payload.
func VerifyEdDSA(token string, keys map[string]ed25519.PublicKey) ([]byte, error) {
	h, p, in, sig, err := Split(token)
	if err != nil {
		return nil, err
	}
	k, ok := keys[h.Kid]
	if h.Alg != "EdDSA" || !ok || !ed25519.Verify(k, []byte(in), sig) {
		return nil, ErrSignature
	}
	return p, nil
}

// VerifyRS256 checks an RS256 token against a key set resolved by kid.
func VerifyRS256(token string, lookup func(kid string) (*rsa.PublicKey, error)) ([]byte, error) {
	h, p, in, sig, err := Split(token)
	if err != nil {
		return nil, err
	}
	if h.Alg != "RS256" {
		return nil, ErrSignature
	}
	k, err := lookup(h.Kid)
	if err != nil {
		return nil, err
	}
	sum := sha256.Sum256([]byte(in))
	if rsa.VerifyPKCS1v15(k, crypto.SHA256, sum[:], sig) != nil {
		return nil, ErrSignature
	}
	return p, nil
}

// VerifyX5C verifies an ES256 JWS whose x5c chain must lead to root, and whose leaf and intermediate
// carry the given marker extension OIDs (Apple's App Store receipt-signing markers). Returns the payload.
func VerifyX5C(token string, root *x509.Certificate, leafOID, interOID string, at time.Time) ([]byte, error) {
	h, p, in, sig, err := Split(token)
	if err != nil {
		return nil, err
	}
	if h.Alg != "ES256" || len(h.X5c) < 2 {
		return nil, ErrSignature
	}
	certs := make([]*x509.Certificate, 0, len(h.X5c))
	for _, c := range h.X5c {
		der, err := base64.StdEncoding.DecodeString(c)
		if err != nil {
			return nil, ErrMalformed
		}
		cert, err := x509.ParseCertificate(der)
		if err != nil {
			return nil, ErrMalformed
		}
		certs = append(certs, cert)
	}
	roots, inters := x509.NewCertPool(), x509.NewCertPool()
	roots.AddCert(root)
	inters.AddCert(certs[1])
	if _, err := certs[0].Verify(x509.VerifyOptions{
		Roots: roots, Intermediates: inters, CurrentTime: at, KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
	}); err != nil {
		return nil, fmt.Errorf("jwt: chain: %w", err)
	}
	if !hasOID(certs[0], leafOID) || !hasOID(certs[1], interOID) {
		return nil, ErrSignature
	}
	pub, ok := certs[0].PublicKey.(*ecdsa.PublicKey)
	if !ok || len(sig) != 64 {
		return nil, ErrSignature
	}
	sum := sha256.Sum256([]byte(in))
	r, s := new(big.Int).SetBytes(sig[:32]), new(big.Int).SetBytes(sig[32:])
	if !ecdsa.Verify(pub, sum[:], r, s) {
		return nil, ErrSignature
	}
	return p, nil
}

func hasOID(c *x509.Certificate, oid string) bool {
	if oid == "" {
		return true
	}
	return slices.ContainsFunc(c.Extensions, func(e pkixExt) bool { return e.Id.String() == oid })
}

// Std are the registered claims we check.
type Std struct {
	Iss string          `json:"iss"`
	Sub string          `json:"sub"`
	Aud json.RawMessage `json:"aud"`
	Exp int64           `json:"exp"`
	Iat int64           `json:"iat"`
}

func (s Std) Audiences() []string {
	var one string
	if json.Unmarshal(s.Aud, &one) == nil {
		return []string{one}
	}
	var many []string
	_ = json.Unmarshal(s.Aud, &many)
	return many
}

// Check validates issuer (any of iss), audience (any overlap, skipped if aud empty) and expiry with 60s leeway.
func (s Std) Check(iss []string, aud []string, now time.Time) error {
	if s.Exp == 0 || now.Unix() > s.Exp+60 {
		return ErrExpired
	}
	if len(iss) > 0 && !slices.Contains(iss, s.Iss) {
		return ErrClaims
	}
	if len(aud) > 0 && !slices.ContainsFunc(s.Audiences(), func(a string) bool { return slices.Contains(aud, a) }) {
		return ErrClaims
	}
	return nil
}
