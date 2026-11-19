package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// Weekly jungle digest. Built from synced records (plant, care_event, care_task) of every jungle the user
// can reach. GET /v1/me/digest returns it for a digest screen; once a week (Sunday from 17:00 UTC) every
// opted-in device with push gets one visible push in the user's language, deep link mytinyjungle://digest.
// The push carries counts only, no plant names.

const digestURL = "mytinyjungle://digest"

type digestItem struct {
	PlantID string     `json:"plantId,omitempty"`
	Plant   string     `json:"plant,omitempty"`
	Kind    string     `json:"kind"`             // due: water|feed|task; watch: overdue_water|problem|quiet|repot; grew: newLeaf|flower|measure|propagate; photos: care event kind
	Date    *time.Time `json:"date,omitempty"`   // due date, or when it happened
	Overdue bool       `json:"overdue,omitempty"` // due items past their date
	Title   string     `json:"title,omitempty"`  // task title
	Value   *float64   `json:"value,omitempty"`  // measure value
	EventID string     `json:"eventId,omitempty"`
	Media   string     `json:"media,omitempty"` // GET path of the photo
}

type digest struct {
	Week   string       `json:"week"` // ISO week start (Monday), YYYY-MM-DD
	Due    []digestItem `json:"due"`
	Watch  []digestItem `json:"watch"`
	Grew   []digestItem `json:"grew"`
	Photos []digestItem `json:"photos"`
}

func (d digest) empty() bool { return len(d.Due)+len(d.Watch)+len(d.Grew) == 0 }

type querier interface {
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
}

type rec struct {
	jungle, entity, id string
	data               map[string]any
}

func num(m map[string]any, k string) (float64, bool) { v, ok := m[k].(float64); return v, ok }
func str(m map[string]any, k string) string          { v, _ := m[k].(string); return v }
func boolean(m map[string]any, k string) bool        { v, _ := m[k].(bool); return v }
func epoch(f float64) time.Time                      { return time.Unix(int64(f), 0).UTC() }

// loadDigest reads the user's live records (care events from the last 120 days) and builds the digest.
func (s *Server) loadDigest(ctx context.Context, q querier, uid string, now time.Time) (digest, error) {
	rows, err := q.Query(ctx, `select jungle_id::text, entity, id::text, data from records
		where not deleted and entity in ('plant', 'care_event', 'care_task')
		and jungle_id in (select jungle_id from jungle_members where user_id = $1 and (until is null or until > now()))
		and (entity <> 'care_event' or (jsonb_typeof(data->'date') = 'number' and (data->>'date')::float8 > $2))`,
		uid, float64(now.Add(-120*24*time.Hour).Unix()))
	if err != nil {
		return digest{}, err
	}
	var recs []rec
	for rows.Next() {
		var r rec
		if rows.Scan(&r.jungle, &r.entity, &r.id, &r.data) == nil {
			recs = append(recs, r)
		}
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return digest{}, err
	}
	return buildDigest(recs, now, s.speciesLookup()), nil
}

type speciesCare struct{ dry, feedWeeks, repotYears float64 }

func (s *Server) speciesLookup() func(string) speciesCare {
	if theBrain.dir == "" {
		theBrain.dir = s.cfg.ContentDir
	}
	theBrain.species()
	return func(id string) speciesCare {
		speciesDB.RLock()
		defer speciesDB.RUnlock()
		if sp := speciesDB.byID[id]; sp != nil {
			return speciesCare{sp.DryMax, sp.FeedWeeks, sp.RepotYears}
		}
		return speciesCare{}
	}
}

func buildDigest(recs []rec, now time.Time, care func(string) speciesCare) digest {
	wd := (int(now.Weekday()) + 6) % 7
	d := digest{Week: now.AddDate(0, 0, -wd).Format("2006-01-02"), Due: []digestItem{}, Watch: []digestItem{}, Grew: []digestItem{}, Photos: []digestItem{}}
	plants := map[string]map[string]any{}
	for _, r := range recs {
		if r.entity == "plant" && !boolean(r.data, "isArchived") {
			plants[r.id] = r.data
		}
	}
	lastWater, lastFeed, lastEvent := map[string]time.Time{}, map[string]time.Time{}, map[string]time.Time{}
	weekAgo, horizon := now.Add(-7*24*time.Hour), now.Add(7*24*time.Hour)
	name := func(pid string) string { return str(plants[pid], "name") }
	for _, r := range recs {
		if r.entity != "care_event" {
			continue
		}
		pid := str(r.data, "plantID")
		if _, ok := plants[pid]; !ok {
			continue
		}
		f, _ := num(r.data, "date")
		at := epoch(f)
		kind := str(r.data, "kind")
		if at.After(lastEvent[pid]) {
			lastEvent[pid] = at
		}
		switch kind {
		case "water":
			if at.After(lastWater[pid]) {
				lastWater[pid] = at
			}
		case "feed":
			if at.After(lastFeed[pid]) {
				lastFeed[pid] = at
			}
		}
		if at.Before(weekAgo) || at.After(now.Add(time.Hour)) {
			continue
		}
		t := at
		switch kind {
		case "newLeaf", "flower", "measure", "propagate":
			it := digestItem{PlantID: pid, Plant: name(pid), Kind: kind, Date: &t}
			if v, ok := num(r.data, "value"); ok && kind == "measure" {
				it.Value = &v
			}
			d.Grew = append(d.Grew, it)
		case "health", "treat":
			d.Watch = append(d.Watch, digestItem{PlantID: pid, Plant: name(pid), Kind: "problem", Date: &t})
		}
		if p, ok := r.data["photo"].(string); ok && p != "" {
			d.Photos = append(d.Photos, digestItem{PlantID: pid, Plant: name(pid), Kind: kind, Date: &t, EventID: r.id, Media: "/v1/media/" + r.jungle + "/" + r.id})
		}
	}
	for pid, p := range plants {
		sc := care(str(p, "speciesID"))
		interval := sc.dry
		if v, ok := num(p, "learnedDryDays"); ok && v > 0 {
			interval = v
		}
		if interval <= 0 {
			interval = 7
		}
		created := now
		if f, ok := num(p, "createdAt"); ok {
			created = epoch(f)
		}
		base := lastWater[pid]
		if base.IsZero() {
			base = created
		}
		next := base.Add(time.Duration(interval * 24 * float64(time.Hour)))
		if next.Before(horizon) {
			n := next
			d.Due = append(d.Due, digestItem{PlantID: pid, Plant: name(pid), Kind: "water", Date: &n, Overdue: next.Before(now)})
			if now.Sub(next) > time.Duration(interval*24*float64(time.Hour)) {
				d.Watch = append(d.Watch, digestItem{PlantID: pid, Plant: name(pid), Kind: "overdue_water", Date: &n})
			}
		}
		if lf := lastFeed[pid]; !lf.IsZero() && sc.feedWeeks > 0 {
			if nf := lf.AddDate(0, 0, int(sc.feedWeeks*7)); nf.Before(horizon) {
				d.Due = append(d.Due, digestItem{PlantID: pid, Plant: name(pid), Kind: "feed", Date: &nf, Overdue: nf.Before(now)})
			}
		}
		if le := lastEvent[pid]; created.Before(now.AddDate(0, 0, -30)) && (le.IsZero() || le.Before(now.AddDate(0, 0, -30))) {
			d.Watch = append(d.Watch, digestItem{PlantID: pid, Plant: name(pid), Kind: "quiet"})
		}
		if f, ok := num(p, "lastRepotAt"); ok && sc.repotYears > 0 && epoch(f).Before(now.AddDate(0, 0, -int(sc.repotYears*365))) {
			d.Watch = append(d.Watch, digestItem{PlantID: pid, Plant: name(pid), Kind: "repot"})
		}
	}
	for _, r := range recs {
		if r.entity != "care_task" || boolean(r.data, "done") {
			continue
		}
		f, ok := num(r.data, "due")
		if !ok {
			continue
		}
		due := epoch(f)
		if due.After(horizon) || due.Before(now.AddDate(0, 0, -30)) {
			continue
		}
		pid := str(r.data, "plantID")
		d.Due = append(d.Due, digestItem{PlantID: pid, Plant: name(pid), Kind: "task", Title: str(r.data, "title"), Date: &due, Overdue: due.Before(now)})
	}
	byDate := func(items []digestItem) {
		sort.SliceStable(items, func(i, j int) bool {
			a, b := items[i].Date, items[j].Date
			if a == nil || b == nil {
				return a != nil
			}
			return a.Before(*b)
		})
	}
	byDate(d.Due)
	byDate(d.Watch)
	byDate(d.Grew)
	byDate(d.Photos)
	if len(d.Photos) > 12 {
		d.Photos = d.Photos[len(d.Photos)-12:]
	}
	return d
}

// GET /v1/me/digest
func (s *Server) getDigest(w http.ResponseWriter, r *http.Request) {
	c := claimsOf(r)
	var d digest
	err := s.db.AsUser(r.Context(), c.Sub, func(tx pgx.Tx) error {
		var err error
		d, err = s.loadDigest(r.Context(), tx, c.Sub, s.now().UTC())
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, d)
}

// PUT /v1/me/digest {on, deviceId, lang?}
func (s *Server) putDigest(w http.ResponseWriter, r *http.Request) {
	var in struct {
		On       bool
		DeviceID string `json:"deviceId"`
		Lang     string
	}
	if decode(r, &in) != nil || !isUUID(in.DeviceID) || len(in.Lang) > 12 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	c := claimsOf(r)
	var n int64
	err := s.db.AsUser(r.Context(), c.Sub, func(tx pgx.Tx) error {
		tag, err := tx.Exec(r.Context(), `update devices set digest_on = $1, digest_lang = coalesce(nullif($2, ''), digest_lang) where id = $3 and user_id = $4`,
			in.On, in.Lang, in.DeviceID, c.Sub)
		n = tag.RowsAffected()
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if n == 0 {
		writeErr(w, http.StatusNotFound, "device_not_found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true, "on": in.On})
}

var digestText = map[string][7]string{ // title, dueOne, dueMany, watchOne, watchMany, grewOnly, joiner
	"en":    {"Your jungle this week", "1 thing to do", "%d things to do", "1 plant to keep an eye on", "%d plants to keep an eye on", "New growth this week. Come take a look!", " · "},
	"pt-BR": {"Sua selva essa semana", "1 cuidado pra fazer", "%d cuidados pra fazer", "1 planta pra ficar de olho", "%d plantas pra ficar de olho", "Teve coisa nova crescendo essa semana. Vem ver!", " · "},
	"es":    {"Tu jungla esta semana", "1 cuidado pendiente", "%d cuidados pendientes", "1 planta a vigilar", "%d plantas a vigilar", "Esta semana hubo crecimiento. ¡Ven a verlo!", " · "},
	"fr":    {"Ta jungle cette semaine", "1 soin à faire", "%d soins à faire", "1 plante à surveiller", "%d plantes à surveiller", "Ça a poussé cette semaine. Viens voir !", " · "},
	"de":    {"Dein Dschungel diese Woche", "1 Pflegeaufgabe", "%d Pflegeaufgaben", "1 Pflanze im Blick behalten", "%d Pflanzen im Blick behalten", "Diese Woche ist etwas gewachsen. Schau mal rein!", " · "},
	"ja":    {"今週のジャングル", "お世話 1件", "お世話 %d件", "様子見 1株", "様子見 %d株", "今週は新しい成長がありました。見てみましょう！", "・"},
}

func digestLang(l string) string {
	l = strings.ToLower(strings.ReplaceAll(l, "_", "-"))
	switch {
	case strings.HasPrefix(l, "pt"):
		return "pt-BR"
	case l == "":
		return "en"
	}
	if _, ok := digestText[l[:min(2, len(l))]]; ok {
		return l[:2]
	}
	return "en"
}

// digestPush returns the title and body for a digest, or ok=false when there is nothing worth a push.
func digestPush(d digest, lang string) (title, body string, ok bool) {
	if d.empty() {
		return "", "", false
	}
	t := digestText[digestLang(lang)]
	watched := map[string]bool{}
	for _, it := range d.Watch {
		watched[it.PlantID] = true
	}
	var parts []string
	switch n := len(d.Due); {
	case n == 1:
		parts = append(parts, t[1])
	case n > 1:
		parts = append(parts, fmt.Sprintf(t[2], n))
	}
	switch n := len(watched); {
	case n == 1:
		parts = append(parts, t[3])
	case n > 1:
		parts = append(parts, fmt.Sprintf(t[4], n))
	}
	if len(parts) == 0 {
		return t[0], t[5], true
	}
	return t[0], strings.Join(parts, t[6]), true
}

// digestLoop checks hourly; on Sunday from 17:00 UTC it sends each opted-in device one digest a week.
func (s *Server) digestLoop(ctx context.Context) {
	t := time.NewTicker(time.Hour)
	defer t.Stop()
	for {
		if now := s.now().UTC(); now.Weekday() == time.Sunday && now.Hour() >= 17 {
			s.digestRound(ctx, now)
		}
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

func (s *Server) digestRound(ctx context.Context, now time.Time) {
	if s.pusher == nil || s.db == nil || s.db.Admin == nil {
		return
	}
	rows, err := s.db.Auth.Query(ctx, `update devices d set digest_sent_at = now()
		from users u where u.id = d.user_id and u.deleted_at is null and d.digest_on and d.push_token is not null
		and (d.digest_sent_at is null or d.digest_sent_at < now() - interval '6 days')
		returning d.user_id::text, d.platform, d.push_token, coalesce(d.digest_lang, d.weather_lang, u.locale, 'en')`)
	if err != nil {
		s.log.Warn("digest", "err", err.Error())
		return
	}
	type dev struct{ User, Platform, Token, Lang string }
	devs, _ := pgx.CollectRows(rows, pgx.RowToStructByPos[dev])
	byUser := map[string][]dev{}
	for _, d := range devs {
		byUser[d.User] = append(byUser[d.User], d)
	}
	sent := 0
	for uid, ds := range byUser {
		dg, err := s.loadDigest(ctx, s.db.Admin, uid, now)
		if err != nil {
			continue
		}
		for _, d := range ds {
			if title, body, ok := digestPush(dg, d.Lang); ok {
				s.pusher.alertLink(ctx, d.Platform, d.Token, title, body, "digest", digestURL)
				sent++
			}
		}
	}
	s.log.Info("digest", "users", len(byUser), "pushes", sent)
}

// alertLink sends a visible notification that opens url (APNs "url" key, FCM data "url").
func (p *pusher) alertLink(ctx context.Context, platform, token, title, body, kind, url string) {
	var gone bool
	var err error
	switch platform {
	case "ios":
		if p.cfg.APNsKeyFile == "" {
			return
		}
		var tok string
		if tok, err = p.apnsJWT(); err != nil {
			break
		}
		payload, _ := json.Marshal(map[string]any{"aps": map[string]any{"alert": map[string]string{"title": title, "body": body}, "sound": "default", "thread-id": kind},
			"kind": kind, "url": url})
		for _, host := range []string{"api.push.apple.com", "api.sandbox.push.apple.com"} {
			req, _ := http.NewRequestWithContext(ctx, http.MethodPost, "https://"+host+"/3/device/"+token, bytes.NewReader(payload))
			req.Header.Set("authorization", "bearer "+tok)
			req.Header.Set("apns-topic", p.cfg.AppleBundleID)
			req.Header.Set("apns-push-type", "alert")
			req.Header.Set("apns-collapse-id", kind)
			res, e := p.http.Do(req)
			if e != nil {
				err = e
				break
			}
			res.Body.Close()
			if res.StatusCode == 200 {
				gone, err = false, nil
				break
			}
			gone = res.StatusCode == 410 || res.StatusCode == 400
		}
	case "android":
		if p.fcm == nil || p.proj == "" {
			return
		}
		var at string
		if at, err = p.fcm.accessToken(ctx); err != nil {
			break
		}
		payload, _ := json.Marshal(map[string]any{"message": map[string]any{"token": token,
			"notification": map[string]string{"title": title, "body": body},
			"data":         map[string]string{"kind": kind, "url": url},
			"android":      map[string]any{"collapse_key": kind}}})
		req, _ := http.NewRequestWithContext(ctx, http.MethodPost, "https://fcm.googleapis.com/v1/projects/"+p.proj+"/messages:send", bytes.NewReader(payload))
		req.Header.Set("Authorization", "Bearer "+at)
		req.Header.Set("Content-Type", "application/json")
		res, e := p.http.Do(req)
		if e != nil {
			err = e
			break
		}
		res.Body.Close()
		gone = res.StatusCode == 404
	}
	if err != nil {
		p.log.Warn("digest push", "err", err.Error())
	}
	if gone {
		_, _ = p.db.Auth.Exec(ctx, `update devices set push_token = null where push_token = $1`, token)
	}
}
