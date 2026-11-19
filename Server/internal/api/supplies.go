package api

import (
	"context"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

// Shopping: GET /v1/plants/{id}/supplies recommends the soil mix, pot and fertiliser for the plant's species
// (affiliate links are null for now). Supplies stock (PUT/GET/DELETE /v1/me/supplies) tracks what the owner
// has; when an item drops to its low mark, one push per drop goes to the owner's devices.

// six languages: en, pt-BR, es, fr, de, ja
var mixText = map[string][6][2]string{ // code → lang → {name, recipe}
	"universal": {{"All-purpose potting mix", "Quality potting soil with a handful of perlite for air."}, {"Substrato universal", "Terra vegetal boa com um punhado de perlita pra arejar."}, {"Sustrato universal", "Buen sustrato con un puñado de perlita para airear."}, {"Terreau universel", "Un bon terreau avec une poignée de perlite pour aérer."}, {"Universalerde", "Gute Blumenerde mit einer Handvoll Perlite für Luft."}, {"草花用培養土", "良質な培養土にパーライトをひとつかみ混ぜて通気よく。"}},
	"cactus":    {{"Cactus and succulent mix", "Gritty and fast-draining: half potting soil, half pumice or coarse sand."}, {"Substrato pra cactos e suculentas", "Bem drenado: metade terra, metade areia grossa ou pedra-pomes."}, {"Sustrato para cactus y suculentas", "Muy drenante: mitad sustrato, mitad piedra pómez o arena gruesa."}, {"Terreau cactées et succulentes", "Très drainant : moitié terreau, moitié pierre ponce ou sable grossier."}, {"Kakteen- und Sukkulentenerde", "Mineralisch und durchlässig: halb Erde, halb Bims oder grober Sand."}, {"サボテン・多肉植物用土", "水はけ重視：培養土と軽石（または粗い砂）を半々に。"}},
	"aroid":     {{"Chunky aroid mix", "Potting soil, orchid bark and perlite in equal parts."}, {"Substrato aeróide (bem aerado)", "Terra, casca de pinus e perlita em partes iguais."}, {"Sustrato para aráceas", "Sustrato, corteza de pino y perlita a partes iguales."}, {"Mélange pour aracées", "Terreau, écorce de pin et perlite à parts égales."}, {"Aroiden-Substrat", "Erde, Pinienrinde und Perlite zu gleichen Teilen."}, {"アロイド用ミックス", "培養土・バーク・パーライトを同量ずつ。"}},
	"vegetable": {{"Vegetable and herb compost", "Rich compost-based soil that holds moisture."}, {"Substrato pra hortas", "Terra rica em composto que segura umidade."}, {"Sustrato para huerto", "Sustrato rico en compost que retiene humedad."}, {"Terreau potager", "Terreau riche en compost qui retient l'humidité."}, {"Gemüse- und Kräutererde", "Nährstoffreiche Komposterde, die Feuchtigkeit hält."}, {"野菜・ハーブ用土", "水もちのよい堆肥入りの土。"}},
	"orchid":    {{"Orchid bark", "Coarse bark only, no soil, so roots get air."}, {"Substrato pra orquídea", "Só casca de pinus grossa, sem terra, pras raízes respirarem."}, {"Corteza para orquídeas", "Solo corteza gruesa, sin tierra, para que las raíces respiren."}, {"Écorce pour orchidées", "Uniquement de l'écorce grossière, sans terre, pour aérer les racines."}, {"Orchideenrinde", "Nur grobe Rinde, keine Erde, damit die Wurzeln Luft bekommen."}, {"洋ラン用バーク", "土は使わず粗いバークだけで根に空気を。"}},
	"fern":      {{"Moist peat-free mix", "Soft, moisture-holding soil with coco coir and a little bark."}, {"Substrato úmido pra samambaias", "Terra macia que segura água, com fibra de coco e um pouco de casca."}, {"Sustrato húmedo para helechos", "Sustrato suave que retiene agua, con fibra de coco y algo de corteza."}, {"Terreau humide pour fougères", "Terreau souple qui garde l'eau, avec fibre de coco et un peu d'écorce."}, {"Feuchte Farnerde", "Lockere, wasserhaltende Erde mit Kokosfaser und etwas Rinde."}, {"シダ用の保水性ミックス", "ココピートと少量のバークを混ぜた、しっとり保水する土。"}},
	"acid":      {{"Ericaceous (acid) mix", "Lime-free soil for acid lovers."}, {"Substrato ácido", "Terra sem calcário pras plantas que gostam de acidez."}, {"Sustrato ácido", "Sustrato sin cal para plantas acidófilas."}, {"Terre de bruyère", "Terre sans calcaire pour les plantes acidophiles."}, {"Moorbeeterde (sauer)", "Kalkfreie Erde für säureliebende Pflanzen."}, {"酸性用土（鹿沼土など）", "石灰を含まない酸性の土。"}},
	"citrus":    {{"Citrus mix", "Free-draining soil with bark and grit, slightly acidic."}, {"Substrato pra cítricos", "Terra bem drenada com casca e areia grossa, levemente ácida."}, {"Sustrato para cítricos", "Sustrato drenante con corteza y grava, ligeramente ácido."}, {"Terreau agrumes", "Terreau drainant avec écorce et gravier, légèrement acide."}, {"Zitruserde", "Durchlässige Erde mit Rinde und Splitt, leicht sauer."}, {"柑橘用土", "バークと砂利で水はけよく、やや酸性に。"}},
}

var feedText = map[string][6][2]string{ // code → lang → {name, note}
	"balanced": {{"Balanced liquid fertiliser", "Half strength in the growing season."}, {"Adubo líquido equilibrado", "Na metade da dose, na época de crescimento."}, {"Fertilizante líquido equilibrado", "A media dosis en temporada de crecimiento."}, {"Engrais liquide équilibré", "À demi-dose pendant la saison de pousse."}, {"Ausgewogener Flüssigdünger", "Halbe Dosis in der Wachstumszeit."}, {"バランス型液体肥料", "生育期に規定の半分の濃さで。"}},
	"bloom":    {{"Bloom fertiliser (high potassium)", "From bud to the end of flowering."}, {"Adubo pra floração (rico em potássio)", "Do botão até o fim da florada."}, {"Fertilizante de floración (rico en potasio)", "Desde el botón hasta el fin de la floración."}, {"Engrais floraison (riche en potasse)", "Du bouton à la fin de la floraison."}, {"Blühdünger (kaliumbetont)", "Von der Knospe bis zum Ende der Blüte."}, {"開花用肥料（カリ多め）", "つぼみから花の終わりまで。"}},
	"light":    {{"Gentle liquid fertiliser", "Quarter strength, now and then."}, {"Adubo líquido suave", "Um quarto da dose, de vez em quando."}, {"Fertilizante líquido suave", "A un cuarto de dosis, de vez en cuando."}, {"Engrais liquide doux", "Au quart de la dose, de temps en temps."}, {"Milder Flüssigdünger", "Viertel Dosis, ab und zu."}, {"薄めの液体肥料", "規定の1/4の濃さで、ときどき。"}},
	"cactus":   {{"Cactus fertiliser (low nitrogen)", "Spring and summer only."}, {"Adubo pra cactos (pouco nitrogênio)", "Só na primavera e no verão."}, {"Fertilizante para cactus (bajo en nitrógeno)", "Solo en primavera y verano."}, {"Engrais cactées (pauvre en azote)", "Au printemps et en été seulement."}, {"Kakteendünger (stickstoffarm)", "Nur im Frühling und Sommer."}, {"サボテン用肥料（窒素少なめ）", "春と夏だけ。"}},
	"orchid":   {{"Orchid fertiliser", "Very diluted, every other watering in growth."}, {"Adubo pra orquídea", "Bem diluído, uma rega sim, outra não, no crescimento."}, {"Fertilizante para orquídeas", "Muy diluido, cada dos riegos en crecimiento."}, {"Engrais orchidées", "Très dilué, un arrosage sur deux en croissance."}, {"Orchideendünger", "Stark verdünnt, jedes zweite Gießen im Wachstum."}, {"洋ラン用肥料", "生育期に、ごく薄めて水やり2回に1回。"}},
	"acid":     {{"Acid-lover fertiliser", "For azaleas, camellias and friends."}, {"Adubo pra plantas acidófilas", "Pra azaleias, camélias e parecidas."}, {"Fertilizante para acidófilas", "Para azaleas, camelias y similares."}, {"Engrais plantes de terre de bruyère", "Pour azalées, camélias et compagnie."}, {"Dünger für Moorbeetpflanzen", "Für Azaleen, Kamelien und Co."}, {"酸性植物用肥料", "ツツジやツバキなどに。"}},
	"citrus":   {{"Citrus fertiliser", "With iron and magnesium against yellow leaves."}, {"Adubo pra cítricos", "Com ferro e magnésio contra folha amarela."}, {"Fertilizante para cítricos", "Con hierro y magnesio contra las hojas amarillas."}, {"Engrais agrumes", "Avec fer et magnésium contre le jaunissement."}, {"Zitrusdünger", "Mit Eisen und Magnesium gegen gelbe Blätter."}, {"柑橘用肥料", "葉の黄変を防ぐ鉄・マグネシウム入り。"}},
	"none":     {{"No fertiliser needed", "This plant does best unfed."}, {"Não precisa de adubo", "Essa planta vai melhor sem adubo."}, {"No necesita fertilizante", "Esta planta está mejor sin abono."}, {"Pas d'engrais", "Cette plante se porte mieux sans engrais."}, {"Kein Dünger nötig", "Diese Pflanze mag es ungedüngt."}, {"肥料は不要", "この植物は肥料なしで元気に育ちます。"}},
}

var potText = map[string][6][2]string{ // material → lang → {name, why}
	"terracotta": {{"Terracotta pot with a drainage hole", "Breathes and dries fast, good for plants that hate wet feet."}, {"Vaso de barro com furo", "Respira e seca rápido, bom pra quem odeia pé molhado."}, {"Maceta de barro con agujero", "Transpira y seca rápido, ideal para las que odian el exceso de agua."}, {"Pot en terre cuite percé", "Il respire et sèche vite, idéal pour les plantes qui craignent l'humidité."}, {"Terrakottatopf mit Abzugsloch", "Atmet und trocknet schnell, gut gegen nasse Füße."}, {"底穴のある素焼き鉢", "通気がよく乾きやすいので、過湿が苦手な植物に。"}},
	"plastic":    {{"Plastic or glazed pot with a drainage hole", "Holds moisture longer, good for plants that like to stay damp."}, {"Vaso plástico ou esmaltado com furo", "Segura umidade por mais tempo, bom pra quem gosta de terra úmida."}, {"Maceta de plástico o esmaltada con agujero", "Retiene la humedad más tiempo, ideal para las que la prefieren húmeda."}, {"Pot plastique ou émaillé percé", "Garde l'humidité plus longtemps, idéal pour les plantes qui aiment le frais."}, {"Kunststoff- oder glasierter Topf mit Loch", "Hält länger feucht, gut für Pflanzen, die es feucht mögen."}, {"底穴のあるプラ鉢・釉薬鉢", "水もちがよく、湿り気を好む植物に。"}},
	"orchid":     {{"Clear orchid pot with side holes", "Lets light and air reach the roots."}, {"Vaso transparente pra orquídea", "Deixa luz e ar chegarem nas raízes."}, {"Maceta transparente para orquídeas", "Deja llegar luz y aire a las raíces."}, {"Pot transparent pour orchidées", "Laisse la lumière et l'air atteindre les racines."}, {"Transparenter Orchideentopf", "Lässt Licht und Luft an die Wurzeln."}, {"透明な洋ラン鉢", "根に光と空気が届きます。"}},
}

var sizeText = [6][2]string{ // {with diameter "%d cm", without}
	{"Next pot: about %d cm across, when it's time to repot.", "Next pot: 2–5 cm wider than the current one."},
	{"Próximo vaso: uns %d cm de diâmetro, quando for hora de trocar.", "Próximo vaso: 2 a 5 cm mais largo que o atual."},
	{"Próxima maceta: unos %d cm de diámetro, cuando toque trasplantar.", "Próxima maceta: 2–5 cm más ancha que la actual."},
	{"Prochain pot : environ %d cm de diamètre, au moment du rempotage.", "Prochain pot : 2 à 5 cm plus large que l'actuel."},
	{"Nächster Topf: etwa %d cm Durchmesser, wenn umgetopft wird.", "Nächster Topf: 2–5 cm breiter als der jetzige."},
	{"次の鉢：植え替えのときに直径約%dcm。", "次の鉢：今より2〜5cm大きいもの。"},
}

func langIdx(lang string) int {
	switch digestLang(lang) {
	case "pt-BR":
		return 1
	case "es":
		return 2
	case "fr":
		return 3
	case "de":
		return 4
	case "ja":
		return 5
	}
	return 0
}

// loadPlant finds a live plant the caller can reach.
func (s *Server) loadPlant(ctx context.Context, uid, pid string) (jungle string, data map[string]any, err error) {
	err = s.db.AsUser(ctx, uid, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select jungle_id::text, data from records where entity = 'plant' and id = $1 and not deleted
			and jungle_id in (select mtj_my_jungles()) limit 1`, pid).Scan(&jungle, &data)
	})
	return jungle, data, asNotFound(err)
}

type supplyRec struct {
	Kind string `json:"kind"`
	Name string `json:"name"`
	Why  string `json:"why"`
	// Affiliate is a shop link; null until partner shops are set up.
	Affiliate *string `json:"affiliate"`
	Have      bool    `json:"have"` // the owner has this kind in stock above its low mark
}

func potMaterial(sp *species) string {
	switch {
	case sp.Mix == "orchid":
		return "orchid"
	case sp.WaterStyle == "dry" || sp.Group == "succulent" || sp.Mix == "cactus":
		return "terracotta"
	}
	return "plastic"
}

// GET /v1/plants/{id}/supplies?lang=
func (s *Server) plantSupplies(w http.ResponseWriter, r *http.Request) {
	ctx, c, pid := r.Context(), claimsOf(r), r.PathValue("id")
	if !isUUID(pid) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	lang := r.URL.Query().Get("lang")
	if len(lang) > 12 {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	_, data, err := s.loadPlant(ctx, c.Sub, pid)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if theBrain.dir == "" {
		theBrain.dir = s.cfg.ContentDir
	}
	sp := theBrain.findSpecies(str(data, "speciesID"))
	if sp == nil {
		writeErr(w, http.StatusNotFound, "species_unknown")
		return
	}
	li := langIdx(lang)
	stock := map[string]bool{}
	_ = s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select distinct kind from supplies where user_id = $1 and qty > coalesce(low_at, 0)`, c.Sub)
		if err != nil {
			return err
		}
		kinds, _ := pgx.CollectRows(rows, pgx.RowTo[string])
		for _, k := range kinds {
			stock[k] = true
		}
		return nil
	})
	mix := sp.Mix
	if _, ok := mixText[mix]; !ok {
		mix = "universal"
	}
	feed := sp.Feed
	if _, ok := feedText[feed]; !ok {
		feed = "balanced"
	}
	mat := potMaterial(sp)
	var diameter *int
	sizeNote := sizeText[li][1]
	if d, ok := num(data, "potDiameterCm"); ok && d > 0 {
		n := int(math.Round(d + 3))
		diameter = &n
		sizeNote = strings.Replace(sizeText[li][0], "%d", strconv.Itoa(n), 1)
	}
	items := []supplyRec{
		{Kind: "soil", Name: mixText[mix][li][0], Why: mixText[mix][li][1], Have: stock["soil"]},
		{Kind: "pot", Name: potText[mat][li][0], Why: potText[mat][li][1] + " " + sizeNote, Have: stock["pot"]},
	}
	if feed != "none" {
		items = append(items, supplyRec{Kind: "fertiliser", Name: feedText[feed][li][0], Why: feedText[feed][li][1], Have: stock["fertiliser"]})
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"plantId": pid, "species": sp.ID,
		"soil":       map[string]any{"code": mix, "name": mixText[mix][li][0], "recipe": mixText[mix][li][1]},
		"pot":        map[string]any{"material": mat, "name": potText[mat][li][0], "diameterCm": diameter, "repotEveryYears": sp.RepotYears, "note": sizeNote},
		"fertiliser": map[string]any{"code": feed, "name": feedText[feed][li][0], "everyWeeks": sp.FeedWeeks, "note": feedText[feed][li][1]},
		"items":      items,
	})
}

type supply struct {
	ID        string    `json:"id"`
	Kind      string    `json:"kind"`
	Name      string    `json:"name"`
	Qty       float64   `json:"qty"`
	Unit      string    `json:"unit"`
	LowAt     *float64  `json:"lowAt"`
	Low       bool      `json:"low"`
	UpdatedAt time.Time `json:"updatedAt"`
}

// GET /v1/me/supplies
func (s *Server) mySupplies(w http.ResponseWriter, r *http.Request) {
	ctx, c := r.Context(), claimsOf(r)
	var out []supply
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		rows, _ := tx.Query(ctx, `select id::text, kind, name, qty::float8, unit, low_at::float8, low_at is not null and qty <= low_at, updated_at
			from supplies where user_id = $1 order by kind, name`, c.Sub)
		var err error
		out, err = pgx.CollectRows(rows, pgx.RowToStructByPos[supply])
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if out == nil {
		out = []supply{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"supplies": out})
}

// PUT /v1/me/supplies/{id} {kind, name, qty, unit?, lowAt?}: create or replace. Refilling above the low
// mark re-arms the reminder.
func (s *Server) putSupply(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Kind  string   `json:"kind"`
		Name  string   `json:"name"`
		Qty   float64  `json:"qty"`
		Unit  string   `json:"unit"`
		LowAt *float64 `json:"lowAt"`
	}
	ctx, c, id := r.Context(), claimsOf(r), r.PathValue("id")
	kinds := map[string]bool{"soil": true, "fertiliser": true, "pot": true, "pesticide": true, "other": true}
	if decode(r, &in) != nil || !isUUID(id) || !kinds[in.Kind] || strings.TrimSpace(in.Name) == "" || len(in.Name) > 80 || len(in.Unit) > 16 ||
		in.Qty < 0 || in.Qty > 1e6 || (in.LowAt != nil && (*in.LowAt < 0 || *in.LowAt > 1e6)) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	var out supply
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `insert into supplies (id, user_id, kind, name, qty, unit, low_at) values ($1,$2,$3,$4,$5,$6,$7)
			on conflict (id) do update set kind = excluded.kind, name = excluded.name, qty = excluded.qty, unit = excluded.unit,
			  low_at = excluded.low_at, updated_at = now(),
			  low_notified_at = case when excluded.low_at is null or excluded.qty > excluded.low_at then null else supplies.low_notified_at end
			where supplies.user_id = $2
			returning id::text, kind, name, qty::float8, unit, low_at::float8, low_at is not null and qty <= low_at, updated_at`,
			id, c.Sub, in.Kind, strings.TrimSpace(in.Name), in.Qty, in.Unit, in.LowAt).
			Scan(&out.ID, &out.Kind, &out.Name, &out.Qty, &out.Unit, &out.LowAt, &out.Low, &out.UpdatedAt)
	})
	if isNoRows(err) {
		writeErr(w, http.StatusNotFound, "not_found")
		return
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, out)
}

// DELETE /v1/me/supplies/{id}
func (s *Server) deleteSupply(w http.ResponseWriter, r *http.Request) {
	ctx, c, id := r.Context(), claimsOf(r), r.PathValue("id")
	if !isUUID(id) {
		s.fail(w, r, bad("invalid_request"))
		return
	}
	err := s.db.AsUser(ctx, c.Sub, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `delete from supplies where id = $1 and user_id = $2`, id, c.Sub)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

var lowStockText = [6][2]string{ // {title, body with %s = item name}
	{"Running low", "%s is almost gone. Time to restock."},
	{"Tá acabando", "%s tá quase no fim. Bora repor?"},
	{"Se está acabando", "Queda poco de %s. Hora de reponer."},
	{"Bientôt épuisé", "Il ne reste presque plus de %s. Pense à en racheter."},
	{"Fast leer", "%s ist fast aufgebraucht. Zeit nachzukaufen."},
	{"残りわずか", "%sがもうすぐなくなります。補充しましょう。"},
}

// suppliesLoop sends low-stock reminders every hour: one push per drop below the mark.
func (s *Server) suppliesLoop(ctx context.Context) {
	t := time.NewTicker(time.Hour)
	defer t.Stop()
	for {
		s.suppliesRound(ctx)
		select {
		case <-ctx.Done():
			return
		case <-t.C:
		}
	}
}

func (s *Server) suppliesRound(ctx context.Context) {
	if s.pusher == nil || s.db == nil || s.db.Auth == nil {
		return
	}
	rows, err := s.db.Auth.Query(ctx, `update supplies set low_notified_at = now()
		where low_at is not null and qty <= low_at and low_notified_at is null
		returning user_id::text, name`)
	if err != nil {
		return
	}
	type low struct{ User, Name string }
	lows, _ := pgx.CollectRows(rows, pgx.RowToStructByPos[low])
	for _, l := range lows {
		drows, err := s.db.Auth.Query(ctx, `select d.platform, d.push_token, coalesce(d.digest_lang, d.weather_lang, u.locale, 'en')
			from devices d join users u on u.id = d.user_id where d.user_id = $1 and d.push_token is not null and u.deleted_at is null`, l.User)
		if err != nil {
			continue
		}
		type dev struct{ Platform, Token, Lang string }
		devs, _ := pgx.CollectRows(drows, pgx.RowToStructByPos[dev])
		for _, d := range devs {
			t := lowStockText[langIdx(d.Lang)]
			s.pusher.alertLink(ctx, d.Platform, d.Token, t[0], strings.Replace(t[1], "%s", l.Name, 1), "supplies", "mytinyjungle://supplies")
		}
	}
}
