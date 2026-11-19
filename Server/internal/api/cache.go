package api

import (
	"sort"
	"strings"
	"sync"
	"time"
)

// answers caches ask and diagnose answers by species, language, question/photo and situation bucket.
// In memory, 30 minutes, at most 2000 entries; nothing personal is part of a key (photos by sha256 only).
var answers = &ttlCache{ttl: 30 * time.Minute, max: 2000, m: map[string]ttlItem{}}

type ttlItem struct {
	at time.Time
	v  any
}

type ttlCache struct {
	sync.Mutex
	ttl time.Duration
	max int
	m   map[string]ttlItem
}

func (c *ttlCache) get(k string) (any, bool) {
	c.Lock()
	defer c.Unlock()
	it, ok := c.m[k]
	if !ok || time.Since(it.at) > c.ttl {
		return nil, false
	}
	return it.v, true
}

func (c *ttlCache) put(k string, v any) {
	c.Lock()
	defer c.Unlock()
	if len(c.m) >= c.max {
		for key, it := range c.m {
			if time.Since(it.at) > c.ttl || len(c.m) >= c.max {
				delete(c.m, key)
			}
		}
	}
	c.m[k] = ttlItem{time.Now(), v}
}

func answerKey(parts ...string) string { return strings.Join(parts, "\x1f") }

// bucket: the situation as a stable string (keys and values sorted); weather is already categorical here.
func (sit situation) bucket() string {
	var ks []string
	for k, vs := range sit {
		v := append([]string(nil), vs...)
		sort.Strings(v)
		ks = append(ks, k+"="+strings.Join(v, ","))
	}
	sort.Strings(ks)
	return strings.Join(ks, ";")
}

// normQ: a question in a cache-friendly form (case, spacing and punctuation don't matter).
func normQ(q string) string {
	return strings.Join(strings.FieldsFunc(strings.ToLower(q), func(r rune) bool {
		return r == ' ' || r == '?' || r == '!' || r == '.' || r == ',' || r == '¿' || r == '¡' || r == '？' || r == '、' || r == '。'
	}), " ")
}
