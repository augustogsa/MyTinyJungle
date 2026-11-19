package api

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"image"
	"image/jpeg"
	"sync"
	"time"

	_ "golang.org/x/image/webp"
)

// Photos: the apps send JPEG or WebP, longest side up to 768 px (bigger is scaled down here). The models get
// JPEG ≤ 768 px. Every inference result is cached by the photo's sha256 so identify, scene, care-plan and
// diagnose on the same photo run each model once.

const photoSide = 768

// normPhoto validates a base64 JPEG/WebP and returns base64 JPEG ≤ 768 px (the input itself when it already is).
func normPhoto(b64 string) (string, error) {
	raw, err := base64.StdEncoding.DecodeString(b64)
	if err != nil || len(raw) < 12 {
		return "", bad("invalid_photo")
	}
	isJPEG := raw[0] == 0xFF && raw[1] == 0xD8
	isWebP := string(raw[0:4]) == "RIFF" && string(raw[8:12]) == "WEBP"
	if !isJPEG && !isWebP {
		return "", bad("invalid_photo")
	}
	cfg, _, err := image.DecodeConfig(bytes.NewReader(raw))
	if err != nil || cfg.Width < 32 || cfg.Height < 32 {
		return "", bad("invalid_photo")
	}
	if isJPEG && cfg.Width <= photoSide && cfg.Height <= photoSide {
		return b64, nil
	}
	img, _, err := image.Decode(bytes.NewReader(raw))
	if err != nil {
		return "", bad("invalid_photo")
	}
	var buf bytes.Buffer
	if jpeg.Encode(&buf, downscale(img, photoSide), &jpeg.Options{Quality: 88}) != nil {
		return "", bad("invalid_photo")
	}
	return base64.StdEncoding.EncodeToString(buf.Bytes()), nil
}

type inferEntry struct {
	at       time.Time
	id       *idResult // BioCLIP: species + zero-shot scene
	full     *scene    // vision model + BioCLIP + photo stats
	idWait   chan struct{}
	fullWait chan struct{}
}

var infer = struct {
	sync.Mutex
	m map[[32]byte]*inferEntry
}{m: map[[32]byte]*inferEntry{}}

const inferTTL, inferMax = 30 * time.Minute, 400

func inferGet(key [32]byte) *inferEntry {
	infer.Lock()
	defer infer.Unlock()
	e := infer.m[key]
	if e != nil && time.Since(e.at) > inferTTL {
		e = nil
	}
	if e == nil {
		if len(infer.m) >= inferMax {
			for k, v := range infer.m {
				if time.Since(v.at) > inferTTL || len(infer.m) >= inferMax {
					delete(infer.m, k)
				}
			}
		}
		e = &inferEntry{at: time.Now()}
		infer.m[key] = e
	}
	return e
}

func photoKey(jpegB64 string) [32]byte { return sha256.Sum256([]byte(jpegB64)) }

// askID: BioCLIP once per photo (concurrent callers wait for the same call).
func askID(ctx context.Context, jpegB64 string) idResult {
	e := inferGet(photoKey(jpegB64))
	infer.Lock()
	if e.id != nil {
		r := *e.id
		infer.Unlock()
		perfCache("identify", true)
		return r
	}
	if w := e.idWait; w != nil {
		infer.Unlock()
		select {
		case <-w:
		case <-ctx.Done():
		}
		infer.Lock()
		defer infer.Unlock()
		if e.id != nil {
			perfCache("identify", true)
			return *e.id
		}
		return idResult{}
	}
	w := make(chan struct{})
	e.idWait = w
	infer.Unlock()
	perfCache("identify", false)
	r := askIDRaw(ctx, jpegB64)
	infer.Lock()
	if r.Candidates != nil {
		e.id = &r
	}
	e.idWait = nil
	infer.Unlock()
	close(w)
	return r
}

// quickScene: the scene from BioCLIP and the photo alone (no vision model), in well under a second.
func quickScene(ctx context.Context, jpegB64 string) (scene, []bioCand) {
	if sc, ok := cachedFull(jpegB64); ok {
		return sc, askID(ctx, jpegB64).Candidates
	}
	id := askID(ctx, jpegB64)
	img, _ := base64.StdEncoding.DecodeString(jpegB64)
	return buildScene(vlmScene{}, false, id.Scene, img), id.Candidates
}

func cachedFull(jpegB64 string) (scene, bool) {
	e := inferGet(photoKey(jpegB64))
	infer.Lock()
	defer infer.Unlock()
	if e.full != nil {
		return *e.full, true
	}
	return scene{}, false
}

// readScene: the whole scene (vision model + BioCLIP in parallel), once per photo.
func readScene(ctx context.Context, jpegB64 string) (scene, []bioCand) {
	e := inferGet(photoKey(jpegB64))
	infer.Lock()
	if e.full != nil {
		sc := *e.full
		infer.Unlock()
		perfCache("scene", true)
		return sc, askID(ctx, jpegB64).Candidates
	}
	if w := e.fullWait; w != nil { // a warm-up is already running: wait for it
		infer.Unlock()
		select {
		case <-w:
		case <-ctx.Done():
		}
		infer.Lock()
		if e.full != nil {
			sc := *e.full
			infer.Unlock()
			perfCache("scene", true)
			return sc, askID(ctx, jpegB64).Candidates
		}
		infer.Unlock()
		return quickScene(ctx, jpegB64)
	}
	w := make(chan struct{})
	e.fullWait = w
	infer.Unlock()
	perfCache("scene", false)
	img, _ := base64.StdEncoding.DecodeString(jpegB64)
	var id idResult
	var v vlmScene
	var okV bool
	var wg sync.WaitGroup
	wg.Add(2)
	go func() { defer wg.Done(); id = askID(ctx, jpegB64) }()
	go func() { defer wg.Done(); v, okV = askVLMScene(ctx, jpegB64) }()
	wg.Wait()
	sc := buildScene(v, okV, id.Scene, img)
	infer.Lock()
	if okV {
		e.full = &sc
	}
	e.fullWait = nil
	infer.Unlock()
	close(w)
	return sc, id.Candidates
}

// warmScene starts the whole scene in the background (once per photo), so the care-plan or diagnosis that
// usually follows an identify finds it ready.
func warmScene(jpegB64 string) {
	e := inferGet(photoKey(jpegB64))
	infer.Lock()
	busy := e.full != nil || e.fullWait != nil
	infer.Unlock()
	if busy {
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
		defer cancel()
		readScene(ctx, jpegB64)
	}()
}

// needsFull: the quick scene is unsure about what changes care most (medium, fake plant, pot).
func (sc scene) needsFull() bool {
	return sc.Soil.Medium.Conf < 0.5 || sc.Plant.Artificial.Conf < 0.5 || sc.Pot.Material.Conf < 0.4
}
