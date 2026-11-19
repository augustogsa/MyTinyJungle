#!/usr/bin/env python3
"""Adds everyday phrasings in pt-BR, es, fr, de and ja to knowledge.json keywords (symptoms, pests, diseases,
deficiencies, topics) so the brain matches questions asked in any of our languages. Idempotent."""
import json, pathlib
p = pathlib.Path(__file__).resolve().parents[3] / "Content/data/knowledge.json"
K = {
 "leaf-miners": "tunnels in leaves|wavy lines|trails inside leaf|túneis nas folhas|caminhos nas folhas|minador|túneles en las hojas|minador de hojas|galeries dans les feuilles|mineuse|Miniermotte|Gänge in den Blättern|Minierfliege|葉に白い線|ハモグリバエ|絵かき虫",
 "downy-mildew": "grey fuzz underneath|fuzz under the leaf|míldio|mofo embaixo da folha|mildiu|pelusa gris debajo|duvet gris dessous|Falscher Mehltau|grauer Flaum unten|べと病|裏に灰色のカビ",
 "whitefly": "white flies|tiny white flies|fly up when touched|moscas brancas|mosquinhas brancas|mosquitas blancas|mouches blanches|aleurodes|weiße Fliegen|白い虫が飛ぶ|コナジラミ|mosca-branca|mosca blanca|aleurode|mouche blanche|Weiße Fliege|コナジラミ",
 "thrips": "silvery streaks|silver streaks|black dots|riscos prateados|rayas plateadas|traînées argentées|silbrige Streifen|銀色のすじ|アザミウマ|tripes|trips|thrips|Thripse|アザミウマ|スリップス",
 "scale": "brown bumps|bumps on stems|carapaças|bolinhas marrons grudadas|escamas marrones|bultitos marrones|bosses brunes|Höcker|braune Schilde|茶色いぽつぽつ|カイガラムシ|cochonilha de escama|carapaça|escamas|cochinilla de escudo|escama|cochenille à bouclier|Schildlaus|Schildläuse|カイガラムシ",
 "aphids": "tiny bugs on new growth|bugs on new shoots|clustered bugs|bichinhos nos brotos|piolho de planta|bichitos en los brotes|bestioles sur les jeunes pousses|Tierchen an den Trieben|新芽に虫|アブラムシ|pulgão|pulgões|pulgón|pulgones|puceron|pucerons|Blattlaus|Blattläuse|アブラムシ",
 "sunburn": "bleached patches|scorched by sun|moved into the sun|queimou no sol|mancha clara depois do sol|quemada por el sol|décolorée au soleil|brûlée par le soleil|ausgebleicht|Sonnenbrand|日焼け|葉焼け|queimada de sol|quemadura de sol|brûlure soleil|Sonnenbrand|葉焼け",
 "yellow-lower": "folhas amarelas embaixo|folha amarelando|amarelando|hojas amarillas|hojas de abajo amarillas|amarillean|feuilles jaunes|jaunissent|jaunissement|gelbe Blätter|untere Blätter gelb|vergilben|葉が黄色|黄色くなる|黄変",
 "yellow-all": "planta toda amarela|toda amarela|toda amarilla|toute jaune|ganz gelb|全体が黄色",
 "brown-tips": "pontas marrons|pontas secas|ponta queimada|puntas marrones|puntas secas|bout des feuilles brun|pointes brunes|pointes sèches|braune Spitzen|Blattspitzen braun|trockene Spitzen|葉先が茶色|葉の先が茶色|葉先が枯れ|先が枯れ",
 "brown-tips-only": "pontas marrons|puntas marrones|pointes brunes|braune Blattspitzen|葉先が茶色",
 "brown-edges": "bordas secas|bordes secos|bords secs|trockene Ränder|縁が枯れ",
 "droop-dry": "murcha|murchando|caída|marchita|mustia|flétrie|ramollie|schlapp|welk|しおれ|しなしな",
 "droop-wet": "murcha com terra molhada|marchita con tierra mojada|flétrie terre mouillée|welk trotz nasser Erde|土が湿っているのにしおれる",
 "leggy": "esticando|estiolada|comprida|crescendo pra janela|se estira|ahilada|estirando|s'étiole|étiolée|file vers la lumière|vergeilt|vergeilen|lang und dünn|徒長|ひょろひょろ|ひょろ長い",
 "reaching": "indo pra janela|virando pra luz|hacia la ventana|vers la fenêtre|zum Fenster|窓の方へ伸び",
 "leaf-drop": "folhas caindo|caindo folhas|se le caen las hojas|hojas caen|perd ses feuilles|feuilles tombent|verliert Blätter|Blätter fallen|葉が落ちる|落葉",
 "curling": "folhas enrolando|hojas enrolladas|se enrollan|feuilles enroulées|s'enroulent|Blätter rollen sich|丸まる|葉が巻く",
 "white-powder": "pó branco|polvo blanco|poudre blanche|weißer Belag|Mehltau|白い粉|うどんこ",
 "powdery-mildew": "oídio|pó branco|polvo blanco|oidio|blanc|oïdium|poudre blanche|Echter Mehltau|weißer Belag|mehlig|うどんこ病|白い粉",
 "sticky": "folha grudenta|grudenta|melada|pegajosa|pegajosas|melaza|collante|collantes|miellat|klebrig|Honigtau|ベタベタ|べたつく",
 "sticky-leaves": "folhas grudentas|hojas pegajosas|feuilles collantes|klebrige Blätter|葉がベタベタ",
 "webbing": "teia|teias|telaraña|telarañas|toile|toiles|Gespinst|Gespinste|Spinnweben|クモの巣|蜘蛛の巣",
 "spider-mites": "ácaro|ácaros|ácaro-rajado|araña roja|arañita|ácaros|araignée rouge|acariens|tétranyques|Spinnmilben|Rote Spinne|ハダニ|クモの巣|小さな点",
 "white-fluff": "algodão|algodãozinho|bolinhas brancas|cochonilha-farinhenta|algodón|algodoncillo|pelusa blanca|cochinilla algodonosa|coton|cotonneux|cochenille farineuse|wattig|Watte|Wollläuse|白い綿|綿のよう|コナカイガラムシ",
 "mealybugs": "cochonilha|cochonilha-farinhenta|algodão nos caules|cochinilla|cochinilla algodonosa|algodón|cochenille|cochenilles farineuses|cotonneux|Wolllaus|Schmierläuse|Wollläuse|wattige Flocken|コナカイガラムシ|カイガラムシ|白い綿",
 "fungus-gnats": "mosquinha|mosquinhas|mosquitinho|mosquinhas pretas|mosquitas|mosquitos negros|mosca del mantillo|moucherons|mouchettes|sciarides|Trauermücken|kleine Fliegen|Fliegen aus der Erde|コバエ|キノコバエ|小さい虫",
 "tiny-flies": "mosquinhas na terra|mosquitas en la tierra|moucherons dans la terre|Fliegen in der Erde|土から虫|コバエ",
 "root-rot": "raiz podre|raízes podres|raiz mole|raízes moles|cheiro ruim|apodrecendo|pudrición de raíz|raíces podridas|raíces blandas|huelen mal|pourriture des racines|racines molles|racines pourries|sentent mauvais|Wurzelfäule|Wurzeln matschig|faulig|riechen|根腐れ|根がぶよぶよ|臭い|mushy roots|roots smell|rotten roots|smelly roots",
 "root-rot-rescue": "salvar raiz podre|rescatar raíces podridas|sauver racines pourries|Wurzelfäule retten|根腐れ 対処",
 "overwatering-signs": "rega demais|água demais|exceso de riego|demasiada agua|trop arrosé|trop d'eau|zu viel gegossen|Staunässe|水のやりすぎ|過湿",
 "underwatering-signs": "falta de água|pouca água|falta de riego|manque d'eau|zu wenig gegossen|水不足",
 "prop-water": "muda na água|fazer muda|enraizar na água|estaca na água|esqueje en agua|enraizar en agua|bouture dans l'eau|faire raciner|bouturage à l'eau|Steckling im Wasser|bewurzeln|Ableger im Wasser|水挿し|挿し木|発根|水で発根",
 "prop-soil": "muda na terra|estaca na terra|esqueje en tierra|bouture en terre|Steckling in Erde|土に挿し木",
 "watering-winter": "regar no inverno|rega no inverno|rego no inverno|regar en invierno|riego en invierno|riego invierno|arroser en hiver|arrosage hiver|fréquence arroser hiver|gießen im Winter|Winter gießen|冬の水やり|冬 水やり",
 "watering-summer": "regar no verão|regar en verano|arroser en été|gießen im Sommer|夏の水やり",
 "watering-how-much": "quanto regar|quanta água|cuánta agua|cuánto regar|combien d'eau|wie viel gießen|水の量|どれくらい水",
 "finger-test": "quando regar|cuándo regar|quand arroser|wann gießen|いつ水やり|水やりのタイミング",
 "repot-signs": "trocar de vaso|troco de vaso|troca de vaso|replantar|vaso maior|trasplantar|cambiar de maceta|maceta más grande|rempoter|rempotage|pot plus grand|umtopfen|größerer Topf|Umtopfen wann|植え替え|鉢替え|大きい鉢",
 "repot-how": "como trocar de vaso|cómo trasplantar|comment rempoter|wie umtopfen|植え替え方",
 "pet-safety": "tóxica pra gato|tóxica para gato|venenosa|cachorro|tóxica para gatos|perros|toxique chat|toxique chien|giftig Katze|giftig Hund|giftig für Katzen|猫に毒|犬に毒|ペット 安全|有毒",
 "pet-friendly": "segura pra pets|segura para mascotas|sans danger animaux|haustierfreundlich|ペットに安全",
 "humidity-raise": "aumentar umidade|aumento a umidade|umidade do ar|ar seco|subir humedad|subo la humedad|humedad|aire seco|augmenter l'humidité|humidité|air sec|Luftfeuchtigkeit erhöhen|Luftfeuchtigkeit|trockene Luft|湿度を上げる|湿度|乾燥",
 "light-signs": "pouca luz|falta de luz|poca luz|falta de luz|manque de lumière|zu wenig Licht|光不足|日照不足",
 "low-light-plants": "planta pra sombra|lugar escuro|plantas de sombra|poca luz|plantes d'ombre|peu de lumière|Schattenpflanzen|wenig Licht|日陰 植物|暗い部屋",
 "feeding-basics": "adubar|adubo|fertilizante|abonar|abono|fertilizar|engrais|fertiliser|düngen|Dünger|肥料|追肥",
 "fungus-gnats-guide": "",
 "gnats-guide": "mosquinhas|mosquitas|moucherons|Trauermücken|コバエ",
 "mealybug-guide": "cochonilha|cochinilla|cochenille|Wollläuse|コナカイガラムシ",
 "spider-mites-guide": "ácaros|araña roja|acariens|Spinnmilben|ハダニ",
 "leggy-fix": "planta esticada|ahilada|étiolée|vergeilt|徒長",
 "brown-tips-guide": "pontas marrons|puntas marrones|pointes brunes|braune Spitzen|葉先 茶色",
 "leaf-yellow-guide": "folhas amarelas|hojas amarillas|feuilles jaunes|gelbe Blätter|黄色い葉",
 "cold-damage": "frio|queimada de frio|daño por frío|dégâts du froid|Kälteschaden|寒さ|低温障害",
 "leaf-spot": "manchas nas folhas|manchas marrons|manchas en las hojas|taches sur les feuilles|Blattflecken|斑点",
 "black-spots": "manchas pretas|manchas negras|taches noires|schwarze Flecken|黒い斑点",
 "mould-soil": "mofo na terra|moho en la tierra|moisissure terre|Schimmel auf der Erde|土にカビ",
 "slugs": "lesma|babosa|limace|Schnecke|ナメクジ",
 "holes": "furos nas folhas|agujeros en las hojas|trous dans les feuilles|Löcher in Blättern|葉に穴",
 "nitrogen": "falta de nitrogênio|deficiencia de nitrógeno|carence en azote|Stickstoffmangel|窒素不足",
 "iron": "falta de ferro|clorose|deficiencia de hierro|clorosis|carence en fer|chlorose|Eisenmangel|Chlorose|鉄欠乏",
}
k = json.loads(p.read_text())
seen = set()
for sec in ("symptoms", "pests", "diseases", "deficiencies", "topics"):
    for e in k[sec]:
        add = [w.strip() for w in K.get(e["id"], "").split("|") if w.strip()]
        if not add:
            continue
        seen.add(e["id"])
        kw = e.setdefault("keywords", [])
        for w in add:
            if w not in kw:
                kw.append(w)
missing = [i for i, v in K.items() if v and i not in seen]
assert not missing, missing
p.write_text(json.dumps(k, ensure_ascii=False, indent=1) + "\n")
print("keywords for", len(seen), "entries")
