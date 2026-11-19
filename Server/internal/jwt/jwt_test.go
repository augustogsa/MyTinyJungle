package jwt

import (
	"crypto/ecdsa"
	"crypto/ed25519"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"testing"
	"time"
)

func TestEdDSARoundTrip(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	tok, _ := SignEdDSA(priv, "k1", map[string]any{"sub": "u"})
	if _, err := VerifyEdDSA(tok, map[string]ed25519.PublicKey{"k1": pub}); err != nil {
		t.Fatal(err)
	}
	if _, err := VerifyEdDSA(tok, map[string]ed25519.PublicKey{"k2": pub}); err == nil {
		t.Fatal("unknown kid accepted")
	}
	if _, err := VerifyEdDSA(tampered(tok), map[string]ed25519.PublicKey{"k1": pub}); err == nil {
		t.Fatal("tampered accepted")
	}
}

func TestRS256(t *testing.T) {
	k, _ := rsa.GenerateKey(rand.Reader, 2048)
	hb, _ := json.Marshal(Header{Alg: "RS256", Kid: "a"})
	in := b64.EncodeToString(hb) + "." + b64.EncodeToString([]byte(`{"sub":"x"}`))
	sum := sha256.Sum256([]byte(in))
	sig, _ := rsa.SignPKCS1v15(rand.Reader, k, 5, sum[:]) // crypto.SHA256 == 5
	tok := in + "." + b64.EncodeToString(sig)
	if _, err := VerifyRS256(tok, func(string) (*rsa.PublicKey, error) { return &k.PublicKey, nil }); err != nil {
		t.Fatal(err)
	}
}

func TestStdCheck(t *testing.T) {
	now := time.Now()
	s := Std{Iss: "i", Aud: json.RawMessage(`["a","b"]`), Exp: now.Add(time.Minute).Unix()}
	if s.Check([]string{"i"}, []string{"b"}, now) != nil {
		t.Fatal("valid rejected")
	}
	if s.Check([]string{"i"}, []string{"c"}, now) == nil || s.Check([]string{"x"}, nil, now) == nil {
		t.Fatal("bad claims accepted")
	}
	if s.Check(nil, nil, now.Add(time.Hour)) != ErrExpired {
		t.Fatal("expired accepted")
	}
}

func TestX5CChain(t *testing.T) {
	leafOID, interOID := asn1.ObjectIdentifier{1, 2, 3, 4}, asn1.ObjectIdentifier{1, 2, 3, 5}
	mk := func(tmpl, parent *x509.Certificate, pub, signer any) *x509.Certificate {
		der, err := x509.CreateCertificate(rand.Reader, tmpl, parent, pub, signer)
		if err != nil {
			t.Fatal(err)
		}
		c, _ := x509.ParseCertificate(der)
		return c
	}
	base := func(n int64, ca bool, ext asn1.ObjectIdentifier) *x509.Certificate {
		c := &x509.Certificate{SerialNumber: big.NewInt(n), Subject: pkix.Name{CommonName: "t"}, NotBefore: time.Now().Add(-time.Hour),
			NotAfter: time.Now().Add(time.Hour), IsCA: ca, BasicConstraintsValid: true,
			KeyUsage: x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature}
		if ext != nil {
			c.ExtraExtensions = []pkix.Extension{{Id: ext, Value: []byte{5, 0}}}
		}
		return c
	}
	rk, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	ik, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	lk, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	root := mk(base(1, true, nil), base(1, true, nil), &rk.PublicKey, rk)
	inter := mk(base(2, true, interOID), root, &ik.PublicKey, rk)
	leaf := mk(base(3, false, leafOID), inter, &lk.PublicKey, ik)
	enc := base64.StdEncoding.EncodeToString
	hb, _ := json.Marshal(Header{Alg: "ES256", X5c: []string{enc(leaf.Raw), enc(inter.Raw), enc(root.Raw)}})
	in := b64.EncodeToString(hb) + "." + b64.EncodeToString([]byte(`{"ok":true}`))
	sum := sha256.Sum256([]byte(in))
	r, s, _ := ecdsa.Sign(rand.Reader, lk, sum[:])
	sig := make([]byte, 64)
	r.FillBytes(sig[:32])
	s.FillBytes(sig[32:])
	tok := in + "." + b64.EncodeToString(sig)
	if _, err := VerifyX5C(tok, root, leafOID.String(), interOID.String(), time.Now()); err != nil {
		t.Fatal(err)
	}
	ok2, _ := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	other := mk(base(9, true, nil), base(9, true, nil), &ok2.PublicKey, ok2)
	if _, err := VerifyX5C(tok, other, leafOID.String(), interOID.String(), time.Now()); err == nil {
		t.Fatal("wrong root accepted")
	}
	if _, err := VerifyX5C(tok, root, "9.9.9", interOID.String(), time.Now()); err == nil {
		t.Fatal("missing marker accepted")
	}
}

func tampered(tok string) string {
	h, _, _, _, _ := Split(tok)
	hb, _ := json.Marshal(h)
	parts := [3]string{}
	copy(parts[:], splitDots(tok))
	_ = hb
	return parts[0] + "." + b64.EncodeToString([]byte(`{"sub":"admin"}`)) + "." + parts[2]
}

func splitDots(s string) []string {
	out, start := []string{}, 0
	for i := range s {
		if s[i] == '.' {
			out = append(out, s[start:i])
			start = i + 1
		}
	}
	return append(out, s[start:])
}
