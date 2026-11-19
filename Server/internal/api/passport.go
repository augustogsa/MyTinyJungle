package api

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"regexp"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5"
)

// Plant passport: a public care card behind an unguessable token, for a QR code on the pot or a link
// sent to a friend. It holds the species and how this plant is cared for (light, water rhythm, soil, pot,
// the owner's care notes). Never the plant's name, photos, people or places.
//   POST   /v1/plants/{id}/passport {notes?}   → {token, url, card}   (same token on re-share, card refreshed)
//   DELETE /v1/plants/{id}/passport                                     (link stops working)
//   GET    /v1/passports/{token}?lang=          public JSON
//   GET    /p/{token}?lang=                     public page
//   POST   /v1/passports/{token}/import {jungleId?} → a new plant in your jungle (personal by default)

const passportBase = "https://api.mytinyjungle.com/p/"

var tokenRe = regexp.MustCompile(`^[A-Za-z0-9_-]{22}$`)

type passportCard struct {
	SpeciesID      string   `json:"speciesId"`
	WaterEveryDays float64  `json:"waterEveryDays"`
	Substrate      string   `json:"substrate,omitempty"`
	PotMaterial    string   `json:"potMaterial,omitempty"`
	PotDiameterCm  *float64 `json:"potDiameterCm,omitempty"`
	PotDrainage    *bool    `json:"potHasDrainage,omitempty"`
	Outdoor        bool     `json:"outdoor"`
	Notes          string   `json:"notes,omitempty"`
}

func passportToken() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

func cardFrom(data map[string]any, notes string, care func(string) speciesCare) passportCard {
	c := passportCard{SpeciesID: str(data, "speciesID"), Substrate: str(data, "substrate"), PotMaterial: str(data, "potMaterial"),
		Outdoor: boolean(data, "isOutdoor"), Notes: notes}
	if v, ok := num(data, "learnedDryDays"); ok && v > 0 {
		c.WaterEveryDays = v
	} else if sc := care(c.SpeciesID); sc.dry > 0 {
		c.WaterEveryDays = sc.dry
	} else {
		c.WaterEveryDays = 7
	}
	c.WaterEveryDays = float64(int(c.WaterEveryDays + 0.5))
	if v, ok := num(data, "potDiameterCm"); ok && v > 0 {
		c.PotDiameterCm = &v
	}
	if v, ok := data["potHasDrainage"].(bool); ok {
		c.PotDrainage = &v
	}
	return c
}

func (s *Server) createPassport(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Notes string `json:"notes"`
	}
	ctx, c, pid := r.Context(), claimsOf(r), r.PathValue("id")
	if r.ContentLength != 0 && decode(r, &in) != nil || !isUUID(pid) || len(in.Notes) > 600 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	_, data, err := s.loadPlant(ctx, c.Sub, pid)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	card := cardFrom(data, strings.TrimSpace(in.Notes), s.speciesLookup())
	if card.SpeciesID == "" {
		writeErr(w, http.StatusUnprocessableEntity, "species_unknown")
		return
	}
	var token string
	err = s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `insert into plant_passports (token, user_id, plant_id, card) values ($1,$2,$3,$4)
			on conflict (user_id, plant_id) do update set card = excluded.card, updated_at = now() returning token`,
			passportToken(), c.Sub, pid, card).Scan(&token)
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"token": token, "url": passportBase + token, "card": s.publicCard(card, r.URL.Query().Get("lang"))})
}

func (s *Server) deletePassport(w http.ResponseWriter, r *http.Request) {
	ctx, c, pid := r.Context(), claimsOf(r), r.PathValue("id")
	if !isUUID(pid) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `delete from plant_passports where user_id = $1 and plant_id = $2`, c.Sub, pid)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

// publicCard is the card as shown to anyone: species facts in the reader's language plus this plant's care.
func (s *Server) publicCard(c passportCard, lang string) map[string]any {
	if theBrain.dir == "" {
		theBrain.dir = s.cfg.ContentDir
	}
	sp := theBrain.findSpecies(c.SpeciesID)
	out := map[string]any{"waterEveryDays": c.WaterEveryDays, "outdoor": c.Outdoor, "notes": c.Notes,
		"substrate": c.Substrate, "potMaterial": c.PotMaterial, "potDiameterCm": c.PotDiameterCm, "potHasDrainage": c.PotDrainage}
	li := langIdx(lang)
	if sp == nil {
		out["species"] = map[string]any{"id": c.SpeciesID}
		return out
	}
	name := sp.En
	if li == 1 && sp.Pt != "" {
		name = sp.Pt
	}
	l := digestLang(lang)
	mix := sp.Mix
	if _, ok := mixText[mix]; !ok {
		mix = "universal"
	}
	out["species"] = map[string]any{"id": sp.ID, "scientific": sp.Scientific, "name": name, "family": sp.Family}
	out["light"] = sp.Light
	out["waterStyle"] = sp.WaterStyle
	out["humidityMin"] = sp.HumidityMin
	out["tempMin"], out["tempMax"] = sp.TempMin, sp.TempMax
	out["soil"] = map[string]string{"code": mix, "name": mixText[mix][li][0], "recipe": mixText[mix][li][1]}
	out["feedEveryWeeks"] = sp.FeedWeeks
	out["toxicCats"], out["toxicDogs"] = sp.ToxicCats, sp.ToxicDogs
	out["tip"] = theBrain.tr(l, sp.Tip)
	return out
}

func (s *Server) passportByToken(ctx context.Context, token string, view bool) (passportCard, bool) {
	var c passportCard
	if !tokenRe.MatchString(token) {
		return c, false
	}
	q := `select card from plant_passports where token = $1`
	if view {
		q = `update plant_passports set views = views + 1 where token = $1 returning card`
	}
	return c, s.db.Auth.QueryRow(ctx, q, token).Scan(&c) == nil
}

// GET /v1/passports/{token}
func (s *Server) getPassport(w http.ResponseWriter, r *http.Request) {
	c, ok := s.passportByToken(r.Context(), r.PathValue("token"), true)
	if !ok {
		writeErr(w, http.StatusNotFound, "not_found")
		return
	}
	writeJSON(w, http.StatusOK, s.publicCard(c, r.URL.Query().Get("lang")))
}

// POST /v1/passports/{token}/import {jungleId?}
func (s *Server) importPassport(w http.ResponseWriter, r *http.Request) {
	var in struct {
		JungleID string `json:"jungleId"`
		Lang     string `json:"lang"`
	}
	ctx, c := r.Context(), claimsOf(r)
	if r.ContentLength != 0 && decode(r, &in) != nil || (in.JungleID != "" && !isUUID(in.JungleID)) || len(in.Lang) > 12 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	card, ok := s.passportByToken(ctx, r.PathValue("token"), false)
	if !ok {
		writeErr(w, http.StatusNotFound, "not_found")
		return
	}
	pub := s.publicCard(card, in.Lang)
	name := ""
	if sp, ok := pub["species"].(map[string]any); ok {
		name, _ = sp["name"].(string)
	}
	now := s.now()
	data := map[string]any{"name": name, "nameGender": "", "speciesID": card.SpeciesID, "personality": "", "location": "",
		"isOutdoor": card.Outdoor, "potDiameterCm": card.PotDiameterCm, "potMaterial": nilIfEmpty(card.PotMaterial),
		"potHasDrainage": card.PotDrainage == nil || *card.PotDrainage, "substrate": card.Substrate, "heightCm": nil,
		"acquiredAt": now.Unix(), "lastRepotAt": nil, "learnedDryDays": card.WaterEveryDays, "createdAt": now.Unix(),
		"isArchived": false, "archivedReason": nil, "photo": nil, "passportNotes": nilIfEmpty(card.Notes)}
	raw, _ := json.Marshal(data)
	var pid, jid string
	var version int64
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		jid = in.JungleID
		if jid == "" {
			if err := tx.QueryRow(ctx, `select id::text from jungles where owner_id = $1 and is_personal`, c.Sub).Scan(&jid); err != nil {
				return asNotFound(err)
			}
		}
		var reach bool
		if err := tx.QueryRow(ctx, `select $1::uuid in (select mtj_my_jungles())`, jid).Scan(&reach); err != nil {
			return err
		}
		if !reach {
			return apiError{http.StatusForbidden, "forbidden"}
		}
		return tx.QueryRow(ctx, `insert into records (jungle_id, entity, id, data, updated_by, updated_device, client_updated_at)
			values ($1, 'plant', gen_random_uuid(), $2, $3, $4, now()) returning id::text, version`, jid, raw, c.Sub, nilIfEmpty(c.Dev)).Scan(&pid, &version)
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	_, _ = s.db.Auth.Exec(ctx, `update plant_passports set imports = imports + 1 where token = $1`, r.PathValue("token"))
	s.pusher.jungleChanged(jid, c.Sub)
	writeJSON(w, http.StatusCreated, map[string]any{"plantId": pid, "jungleId": jid, "version": version})
}

func nilIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

var passportPage = template.Must(template.New("p").Parse(`<!doctype html>
<html lang="{{.Lang}}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>{{.Name}} · My Tiny Jungle</title>
<style>
:root{--bg:#f6f5f0;--fg:#1d2a1f;--mut:#5f6b60;--card:#fff;--line:#e3e2da;--acc:#2f6b3a}
@media (prefers-color-scheme:dark){:root{--bg:#121512;--fg:#e8ece6;--mut:#a3aca3;--card:#1b201c;--line:#2a312b;--acc:#7fc48a}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.5 -apple-system,system-ui,sans-serif}
main{max-width:560px;margin:0 auto;padding:32px 16px}h1{font-size:28px;margin:0}.sci{color:var(--mut);font-style:italic;margin:2px 0 20px}
dl{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:4px 16px;margin:0}
.r{display:flex;justify-content:space-between;gap:16px;padding:12px 0;border-bottom:1px solid var(--line)}.r:last-child{border:0}
dt{color:var(--mut)}dd{margin:0;text-align:right}p.n{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px 16px}
a.b{display:block;text-align:center;margin-top:24px;padding:14px;border-radius:12px;background:var(--acc);color:var(--bg);text-decoration:none;font-weight:600}
footer{color:var(--mut);font-size:13px;margin-top:20px;text-align:center}
</style></head><body><main>
<h1>{{.Name}}</h1><p class="sci">{{.Scientific}}</p>
<dl>{{range .Rows}}<div class="r"><dt>{{index . 0}}</dt><dd>{{index . 1}}</dd></div>{{end}}</dl>
{{if .Tip}}<p class="n">{{.Tip}}</p>{{end}}
{{if .Notes}}<p class="n">{{.Notes}}</p>{{end}}
<a class="b" href="{{.Open}}">{{.Cta}}</a>
<footer>My Tiny Jungle · support@simpleappscompany.com</footer>
</main></body></html>`))

var passportLabels = [6][9]string{ // light, water, every N days, soil, pot, humidity, temperature, pets, cta
	{"Light", "Water", "every %d days", "Soil", "Pot", "Humidity", "Temperature", "Toxic to pets", "Add to my jungle"},
	{"Luz", "Rega", "a cada %d dias", "Substrato", "Vaso", "Umidade", "Temperatura", "Tóxica pra pets", "Adicionar na minha selva"},
	{"Luz", "Riego", "cada %d días", "Sustrato", "Maceta", "Humedad", "Temperatura", "Tóxica para mascotas", "Añadir a mi jungla"},
	{"Lumière", "Arrosage", "tous les %d jours", "Terreau", "Pot", "Humidité", "Température", "Toxique pour les animaux", "Ajouter à ma jungle"},
	{"Licht", "Gießen", "alle %d Tage", "Erde", "Topf", "Luftfeuchte", "Temperatur", "Giftig für Haustiere", "Zu meinem Dschungel"},
	{"日当たり", "水やり", "%d日ごと", "用土", "鉢", "湿度", "温度", "ペットに有毒", "マイジャングルに追加"},
}

var lightNames = map[string][6]string{
	"low":    {"Low light", "Pouca luz", "Poca luz", "Peu de lumière", "Wenig Licht", "日陰でOK"},
	"medium": {"Medium, indirect", "Meia-luz, indireta", "Media, indirecta", "Moyenne, indirecte", "Mittel, indirekt", "明るい日陰"},
	"bright": {"Bright, indirect", "Bem clara, indireta", "Brillante, indirecta", "Vive, indirecte", "Hell, indirekt", "明るい間接光"},
	"direct": {"Direct sun", "Sol direto", "Sol directo", "Plein soleil", "Direkte Sonne", "直射日光"},
}

// GET /p/{token}: the public page. Opening it with the app installed hands the token to the app.
func (s *Server) passportHTML(w http.ResponseWriter, r *http.Request) {
	token := r.PathValue("token")
	c, ok := s.passportByToken(r.Context(), token, true)
	if !ok {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte("This plant passport is no longer shared.\n"))
		return
	}
	lang := r.URL.Query().Get("lang")
	if lang == "" {
		lang = r.Header.Get("Accept-Language")
		if i := strings.IndexAny(lang, ",;"); i > 0 {
			lang = lang[:i]
		}
	}
	li := langIdx(lang)
	lb := passportLabels[li]
	pub := s.publicCard(c, lang)
	sp, _ := pub["species"].(map[string]any)
	name, _ := sp["name"].(string)
	sci, _ := sp["scientific"].(string)
	if name == "" {
		name = c.SpeciesID
	}
	var rows [][2]string
	if l, ok := lightNames[fmt.Sprint(pub["light"])]; ok {
		rows = append(rows, [2]string{lb[0], l[li]})
	}
	rows = append(rows, [2]string{lb[1], strings.Replace(lb[2], "%d", strconv.Itoa(int(c.WaterEveryDays)), 1)})
	if soil, ok := pub["soil"].(map[string]string); ok {
		rows = append(rows, [2]string{lb[3], soil["name"]})
	}
	if c.PotDiameterCm != nil {
		rows = append(rows, [2]string{lb[4], fmt.Sprintf("%.0f cm %s", *c.PotDiameterCm, c.PotMaterial)})
	}
	if h, ok := pub["humidityMin"].(float64); ok && h > 0 {
		rows = append(rows, [2]string{lb[5], fmt.Sprintf("≥ %.0f%%", h)})
	}
	if lo, ok := pub["tempMin"].(float64); ok && lo != 0 {
		hi, _ := pub["tempMax"].(float64)
		rows = append(rows, [2]string{lb[6], fmt.Sprintf("%.0f–%.0f °C", lo, hi)})
	}
	if pub["toxicCats"] == true || pub["toxicDogs"] == true {
		rows = append(rows, [2]string{lb[7], "⚠︎"})
	}
	tip, _ := pub["tip"].(string)
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'")
	w.Header().Set("Cache-Control", "public, max-age=300")
	_ = passportPage.Execute(w, map[string]any{"Lang": digestLang(lang), "Name": name, "Scientific": sci, "Rows": rows, "Tip": tip,
		"Notes": c.Notes, "Open": template.URL("mytinyjungle://passport/" + token), "Cta": lb[8]})
}
