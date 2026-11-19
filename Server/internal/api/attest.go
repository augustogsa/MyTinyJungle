package api

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	_ "embed"
	"encoding/asn1"
	"encoding/base64"
	"encoding/binary"
	"errors"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
)

// App Attest: the iPhone proves the app is the genuine signed build on a real device. The server hands
// out a one-time challenge, the device attests a Secure Enclave key, and we verify Apple's certificate
// chain, the nonce, the app ID and the key ID before marking the device attested.

//go:embed AppleAppAttestRootCA.pem
var appAttestRootPEM []byte

const appAttestAppID = "JKMB58P38J.com.simpleappscompany.mytinyjungle"

var oidAppAttestNonce = asn1.ObjectIdentifier{1, 2, 840, 113635, 100, 8, 2}

func (s *Server) attestChallenge(w http.ResponseWriter, r *http.Request) {
	c := claimsOf(r)
	ch := make([]byte, 32)
	rand.Read(ch)
	err := s.db.AsUser(r.Context(), c.Sub, func(tx pgx.Tx) error {
		_, err := tx.Exec(r.Context(), `update devices set attest_challenge = $1, attest_challenge_at = now() where id = $2`, ch, c.Dev)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"challenge": base64.StdEncoding.EncodeToString(ch)})
}

func (s *Server) attest(w http.ResponseWriter, r *http.Request) {
	var in struct{ KeyID, Attestation string }
	if decode(r, &in) != nil {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	keyID, e1 := base64.StdEncoding.DecodeString(in.KeyID)
	att, e2 := base64.StdEncoding.DecodeString(in.Attestation)
	if e1 != nil || e2 != nil || len(keyID) != 32 || len(att) > 16<<10 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	ctx, c := r.Context(), claimsOf(r)
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		var ch []byte
		var at *time.Time
		if err := tx.QueryRow(ctx, `select attest_challenge, attest_challenge_at from devices where id = $1 for update`, c.Dev).Scan(&ch, &at); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update devices set attest_challenge = null where id = $1`, c.Dev); err != nil {
			return err
		}
		if len(ch) == 0 || at == nil || time.Since(*at) > 5*time.Minute {
			return bad("challenge_expired")
		}
		pub, err := verifyAppAttest(att, keyID, ch, time.Now())
		if err != nil {
			return bad("attestation_invalid")
		}
		_, err = tx.Exec(ctx, `update devices set attest_key_id = $1, attest_pubkey = $2, attest_counter = 0, attested_at = now() where id = $3`, keyID, pub, c.Dev)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// verifyAppAttest checks an attestation object and returns the attested public key (uncompressed point).
func verifyAppAttest(att, keyID, challenge []byte, now time.Time) ([]byte, error) {
	v, _, err := cborDecode(att, 0)
	if err != nil {
		return nil, err
	}
	m, ok := v.(map[any]any)
	if !ok || m["fmt"] != "apple-appattest" {
		return nil, errors.New("fmt")
	}
	stmt, _ := m["attStmt"].(map[any]any)
	authData, _ := m["authData"].([]byte)
	x5c, _ := stmt["x5c"].([]any)
	if len(x5c) < 2 || len(authData) < 55 {
		return nil, errors.New("shape")
	}
	certs := make([]*x509.Certificate, len(x5c))
	for i, raw := range x5c {
		b, _ := raw.([]byte)
		if certs[i], err = x509.ParseCertificate(b); err != nil {
			return nil, err
		}
	}
	roots, inter := x509.NewCertPool(), x509.NewCertPool()
	roots.AppendCertsFromPEM(appAttestRootPEM)
	for _, c := range certs[1:] {
		inter.AddCert(c)
	}
	if _, err := certs[0].Verify(x509.VerifyOptions{Roots: roots, Intermediates: inter, CurrentTime: now, KeyUsages: []x509.ExtKeyUsage{x509.ExtKeyUsageAny}}); err != nil {
		return nil, err
	}
	// Nonce = SHA256(authData || SHA256(challenge)), carried in the leaf's extension.
	ch := sha256.Sum256(challenge)
	nonce := sha256.Sum256(append(append([]byte{}, authData...), ch[:]...))
	var got []byte
	for _, ext := range certs[0].Extensions {
		if ext.Id.Equal(oidAppAttestNonce) {
			var seq struct {
				N asn1.RawValue `asn1:"tag:1,explicit"`
			}
			if _, err := asn1.Unmarshal(ext.Value, &seq); err == nil {
				got = seq.N.Bytes
			}
		}
	}
	if !bytes.Equal(got, nonce[:]) {
		return nil, errors.New("nonce")
	}
	pk, ok := certs[0].PublicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, errors.New("key")
	}
	point := elliptic.Marshal(elliptic.P256(), pk.X, pk.Y) //nolint:staticcheck // App Attest defines the key ID over this encoding
	if h := sha256.Sum256(point); !bytes.Equal(h[:], keyID) {
		return nil, errors.New("key id")
	}
	app := sha256.Sum256([]byte(appAttestAppID))
	aaguid := string(authData[37:53])
	n := int(binary.BigEndian.Uint16(authData[53:55]))
	if !bytes.Equal(authData[:32], app[:]) || binary.BigEndian.Uint32(authData[33:37]) != 0 ||
		(aaguid != "appattestdevelop" && aaguid != "appattest\x00\x00\x00\x00\x00\x00\x00") ||
		len(authData) < 55+n || !bytes.Equal(authData[55:55+n], keyID) {
		return nil, errors.New("authData")
	}
	return point, nil
}

// cborDecode reads the definite-length subset of CBOR that attestation objects use.
func cborDecode(b []byte, depth int) (any, []byte, error) {
	if len(b) == 0 || depth > 16 {
		return nil, nil, errors.New("cbor")
	}
	major, info := b[0]>>5, b[0]&31
	b = b[1:]
	var n uint64
	switch {
	case info < 24:
		n = uint64(info)
	case info <= 27:
		k := 1 << (info - 24)
		if len(b) < k {
			return nil, nil, errors.New("cbor")
		}
		for _, x := range b[:k] {
			n = n<<8 | uint64(x)
		}
		b = b[k:]
	default:
		return nil, nil, errors.New("cbor")
	}
	switch major {
	case 0:
		return n, b, nil
	case 2, 3:
		if uint64(len(b)) < n {
			return nil, nil, errors.New("cbor")
		}
		if major == 3 {
			return string(b[:n]), b[n:], nil
		}
		return b[:n], b[n:], nil
	case 4:
		if n > 64 {
			return nil, nil, errors.New("cbor")
		}
		out := make([]any, n)
		for i := range out {
			var err error
			if out[i], b, err = cborDecode(b, depth+1); err != nil {
				return nil, nil, err
			}
		}
		return out, b, nil
	case 5:
		if n > 64 {
			return nil, nil, errors.New("cbor")
		}
		out := make(map[any]any, n)
		for range n {
			k, rest, err := cborDecode(b, depth+1)
			if err != nil {
				return nil, nil, err
			}
			v, rest, err := cborDecode(rest, depth+1)
			if err != nil {
				return nil, nil, err
			}
			if _, ok := k.([]byte); ok {
				return nil, nil, errors.New("cbor")
			}
			out[k], b = v, rest
		}
		return out, b, nil
	}
	return nil, nil, errors.New("cbor")
}
