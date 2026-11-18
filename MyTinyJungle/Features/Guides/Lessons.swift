import SwiftUI

/// Little lessons: cosy, plant-parent explainers built from the knowledge base.
extension GuideLibrary {
    private static let blue = Color(red: 0.27, green: 0.5, blue: 0.72)
    private static let teal = Color(red: 0.25, green: 0.55, blue: 0.55)
    private static let plum = Color(red: 0.55, green: 0.35, blue: 0.55)
    private static let gold = Color(red: 0.72, green: 0.56, blue: 0.2)

    private static func lesson(_ id: String, _ title: String, _ sub: String, _ symbol: String, _ tint: Color, _ min: Int,
                               _ level: CareGuide.Level = .easy, tools: [String] = [], when: String, logs: CareKind? = nil,
                               _ steps: [CareGuide.Step]) -> CareGuide {
        CareGuide(id: id, title: title, subtitle: sub, symbol: symbol, tint: tint, minutes: min, level: level, tools: tools, when: when, logs: logs, steps: steps)
    }
    private typealias S = CareGuide.Step

    static let lessons: [CareGuide] = [
        lesson("light-read", "Read the light in your home", "Bright, medium or low?", "sun.max.fill", gold, 3, when: "Before choosing a spot for a new plant.", [
            S(title: "The shadow test", detail: "Hold your hand a foot above the spot at midday. A crisp shadow means bright light, a soft one medium, barely any means low.", symbol: "hand.raised.fill"),
            S(title: "Window direction", detail: "South-facing windows (north in the southern hemisphere) bring the most sun; east gives gentle mornings; west gives hot afternoons; north is soft all day.", symbol: "safari.fill"),
            S(title: "Distance matters", detail: "Light fades fast. Two metres from a window can be a quarter of the light right beside it.", symbol: "ruler.fill", tip: "If you can comfortably read a book there without a lamp, most leafy plants will cope."),
            S(title: "Watch the plant", detail: "Stretching and small leaves ask for more light. Bleached or crispy patches ask for less.", symbol: "eye.fill"),
        ]),
        lesson("soil-mixes", "Build the perfect soil mix", "Air, water and a little food", "square.stack.3d.down.right.fill", Jungle.terracotta, 6, .medium,
               tools: ["Potting compost", "Perlite or pumice", "Orchid bark", "A bucket"], when: "When repotting, or if your soil stays soggy.", [
            S(title: "Know your plant's style", detail: "Climbing jungle plants want chunky, airy mixes. Desert plants want gritty, fast-draining ones. Ferns want something that stays gently damp.", symbol: "leaf.fill"),
            S(title: "Start with a base", detail: "Peat-free compost or coco coir holds water and gives roots something soft to grow into.", symbol: "square.fill"),
            S(title: "Add air", detail: "Perlite, pumice or bark make pockets of air. Roots breathe there, and that's what keeps rot away.", symbol: "bubbles.and.sparkles.fill", tip: "Aroid mix: about one third bark, a quarter coir, a quarter perlite."),
            S(title: "Squeeze test", detail: "Dampen a handful and squeeze. It should hold together, then crumble when poked. If water drips, add more grit or bark.", symbol: "hand.raised.fingers.spread.fill"),
        ]),
        lesson("soil-ph", "Why soil pH matters", "Sweet, sour and in between", "testtube.2", plum, 3, when: "For azaleas, camellias, blueberries and hydrangeas especially.", [
            S(title: "What it is", detail: "pH tells you how acidic soil is. Most houseplants are happy around 6 to 7, just a touch acidic.", symbol: "number"),
            S(title: "The lime-haters", detail: "Azaleas, camellias, gardenias and blueberries need 4.5 to 6. In chalky soil their leaves turn yellow with green veins.", symbol: "drop.triangle.fill"),
            S(title: "Keep it gentle", detail: "Use ericaceous compost and rainwater for acid lovers. Hard tap water slowly raises pH.", symbol: "cloud.rain.fill", tip: "Blue hydrangeas stay blue only in acidic soil."),
        ]),
        lesson("npk", "Plant food, simply explained", "What N, P and K mean", "leaf.arrow.triangle.circlepath", Jungle.leaf, 4, when: "Before buying fertilizer.", [
            S(title: "Three numbers", detail: "Every bottle shows N-P-K. Nitrogen grows leaves, phosphorus supports roots, potassium helps flowers and fruit.", symbol: "textformat.123"),
            S(title: "Match the plant", detail: "Leafy plants like a balanced feed. Flowering and fruiting plants like more potassium. Cacti want little nitrogen.", symbol: "leaf.fill"),
            S(title: "Weaker is kinder", detail: "Half strength is plenty for most houseplants. Too much food burns roots and browns leaf tips.", symbol: "drop.halffull", tip: "Always water first, then feed. Never feed dry roots."),
            S(title: "Let them rest", detail: "Pause feeding from mid-autumn to early spring. Resting plants can't use it and the salts pile up.", symbol: "moon.zzz.fill"),
        ]),
        lesson("flush", "Rinse out salty soil", "A spa day for roots", "water.waves", blue, 5, tools: ["Sink or shower", "Room-temperature water"], when: "Every 2–3 months, or when you see white crust on the soil.", logs: .water, [
            S(title: "Spot the signs", detail: "A white crust on the soil or pot rim, and brown leaf tips, mean salts from tap water and food have built up.", symbol: "eye.fill"),
            S(title: "Slow, deep rinse", detail: "Run water through the pot for a minute or two, about three times the pot's volume.", symbol: "shower.fill", seconds: 90),
            S(title: "Drain fully", detail: "Let it drip until it stops before it goes back in its cover pot.", symbol: "drop.fill", tip: "Skip feeding for two weeks afterwards."),
        ]),
        lesson("humidity", "Give tropical plants humid air", "Grouping beats misting", "humidity.fill", teal, 3, when: "In winter, when heating dries the air.", [
            S(title: "Who needs it", detail: "Calatheas, ferns, alocasias and orchids grew up in steamy forests. Below about 50% their edges crisp.", symbol: "leaf.fill"),
            S(title: "Group them", detail: "Plants breathe out moisture. Clustered together, they make their own little cloud.", symbol: "square.grid.2x2.fill"),
            S(title: "Pebble tray", detail: "A tray of wet pebbles under the pot adds a little moisture right where it's needed. Keep the pot above the water.", symbol: "circle.grid.3x3.fill"),
            S(title: "Humidifier", detail: "The most reliable fix. Misting feels nice but only lasts minutes.", symbol: "wind", tip: "Bathrooms and kitchens with a window are natural spas."),
        ]),
        lesson("winter", "Help plants through winter", "Less water, more light", "snowflake", blue, 3, when: "From late autumn.", [
            S(title: "Water less", detail: "Short days slow growth, so soil stays wet much longer. Always feel before watering.", symbol: "drop"),
            S(title: "Move closer to the light", detail: "Shift plants nearer to windows, but not touching cold glass.", symbol: "sun.min.fill"),
            S(title: "Mind the heat", detail: "Radiators and heaters dry the air. Keep pots a metre away.", symbol: "heater.vertical.fill"),
            S(title: "Pause the food", detail: "No feeding until spring for most plants. Citrus keeps a light winter feed.", symbol: "moon.zzz.fill", tip: "Cacti like a cool, dry winter: it's what makes them flower."),
        ]),
        lesson("spring", "Wake your jungle in spring", "Fresh start season", "leaf.fill", Jungle.leaf, 4, when: "When new leaves appear.", [
            S(title: "Check the roots", detail: "Roots circling the pot or poking out below mean it's repotting time.", symbol: "arrow.up.bin.fill"),
            S(title: "Start feeding", detail: "Begin with a half-strength feed and build up as growth speeds up.", symbol: "leaf.arrow.triangle.circlepath"),
            S(title: "Tidy up", detail: "Snip dead leaves and leggy stems. Every cut can become a new plant.", symbol: "scissors"),
            S(title: "Clean the leaves", detail: "Winter dust blocks light. A gentle shower freshens everyone up.", symbol: "shower.fill"),
        ]),
        lesson("summer-holiday", "Going on holiday", "Keep plants happy while you're away", "suitcase.fill", gold, 5, when: "Before a trip of more than a week.", [
            S(title: "Water deeply", detail: "Give everyone a good soak the day before you leave.", symbol: "drop.fill"),
            S(title: "Move back from windows", detail: "Less sun means slower drying. A metre back makes a real difference.", symbol: "arrow.backward"),
            S(title: "Group in a cool room", detail: "Together on a tray of damp pebbles, they share humidity.", symbol: "square.grid.2x2.fill"),
            S(title: "Wick watering", detail: "A cotton cord from a jug of water into the soil keeps thirsty plants topped up.", symbol: "line.diagonal", tip: "Succulents and ZZ plants will happily wait three weeks."),
        ]),
        lesson("overwater", "Rescue an overwatered plant", "Dry the roots, save the plant", "cross.case.fill", Jungle.terracotta, 15, .careful, tools: ["Clean scissors", "Fresh mix", "Newspaper"], when: "Yellow leaves, soggy soil, a sour smell.", logs: .repot, [
            S(title: "Slide it out", detail: "Ease the plant out of its pot and look at the roots.", symbol: "arrow.up.bin.fill"),
            S(title: "Sort the roots", detail: "Healthy roots are firm and pale. Rotten ones are brown, mushy and smell. Snip those away.", symbol: "scissors", tip: "Wipe the blades with alcohol between cuts."),
            S(title: "Fresh, airy home", detail: "Repot into fresh, chunkier mix in a pot with drainage holes, only as big as the root ball.", symbol: "square.stack.3d.down.right.fill"),
            S(title: "Wait to water", detail: "Give it a few days, then water lightly. Keep it in bright, indirect light while it recovers.", symbol: "clock.fill"),
        ]),
        lesson("underwater", "Revive a thirsty plant", "The bottom-soak trick", "drop.triangle.fill", blue, 30, tools: ["Sink or bowl"], when: "Soil pulled away from the pot, drooping leaves.", logs: .water, [
            S(title: "Soak from below", detail: "Stand the pot in a few centimetres of water for 20–30 minutes so dry soil can drink again.", symbol: "water.waves", seconds: 1200),
            S(title: "Drain", detail: "Let all extra water run out.", symbol: "drop.fill"),
            S(title: "Be patient", detail: "Leaves usually perk up within a day. Crispy ones won't recover, so trim them once new growth appears.", symbol: "heart.fill"),
        ]),
        lesson("propagate-water", "Root cuttings in water", "Watch roots grow", "drop.circle.fill", teal, 10, tools: ["Clean scissors", "Glass jar"], when: "Spring and summer.", logs: .propagate, [
            S(title: "Find a node", detail: "The little bump where a leaf joins the stem is where roots come from. Cut just below one.", symbol: "scissors"),
            S(title: "Into the jar", detail: "Put the node under water, leaves above. Bright, indirect light.", symbol: "drop.fill"),
            S(title: "Fresh water weekly", detail: "Change the water every week so it stays clear.", symbol: "arrow.triangle.2.circlepath"),
            S(title: "Pot it up", detail: "When roots reach 3–5 cm, plant into a small pot of moist mix.", symbol: "arrow.up.bin.fill", tip: "Pothos, philodendron, tradescantia and monstera root easily this way."),
        ]),
        lesson("propagate-leaf", "Grow succulents from leaves", "Patience and a sunny sill", "leaf.circle.fill", Jungle.leaf, 5, tools: ["Shallow tray", "Gritty mix"], when: "Spring and summer.", logs: .propagate, [
            S(title: "Twist off a leaf", detail: "Gently wiggle off a whole, plump leaf, including its base.", symbol: "hand.pinch.fill"),
            S(title: "Let it heal", detail: "Leave it on a dry surface for 2–3 days until the end seals over.", symbol: "clock.fill"),
            S(title: "Lay it on soil", detail: "Rest it on gritty mix in bright light. Mist the soil lightly once roots appear.", symbol: "sun.max.fill"),
            S(title: "Tiny rosettes", detail: "In a few weeks, a baby plant forms at the base. Let the old leaf shrivel by itself.", symbol: "sparkles"),
        ]),
        lesson("division", "Divide a crowded plant", "One becomes many", "square.split.2x1.fill", Jungle.forest, 20, .medium, tools: ["Clean knife", "Extra pots", "Fresh mix"], when: "Spring, when it fills the pot.", logs: .repot, [
            S(title: "Unpot", detail: "Water the day before, then ease the plant out.", symbol: "arrow.up.bin.fill"),
            S(title: "Find natural gaps", detail: "Look for separate crowns or clumps and tease them apart gently.", symbol: "hand.raised.fingers.spread.fill"),
            S(title: "Cut if needed", detail: "A clean knife through tight roots is fine. Each piece needs leaves and roots.", symbol: "scissors"),
            S(title: "Pot each piece", detail: "Snug pots, fresh mix, and a gentle drink.", symbol: "drop.fill", tip: "Peace lilies, snake plants, ferns and calatheas divide beautifully."),
        ]),
        lesson("air-layer", "Air-layer a tall plant", "Roots in mid-air", "tree.fill", Jungle.forest, 15, .careful, tools: ["Sphagnum moss", "Cling film", "Twist ties"], when: "Spring, for leggy rubber plants and monsteras.", logs: .propagate, [
            S(title: "Pick a spot", detail: "Choose a node about 30 cm below the top. Make a small upward nick or simply find an aerial root.", symbol: "scope"),
            S(title: "Wrap in moss", detail: "Pack damp moss around it and wrap with cling film, tied at both ends.", symbol: "gift.fill"),
            S(title: "Wait for roots", detail: "In 4–8 weeks roots show through the moss.", symbol: "clock.fill"),
            S(title: "Cut and pot", detail: "Cut below the moss ball and plant it whole. The old stem will sprout again.", symbol: "scissors"),
        ]),
        lesson("pest-check", "Weekly pest patrol", "Catch them early", "magnifyingglass", Color(red: 0.75, green: 0.33, blue: 0.27), 3, when: "Once a week, while watering.", [
            S(title: "Flip a leaf", detail: "Most pests hide underneath. Look for webs, white fluff, brown bumps or tiny dots.", symbol: "arrow.uturn.down"),
            S(title: "Check the joints", detail: "Mealybugs love the crooks where leaves meet stems.", symbol: "point.3.connected.trianglepath.dotted"),
            S(title: "Sticky leaves?", detail: "A shiny, sticky film means sap-suckers like scale or aphids are nearby.", symbol: "hand.raised.fill"),
            S(title: "Quarantine new plants", detail: "Keep newcomers apart for two weeks before they join the family.", symbol: "shield.fill", tip: "Yellow sticky traps catch fungus gnats and show you what's flying."),
        ]),
        lesson("fungus-gnats", "Say goodbye to fungus gnats", "Dry the top, trap the flies", "ant.fill", Color(red: 0.75, green: 0.33, blue: 0.27), 5, tools: ["Yellow sticky traps"], when: "Tiny black flies around the soil.", logs: .treat, [
            S(title: "Let it dry", detail: "Gnat larvae need damp compost. Let the top few centimetres dry between waterings.", symbol: "sun.max.fill"),
            S(title: "Set traps", detail: "Sticky traps catch adults before they lay more eggs.", symbol: "rectangle.fill"),
            S(title: "Water from below", detail: "For a few weeks, water from a saucer so the surface stays dry.", symbol: "water.waves"),
            S(title: "Top with grit", detail: "A thin layer of sand or grit makes the surface unwelcoming.", symbol: "circle.grid.3x3.fill"),
        ]),
        lesson("pet-safe", "A pet-friendly jungle", "Plants and paws together", "pawprint.fill", Jungle.peach, 3, when: "If you share your home with cats or dogs.", [
            S(title: "Know the risky ones", detail: "Lilies are very dangerous to cats. Sago palms, oleander and daffodil bulbs are dangerous to all pets. Many aroids cause mouth irritation.", symbol: "exclamationmark.triangle.fill"),
            S(title: "Choose safe friends", detail: "Spider plants, calatheas, parlour palms, peperomias, money trees and African violets are on the ASPCA safe list.", symbol: "checkmark.seal.fill"),
            S(title: "Up and away", detail: "Shelves and hanging pots keep curious mouths away from the rest.", symbol: "arrow.up"),
            S(title: "If they nibble", detail: "Call your vet or a pet poison helpline, and have the plant's name ready.", symbol: "phone.fill", tip: "Every plant page in the app shows its ASPCA status."),
        ]),
        lesson("pots", "Choose the right pot", "Size, holes and material", "cylinder.fill", Jungle.terracotta, 3, when: "When buying or repotting.", [
            S(title: "Drainage first", detail: "Holes at the bottom are essential. A pretty pot without holes can be a cover pot instead.", symbol: "circle.dotted"),
            S(title: "Go up gently", detail: "Choose a pot just 2–5 cm wider. Too much soil stays wet and roots rot.", symbol: "arrow.up.left.and.arrow.down.right"),
            S(title: "Terracotta or plastic?", detail: "Terracotta breathes and dries fast, lovely for succulents. Plastic and glazed pots stay moist longer, kind to ferns.", symbol: "square.on.square"),
        ]),
        lesson("grow-lights", "Grow lights made simple", "Sunshine for dark corners", "lightbulb.fill", gold, 3, when: "For north rooms and winter.", [
            S(title: "Full-spectrum LED", detail: "A white full-spectrum LED looks natural and gives plants everything they need.", symbol: "lightbulb.led.fill"),
            S(title: "Close enough", detail: "Keep it 20–40 cm above the leaves. Light weakens quickly with distance.", symbol: "ruler.fill"),
            S(title: "12 hours a day", detail: "A timer makes it effortless. Plants need dark nights too.", symbol: "timer"),
        ]),
        lesson("orchid-rebloom", "Help an orchid bloom again", "Cool nights, patient days", "camera.macro", plum, 4, when: "After the last flower falls.", [
            S(title: "Trim the spike", detail: "Cut a green spike just above a node to encourage a side branch, or cut a brown one at the base.", symbol: "scissors"),
            S(title: "Weakly, weekly", detail: "Keep feeding at quarter strength while leaves and roots grow.", symbol: "drop.halffull"),
            S(title: "Cool nights", detail: "In autumn, a few weeks of nights 5 °C cooler than days triggers a new spike.", symbol: "moon.stars.fill"),
            S(title: "Leave it be", detail: "Once a spike appears, don't move or turn the plant.", symbol: "hand.raised.fill"),
        ]),
        lesson("succulent-care", "Succulent secrets", "Sun, grit and soak-and-dry", "sun.max.fill", Jungle.leaf, 3, when: "For any cactus or succulent.", [
            S(title: "Maximum light", detail: "The sunniest window you have. Stretching is their way of asking for more.", symbol: "sun.max.fill"),
            S(title: "Soak and dry", detail: "Water deeply, then wait until the soil is completely dry before the next drink.", symbol: "drop.fill"),
            S(title: "Winter rest", detail: "Cool and nearly dry from October to March. This is what makes many cacti flower.", symbol: "snowflake", tip: "Wrinkly leaves mean thirsty. Mushy leaves mean too much water."),
        ]),
        lesson("herbs", "A happy kitchen herb pot", "Pick often, grow more", "leaf.fill", Jungle.leaf, 3, when: "Spring through autumn.", [
            S(title: "Two families", detail: "Rosemary, thyme and sage like sun and lean, gritty soil. Basil, parsley and coriander like rich, moist soil.", symbol: "square.split.2x1.fill"),
            S(title: "Harvest from the top", detail: "Pinch just above a pair of leaves. Two new shoots will grow there.", symbol: "hand.pinch.fill"),
            S(title: "Stop the flowers", detail: "Pinch flower buds on basil and coriander to keep the leaves sweet.", symbol: "xmark.circle.fill"),
        ]),
        lesson("water-quality", "Which water is best?", "Tap, rain or filtered", "drop.fill", blue, 2, when: "For fussy plants with brown tips.", [
            S(title: "Rainwater", detail: "Soft and free. The favourite of calatheas, carnivorous plants and acid lovers.", symbol: "cloud.rain.fill"),
            S(title: "Tap water", detail: "Fine for most plants. Let it stand overnight so it reaches room temperature.", symbol: "drop.fill"),
            S(title: "Filtered or distilled", detail: "A good choice where water is very hard or for plants that brown easily.", symbol: "drop.circle.fill"),
        ]),
        lesson("new-plant", "Welcome a new plant home", "The first two weeks", "house.fill", Jungle.forest, 3, when: "The day a new plant arrives.", [
            S(title: "Quick health check", detail: "Look under leaves and along stems for pests before it meets the others.", symbol: "magnifyingglass"),
            S(title: "Pick its spot", detail: "Match its light needs, then try not to move it while it settles.", symbol: "sun.max.fill"),
            S(title: "Don't repot yet", detail: "Give it two to four weeks to adjust before any big changes.", symbol: "clock.fill"),
            S(title: "Expect a sulk", detail: "A dropped leaf or two is normal. It's getting used to your home.", symbol: "heart.fill"),
        ]),
        lesson("leaf-signs", "What leaves are telling you", "A little leaf language", "text.bubble.fill", teal, 4, when: "Whenever something looks off.", [
            S(title: "Yellow and soft", detail: "Usually too much water, especially lower leaves with damp soil.", symbol: "drop.fill"),
            S(title: "Brown and crispy", detail: "Dry air, missed waterings, or salt build-up.", symbol: "flame.fill"),
            S(title: "Pale and stretched", detail: "Not enough light.", symbol: "sun.min.fill"),
            S(title: "Bleached patches", detail: "Sunburn from sudden strong light.", symbol: "sun.max.trianglebadge.exclamationmark.fill"),
            S(title: "Curling", detail: "Thirst, heat or dry air. Feel the soil first.", symbol: "arrow.uturn.down"),
        ]),
        lesson("outdoor-pots", "Container garden basics", "Balconies and patios", "sun.horizon.fill", gold, 4, when: "Spring planting.", [
            S(title: "Bigger is easier", detail: "Large pots dry out slower and keep roots cooler in summer.", symbol: "cylinder.fill"),
            S(title: "Water daily in heat", detail: "On hot days, pots may need water morning and evening. Check early.", symbol: "drop.fill"),
            S(title: "Feed through summer", detail: "Rain washes nutrients out. A liquid feed every 1–2 weeks keeps flowers coming.", symbol: "leaf.arrow.triangle.circlepath"),
            S(title: "Frost care", detail: "Move tender plants in when nights drop below about 5 °C.", symbol: "thermometer.snowflake"),
        ]),
        lesson("carnivorous", "Caring for carnivorous plants", "Rainwater, sun, and no food", "ant.circle.fill", plum, 3, when: "For flytraps, sundews and pitcher plants.", [
            S(title: "Only rainwater", detail: "Tap water minerals slowly poison them. Rain or distilled water only.", symbol: "cloud.rain.fill"),
            S(title: "Stand in water", detail: "In summer, keep the pot in a saucer of water so the soil never dries.", symbol: "water.waves"),
            S(title: "Never fertilize", detail: "They catch their own food. Fertilizer and compost burn their roots.", symbol: "xmark.octagon.fill"),
            S(title: "Winter sleep", detail: "Venus flytraps need a cool, bright rest from November to February.", symbol: "moon.zzz.fill"),
        ]),
    ]

    /// Lessons generated from the knowledge base: one per plant illness, plus this month's jobs and leaf hunger signs.
    static let knowledgeLessons: [CareGuide] = {
        let k = Knowledge.shared
        var out = k.diseases.map { d in
            lesson("disease-\(d.id)", "Understanding \(d.name.lowercased())", "Spot it, fix it, prevent it", "cross.case.fill", Jungle.terracotta, 3, .medium,
                   when: "If you notice: \(d.signs.prefix(1).lowercased() + d.signs.dropFirst())", logs: .treat, [
                S(title: "What you'll see", detail: d.signs, symbol: "eye.fill"),
                S(title: "Why it happens", detail: d.why, symbol: "questionmark.circle.fill"),
                S(title: "What helps", detail: d.fix, symbol: "cross.case.fill"),
                S(title: "Next time", detail: d.prevent, symbol: "shield.fill"),
            ])
        }
        if !k.deficiencies.isEmpty {
            out.append(lesson("hunger-signs", "When leaves are hungry", "Reading nutrient shortages", "leaf.fill", Jungle.leaf, 4,
                              when: "Pale, patchy or oddly coloured leaves in the growing season.", k.deficiencies.map {
                S(title: $0.name, detail: "\($0.signs) \($0.fix)", symbol: "leaf.fill")
            }))
        }
        if let m = k.month() {
            out.append(lesson("this-month", "This month in your jungle", "Seasonal jobs, little and often", "calendar", gold, 2, when: "Any day this month.", [
                S(title: "Indoors", detail: m.indoor, symbol: "house.fill"),
                S(title: "Outdoors", detail: m.outdoor, symbol: "sun.horizon.fill"),
            ]))
        }
        if !k.glossary.isEmpty {
            let pick = k.glossary.shuffled().prefix(5)
            out.append(lesson("words", "Plant words, gently explained", "Five terms you'll hear", "text.book.closed.fill", plum, 2, when: "A cosy read with a cup of tea.",
                              pick.map { S(title: $0.term, detail: $0.meaning, symbol: "text.bubble.fill") }))
        }
        return out
    }()
}
