package jwt

import (
	"context"
	"crypto/rsa"
	"encoding/json"
	"errors"
	"math/big"
	"net/http"
	"sync"
	"time"
)

// JWKS fetches and caches an RSA key set, refetching at most once a minute on an unknown kid.
type JWKS struct {
	URL     string
	mu      sync.Mutex
	keys    map[string]*rsa.PublicKey
	fetched time.Time
	client  *http.Client
}

func NewJWKS(url string) *JWKS {
	return &JWKS{URL: url, client: &http.Client{Timeout: 8 * time.Second}}
}

func (j *JWKS) Key(kid string) (*rsa.PublicKey, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if k, ok := j.keys[kid]; ok && time.Since(j.fetched) < 6*time.Hour {
		return k, nil
	}
	if time.Since(j.fetched) > time.Minute || j.keys == nil {
		if err := j.refresh(); err != nil && j.keys == nil {
			return nil, err
		}
	}
	if k, ok := j.keys[kid]; ok {
		return k, nil
	}
	return nil, errors.New("jwks: unknown kid")
}

func (j *JWKS) refresh() error {
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, j.URL, nil)
	res, err := j.client.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	var set struct {
		Keys []struct{ Kid, Kty, N, E string } `json:"keys"`
	}
	if err := json.NewDecoder(res.Body).Decode(&set); err != nil {
		return err
	}
	keys := map[string]*rsa.PublicKey{}
	for _, k := range set.Keys {
		if k.Kty != "RSA" {
			continue
		}
		n, err1 := b64.DecodeString(k.N)
		e, err2 := b64.DecodeString(k.E)
		if err1 != nil || err2 != nil {
			continue
		}
		keys[k.Kid] = &rsa.PublicKey{N: new(big.Int).SetBytes(n), E: int(new(big.Int).SetBytes(e).Int64())}
	}
	j.keys, j.fetched = keys, time.Now()
	return nil
}
