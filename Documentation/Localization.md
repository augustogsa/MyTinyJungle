# Localization

My Tiny Jungle ships in English (source), Brazilian Portuguese (pt-BR), Latin American Spanish (es), French (fr), German (de) and Japanese (ja). Erty is Raminho (pt-BR, pt-PT), Brotito (es), Poussi (fr), Knospi (de) and めぶき (ja); only English keeps Erty.

Bulk translations land as `Tools/l10n/staging/<lang>.json` and merge with `python3 Tools/l10n/merge_staging.py es fr de ja` (new keys go in `staging/new-strings.json`). App Store listings are ready in `Tools/appstore/<locale>.json` and go live only when the owner says so.

## The one rule: native, never literal

Every language must read as if a native plant lover from that country wrote the app. Translate the meaning, the warmth and the joke, not the words. If a sentence would sound odd said out loud by a friend in a garden center, rewrite it. Use the plant names people actually use there, local seasons and climate, metric units, and the local date and number formats (these come from `FormatStyle`, never hand-written).

## Where text lives

| Text | Where | How it is localized |
|---|---|---|
| UI, chat, plant voices, CareEngine, notifications, paywall, ads labels | `MyTinyJungle/Localizable.xcstrings` | SwiftUI literals and `String(localized:comment:)` |
| Notification content extension | `NotificationContent/Localizable.xcstrings` | same |
| Permission prompts, display name | `MyTinyJungle/InfoPlist.xcstrings` | Info.plist keys |
| Species names, about, tips, problems; knowledge.json (soils, pests, glossary, lessons) | `Content/data/locales/<lang>.json` | `L10nData.localize` swaps text when the JSON loads |
| App Store listing, subscription, screenshot captions, What's New | `Tools/appstore/<lang>.json` | `node Tools/appstore/push.mjs <lang> --apply` |
| Website | `Website/build.py`, `Website/home_content.py` | per-language dicts, `/pt/` for Portuguese |

Keys are the English source strings (Apple's default), which keeps call sites readable and keys stable as long as the copy is stable. Changing English copy creates a new key; run `sync`, then translate it.

### Code rules
- Never build a sentence from pieces. One `String(localized: "…\(x)…", comment:)` per sentence.
- Every `String(localized:)` has a `comment` with context, tone and a length limit when it is a button, label or notification title.
- Counts: use an `Int` interpolation (`%lld`) and give plural variants (`one`/`other`) in the catalog for every language, English included.
- Lists: `.formatted(.list(type: .and))`. Dates: `Date.FormatStyle` / `.relative(presentation: .named)`. Temperatures and lengths: `Measurement` with the user's unit preference.
- Identifiers, analytics names, UserDefaults keys, SF Symbol names and log lines are not user-facing; if the checker flags one, add it to `Tools/l10n/allowlist.txt`.
- Chat parsing (`ChatParser`, `Answerer`, `ProductAnalyzer`) must understand each shipped language's everyday words too.

## Tone guide

### English
Warm, light, friendly; short sentences; plants are characters with moods.

### Português (Brasil)
- "Você", never "tu" or "o senhor". Affectionate diminutives in moderation: "suas plantinhas", "uma regadinha", "sua selvinha".
- Brazilian everyday words: celular, tela, câmera, toque, salvar, compartilhar, aplicativo/app, notificação. Avoid pt-PT (câmara, ecrã, fototeca, partilhar, telemóvel, "regar a planta de", "consigo").
- Seasons: think Southern Hemisphere and Brazilian climate (verão quente e úmido, inverno seco no Centro-Sul, estação das chuvas). Don't assume snow.
- Plant personalities stay vivid: the calathea is "dramática", the succulent is "de boa", the costela-de-adão is "tranquilona", the samambaia "adora uma umidade".
- Length: buttons and notification titles no more than ~20% longer than English.

## Glossary (en → pt-BR)

| English | pt-BR | Notes |
|---|---|---|
| My Tiny Jungle | My Tiny Jungle | brand, never translated |
| My Tiny Jungle Plus / Plus | My Tiny Jungle Plus / Plus | brand |
| Erty (mascot) | Raminho | mascot name is localized per language: pick a name natives find cute |
| your jungle | sua selvinha / sua mini selva | prose only |
| Today / Plants / Care / Scan / Me | Hoje / Plantas / Cuidados / Escanear / Você | tabs |
| water / watering | regar / rega | "dar uma regadinha" in casual copy |
| mist | borrifar | |
| fertilize / feed / fertilizer | adubar / adubo | "fertilizante" only on product labels |
| potting mix / soil | substrato / terra | substrato in technical, terra in casual |
| repot | trocar de vaso / replantar | |
| pot | vaso | |
| drainage hole | furo de drenagem | |
| cutting / propagate | muda / estaca / fazer mudas | |
| bright indirect light | luz indireta forte / claridade | |
| partial shade | meia-sombra | |
| direct sun | sol direto / sol pleno | |
| humidity | umidade | |
| pests | pragas | |
| mealybugs / spider mites / aphids / scale / fungus gnats / thrips | cochonilha-farinhenta / ácaro-rajado / pulgão / cochonilha-de-carapaça / mosquinha-do-fungo / tripes | |
| root rot | podridão das raízes | |
| frost / heat wave | geada / onda de calor | |
| plant sitter | quem cuida das suas plantas | "alguém de confiança" |
| reminder | lembrete | |
| Sponsored | Patrocinado | ad label |
| Monstera deliciosa | Costela-de-adão | |
| Pothos (Epipremnum aureum) | Jiboia | |
| Snake plant (Dracaena trifasciata) | Espada-de-são-jorge | |
| ZZ plant | Zamioculca | |
| Peace lily | Lírio-da-paz | |
| Fiddle-leaf fig | Figueira-lira | |
| Aloe vera | Babosa | |
| Spider plant | Clorofito | |
| Boston fern | Samambaia | |

## Adding a new language (repeatable)

1. Add the code to `knownRegions` in `MyTinyJungle.xcodeproj/project.pbxproj` and to `LANGS` in `Tools/l10n/l10n.py`.
2. Add a tone guide and glossary column above, written by a native speaker.
3. Build once (`xcodebuild … -derivedDataPath build/dd build`), then `python3 Tools/l10n/l10n.py sync`.
4. `python3 Tools/l10n/l10n.py missing <lang>` writes everything to translate (catalog keys, knowledge strings, species ids) to `build/l10n-missing-<lang>.json`.
5. Translate into fragments (`{"key": {"<lang>": "…"}}`, plurals as `{"one","other",…}` per CLDR) and run `python3 Tools/l10n/l10n.py merge <lang> fragments/*.json`.
6. Translate knowledge text (`{"English": "…"}`) and species names (`names-*.json`: `{"id": "Name"}`), then `python3 Tools/l10n/l10n.py data <lang> text.json names.json`.
7. Write `Tools/appstore/<lang>.json` (copy `pt-BR.json`) and push with `node Tools/appstore/push.mjs <lang> --apply`.
8. Add the language to the website dicts in `Website/build.py`.
9. Gate: `python3 Tools/l10n/l10n.py check` must print `✓ localization complete`.
10. Verify on the simulator with `-AppleLanguages "(<lang>)" -AppleLocale <locale>`: every tab, sheet, paywall, notification and plant chat.

## Checklist before shipping a language
- [ ] `l10n.py check` passes (no missing keys, data, names, or escaped literals).
- [ ] Release build clean.
- [ ] Read every screen on the simulator in that language; nothing truncated, nothing in English except brand names.
- [ ] Notifications (each kind, actions, content extension) and plant chat replies checked.
- [ ] Dates, numbers, temperatures and units follow the locale.
- [ ] App Store listing, keywords and screenshot captions pushed; website language reviewed.
- [ ] Release note added.
