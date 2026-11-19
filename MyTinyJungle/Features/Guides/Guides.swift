import Combine
import SwiftUI
import SwiftData

/// Step-by-step plant care, like an exercise guide: what you need, each move, timing and mistakes to avoid.
struct CareGuide: Identifiable, Hashable {
    struct Step: Hashable {
        let title: String
        let detail: String
        let symbol: String
        var tip: String? = nil
        var seconds: Int? = nil
    }
    enum Level: String {
        case easy = "Easy", medium = "Medium", careful = "Take care"
        var label: String {
            switch self {
            case .easy: Grammar.pt(String(localized: "Easy", comment: "Care guide difficulty level"))
            case .medium: Grammar.pt(String(localized: "Medium", comment: "Care guide difficulty level"))
            case .careful: Grammar.pt(String(localized: "Take care", comment: "Care guide difficulty level; needs extra care"))
            }
        }
    }
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let minutes: Int
    let level: Level
    let tools: [String]
    let when: String
    let logs: CareKind?
    let steps: [Step]
    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

extension CareEngine {
    /// Water amount from pot size and species style.
    static func waterAmount(for plant: Plant) -> (lo: Int, hi: Int)? {
        guard let d = plant.potDiameterCm else { return nil }
        let litres = 0.75 * Double.pi * pow(d / 2, 2) * d * 0.9 / 1000
        let share = plant.species?.waterStyle == .dry ? 0.12 : plant.species?.waterStyle == .moist ? 0.25 : 0.2
        let ml = litres * share * 1000
        return (max(50, Int((ml * 0.8 / 50).rounded() * 50)), max(100, Int((ml * 1.2 / 50).rounded() * 50)))
    }
}

enum GuideLibrary {
    static let all: [CareGuide] = core + lessons + knowledgeLessons
    static let core: [CareGuide] = [
        CareGuide(id: "water", title: Grammar.pt(String(localized: "Water the right amount", comment: "Care guide title; short")), subtitle: Grammar.pt(String(localized: "Deep, slow, then drain", comment: "Care guide subtitle; short")), symbol: "drop.fill", tint: Jungle.sky, minutes: 3, level: .easy,
                  tools: [Grammar.pt(String(localized: "Watering can", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Measuring jug", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Saucer", comment: "Tool needed for a care guide"))], when: Grammar.pt(String(localized: "Only when the top of the soil is dry for most plants.", comment: "When to do this care guide")), logs: .water, steps: [
            .init(title: Grammar.pt(String(localized: "Check first", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Push a finger 2–3 cm into the soil. Dry? Water. Still cool and damp? Wait a day or two.", comment: "Care guide step instruction; warm, practical")), symbol: "hand.point.down.fill", tip: Grammar.pt(String(localized: "Lift the pot: a dry pot feels surprisingly light.", comment: "Care guide step tip"))),
            .init(title: Grammar.pt(String(localized: "Measure", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Use about a fifth of the pot's volume. I'll show the exact amount for your pot.", comment: "Care guide step instruction; warm, practical")), symbol: "drop.halffull"),
            .init(title: Grammar.pt(String(localized: "Pour slowly", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Circle the base, not the leaves, so all the soil gets wet evenly.", comment: "Care guide step instruction; warm, practical")), symbol: "arrow.trianglehead.clockwise", seconds: 30),
            .init(title: Grammar.pt(String(localized: "Let it drain", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Wait until water runs out of the holes, then empty the saucer.", comment: "Care guide step instruction; warm, practical")), symbol: "water.waves", tip: Grammar.pt(String(localized: "Standing water rots roots.", comment: "Care guide step tip")), seconds: 60),
        ]),
        CareGuide(id: "soil", title: Grammar.pt(String(localized: "Read the soil", comment: "Care guide title; short")), subtitle: Grammar.pt(String(localized: "The finger test", comment: "Care guide subtitle; short")), symbol: "hand.point.down.fill", tint: Jungle.terracotta, minutes: 1, level: .easy,
                  tools: [Grammar.pt(String(localized: "Your finger", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Optional: wooden skewer", comment: "Tool needed for a care guide"))], when: Grammar.pt(String(localized: "Before every watering.", comment: "When to do this care guide")), logs: .soilCheck, steps: [
            .init(title: Grammar.pt(String(localized: "Go in 2–3 cm", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Push one finger in near the edge of the pot, away from the stem.", comment: "Care guide step instruction; warm, practical")), symbol: "hand.point.down.fill"),
            .init(title: Grammar.pt(String(localized: "Feel", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Dry and crumbly: water. Cool and slightly damp: wait. Wet or muddy: definitely wait.", comment: "Care guide step instruction; warm, practical")), symbol: "hand.raised.fill"),
            .init(title: Grammar.pt(String(localized: "For deep pots", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Slide a wooden skewer to the bottom for 10 s. Damp soil sticks to it.", comment: "Care guide step instruction; warm, practical")), symbol: "line.diagonal", seconds: 10),
        ]),
        CareGuide(id: "prune", title: Grammar.pt(String(localized: "Prune a leaf or stem", comment: "Care guide title; short")), subtitle: Grammar.pt(String(localized: "Clean cuts heal fast", comment: "Care guide subtitle; short")), symbol: "scissors", tint: Jungle.leaf, minutes: 5, level: .easy,
                  tools: [Grammar.pt(String(localized: "Sharp scissors or pruners", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Alcohol wipe", comment: "Tool needed for a care guide"))], when: Grammar.pt(String(localized: "Spring or summer. Remove yellow or brown leaves any time.", comment: "When to do this care guide")), logs: .prune, steps: [
            .init(title: Grammar.pt(String(localized: "Clean your blades", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Wipe scissors with alcohol so you don't spread disease.", comment: "Care guide step instruction; warm, practical")), symbol: "sparkles", seconds: 15),
            .init(title: Grammar.pt(String(localized: "Find the node", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "A node is the small bump where a leaf meets the stem. New growth starts there.", comment: "Care guide step instruction; warm, practical")), symbol: "smallcircle.filled.circle"),
            .init(title: Grammar.pt(String(localized: "Cut above it", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Cut about 1 cm above a node at a slight angle. For a dead leaf, cut its stalk at the base.", comment: "Care guide step instruction; warm, practical")), symbol: "scissors", tip: Grammar.pt(String(localized: "Never remove more than a quarter of the plant at once.", comment: "Care guide step tip"))),
            .init(title: Grammar.pt(String(localized: "Tidy up", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Remove fallen leaves from the soil to keep pests away.", comment: "Care guide step instruction; warm, practical")), symbol: "leaf"),
        ]),
        CareGuide(id: "cutting", title: Grammar.pt(String(localized: "Take a cutting", comment: "Care guide title; short")), subtitle: Grammar.pt(String(localized: "Make a new plant", comment: "Care guide subtitle; short")), symbol: "scissors.badge.ellipsis", tint: Jungle.forest, minutes: 10, level: .medium,
                  tools: [Grammar.pt(String(localized: "Clean scissors", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Glass jar", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Room-temperature water", comment: "Tool needed for a care guide"))], when: Grammar.pt(String(localized: "Spring to late summer, from a healthy stem.", comment: "When to do this care guide")), logs: .propagate, steps: [
            .init(title: Grammar.pt(String(localized: "Pick a stem", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Choose a healthy stem with 1–3 leaves and at least one node (and an aerial root if it has one).", comment: "Care guide step instruction; warm, practical")), symbol: "leaf.fill"),
            .init(title: Grammar.pt(String(localized: "Cut below the node", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Cut 1 cm below the node. The node is where roots will grow.", comment: "Care guide step instruction; warm, practical")), symbol: "scissors"),
            .init(title: Grammar.pt(String(localized: "Into water", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Put it in a jar so the node is under water but the leaves stay dry.", comment: "Care guide step instruction; warm, practical")), symbol: "drop.fill"),
            .init(title: Grammar.pt(String(localized: "Bright and warm", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Bright indirect light, no direct sun. Change the water every week.", comment: "Care guide step instruction; warm, practical")), symbol: "sun.max", tip: Grammar.pt(String(localized: "Roots appear in 1–3 weeks. Pot it once they're 2–5 cm long.", comment: "Care guide step tip"))),
        ]),
        CareGuide(id: "repot", title: Grammar.pt(String(localized: "Repot a plant", comment: "Care guide title; short")), subtitle: Grammar.pt(String(localized: "Bigger home, fresh soil", comment: "Care guide subtitle; short")), symbol: "arrow.up.bin.fill", tint: Jungle.terracotta, minutes: 20, level: .medium,
                  tools: [Grammar.pt(String(localized: "New pot 2–4 cm wider with drainage", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Fresh mix", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Newspaper", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Gloves", comment: "Tool needed for a care guide"))], when: Grammar.pt(String(localized: "Spring, when roots circle the pot or poke out of the holes.", comment: "When to do this care guide")), logs: .repot, steps: [
            .init(title: Grammar.pt(String(localized: "Water the day before", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Moist roots slide out easier and suffer less.", comment: "Care guide step instruction; warm, practical")), symbol: "drop"),
            .init(title: Grammar.pt(String(localized: "Ease it out", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Tip the pot sideways, hold the base of the stems and squeeze or tap the pot.", comment: "Care guide step instruction; warm, practical")), symbol: "hand.raised.fill"),
            .init(title: Grammar.pt(String(localized: "Loosen the roots", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Gently tease circling roots. Trim any black, mushy ones with clean scissors.", comment: "Care guide step instruction; warm, practical")), symbol: "scissors", tip: Grammar.pt(String(localized: "Healthy roots are firm and white or tan.", comment: "Care guide step tip"))),
            .init(title: Grammar.pt(String(localized: "Set the height", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Add mix to the new pot so the plant sits at the same depth as before.", comment: "Care guide step instruction; warm, practical")), symbol: "ruler"),
            .init(title: Grammar.pt(String(localized: "Fill and firm", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Fill around the sides, tap the pot to settle. Don't pack it hard.", comment: "Care guide step instruction; warm, practical")), symbol: "square.stack.3d.down.forward"),
            .init(title: Grammar.pt(String(localized: "Water and rest", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Water until it drains. Keep it out of direct sun for a week and don't feed for a month.", comment: "Care guide step instruction; warm, practical")), symbol: "moon.zzz"),
        ]),
        CareGuide(id: "feed", title: Grammar.pt(String(localized: "Feed with fertilizer", comment: "Care guide title; short")), subtitle: Grammar.pt(String(localized: "Dilute, never on dry soil", comment: "Care guide subtitle; short")), symbol: "leaf.arrow.triangle.circlepath", tint: Jungle.leaf, minutes: 3, level: .easy,
                  tools: [Grammar.pt(String(localized: "Liquid fertilizer", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Measuring cap", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Watering can", comment: "Tool needed for a care guide"))], when: Grammar.pt(String(localized: "Spring and summer, every 2–6 weeks. Pause in winter.", comment: "When to do this care guide")), logs: .feed, steps: [
            .init(title: Grammar.pt(String(localized: "Water first if dry", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Fertilizer on dry roots can burn them.", comment: "Care guide step instruction; warm, practical")), symbol: "drop"),
            .init(title: Grammar.pt(String(localized: "Half strength", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Mix at half the dose on the label. Houseplants prefer little and often.", comment: "Care guide step instruction; warm, practical")), symbol: "drop.halffull"),
            .init(title: Grammar.pt(String(localized: "Pour on the soil", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Water it in like a normal watering and let it drain.", comment: "Care guide step instruction; warm, practical")), symbol: "drop.fill"),
        ]),
        CareGuide(id: "clean", title: Grammar.pt(String(localized: "Clean the leaves", comment: "Care guide title; short")), subtitle: Grammar.pt(String(localized: "More light, fewer pests", comment: "Care guide subtitle; short")), symbol: "sparkles", tint: Jungle.teal, minutes: 5, level: .easy,
                  tools: [Grammar.pt(String(localized: "Soft damp cloth", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Lukewarm water", comment: "Tool needed for a care guide"))], when: Grammar.pt(String(localized: "Once a month or when dust is visible.", comment: "When to do this care guide")), logs: .clean, steps: [
            .init(title: Grammar.pt(String(localized: "Support the leaf", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Hold each leaf from underneath with one hand.", comment: "Care guide step instruction; warm, practical")), symbol: "hand.raised"),
            .init(title: Grammar.pt(String(localized: "Wipe gently", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Wipe from stem to tip, top and underside. Check for pests while you're there.", comment: "Care guide step instruction; warm, practical")), symbol: "sparkles", seconds: 60),
            .init(title: Grammar.pt(String(localized: "No leaf shine", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Skip shine sprays and oils: they block the leaf's pores.", comment: "Care guide step instruction; warm, practical")), symbol: "xmark.circle"),
        ]),
        CareGuide(id: "pests", title: Grammar.pt(String(localized: "Treat common pests", comment: "Care guide title; short")), subtitle: Grammar.pt(String(localized: "Mites, mealybugs, gnats", comment: "Care guide subtitle; short")), symbol: "ant.fill", tint: Jungle.brick, minutes: 15, level: .careful,
                  tools: [Grammar.pt(String(localized: "Shower or spray bottle", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Insecticidal soap or neem", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Cotton buds", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Alcohol", comment: "Tool needed for a care guide"))], when: Grammar.pt(String(localized: "As soon as you see webs, white fluff, sticky leaves or tiny flies.", comment: "When to do this care guide")), logs: .treat, steps: [
            .init(title: Grammar.pt(String(localized: "Isolate", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Move it away from other plants straight away.", comment: "Care guide step instruction; warm, practical")), symbol: "arrow.left.and.right"),
            .init(title: Grammar.pt(String(localized: "Rinse", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Shower the leaves, especially undersides, with lukewarm water.", comment: "Care guide step instruction; warm, practical")), symbol: "shower.fill", seconds: 60),
            .init(title: Grammar.pt(String(localized: "Spot-treat", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Dab mealybugs with alcohol on a cotton bud. Spray soap or neem on the rest, following the label.", comment: "Care guide step instruction; warm, practical")), symbol: "drop.triangle"),
            .init(title: Grammar.pt(String(localized: "Repeat weekly", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Treat again every 5–7 days for 3–4 weeks to catch new hatchlings.", comment: "Care guide step instruction; warm, practical")), symbol: "calendar", tip: Grammar.pt(String(localized: "Fungus gnats: let the top soil dry out fully between waterings.", comment: "Care guide step tip"))),
        ]),
        CareGuide(id: "measure", title: Grammar.pt(String(localized: "Measure growth", comment: "Care guide title; short")), subtitle: Grammar.pt(String(localized: "See progress over months", comment: "Care guide subtitle; short")), symbol: "ruler.fill", tint: Jungle.indigo, minutes: 2, level: .easy,
                  tools: [Grammar.pt(String(localized: "Tape measure", comment: "Tool needed for a care guide")), Grammar.pt(String(localized: "Phone camera", comment: "Tool needed for a care guide"))], when: Grammar.pt(String(localized: "Once a month, same spot, same angle.", comment: "When to do this care guide")), logs: .measure, steps: [
            .init(title: Grammar.pt(String(localized: "Soil to tip", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Measure from the soil line to the tallest growing point.", comment: "Care guide step instruction; warm, practical")), symbol: "ruler"),
            .init(title: Grammar.pt(String(localized: "Count new leaves", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Note new leaves since last month.", comment: "Care guide step instruction; warm, practical")), symbol: "leaf"),
            .init(title: Grammar.pt(String(localized: "Same photo", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Take a photo from the same place each month. Your timeline will show the growth.", comment: "Care guide step instruction; warm, practical")), symbol: "camera.fill"),
        ]),
        CareGuide(id: "rotate", title: Grammar.pt(String(localized: "Rotate for even growth", comment: "Care guide title; short")), subtitle: Grammar.pt(String(localized: "Stop the lean", comment: "Care guide subtitle; short")), symbol: "arrow.clockwise", tint: Jungle.gold, minutes: 1, level: .easy,
                  tools: [], when: Grammar.pt(String(localized: "Every 2 weeks for plants near a window.", comment: "When to do this care guide")), logs: .rotate, steps: [
            .init(title: Grammar.pt(String(localized: "Quarter turn", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "Turn the pot a quarter turn in the same direction every time.", comment: "Care guide step instruction; warm, practical")), symbol: "arrow.clockwise"),
            .init(title: Grammar.pt(String(localized: "Mark it", comment: "Care guide step title; short")), detail: Grammar.pt(String(localized: "A small mark on the pot helps you remember which way you turned.", comment: "Care guide step instruction; warm, practical")), symbol: "pencil"),
        ]),
    ]

    static func guide(_ id: String) -> CareGuide? { all.first { $0.id == id } }

    /// Guides worth doing now for this plant, most relevant first.
    static func suggested(for plant: Plant, now: Date = .now) -> [CareGuide] {
        var ids: [String] = []
        let reqs = CareEngine.requests(for: plant, now: now).map(\.kind)
        if reqs.contains(.water) || reqs.contains(.checkSoil) { ids += ["soil", "water"] }
        if reqs.contains(.checkRoots) { ids.append("repot") }
        if reqs.contains(.feed) { ids.append("feed") }
        if let sp = plant.species {
            switch sp.group {
            case "succulent", "cactus": ids += ["succulent-care", "propagate-leaf"]
            case "orchid": ids.append("orchid-rebloom")
            case "carnivorous": ids.append("carnivorous")
            case "herb-med", "herb-soft", "vegetable": ids += ["herbs", "outdoor-pots"]
            case "prayer", "fern": ids += ["humidity", "water-quality"]
            case "acid": ids.append("soil-ph")
            case "aroid": ids += ["propagate-water", "soil-mixes"]
            default: break
            }
            if !sp.isPetSafe && (JungleSettings.shared.hasCats || JungleSettings.shared.hasDogs) { ids.append("pet-safe") }
            if CareEngine.isWinter(now) { ids.append("winter") }
        }
        if plant.sortedEvents.contains(where: { $0.kind == .health }) { ids += ["leaf-signs", "hunger-signs"] }
        ids.append("this-month")
        ids += ["clean", "prune", "cutting", "measure"]
        return ids.uniqued().compactMap { guide($0) }
    }
}

/// Library of all guides.
struct GuidesView: View {
    var plant: Plant? = nil
    @State private var open: CareGuide?

    var body: some View {
        DuoCompanion(mood: .learn, title: "How-to guides", detail: "Short, friendly and made for real homes.") { duoContent }
    }

    @ViewBuilder private var duoContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                InlineErty(mood: .learn, size: 104)
                if let plant {
                    SectionTitle(Grammar.pt(String(localized: "Picked for \(plant.name)", comment: "Section title: guides suggested for this plant")))
                    VStack(spacing: 0) {
                        let picks = Array(GuideLibrary.suggested(for: plant).prefix(3))
                        ForEach(picks) { g in
                            Button { open = g } label: { GuideRow(guide: g) }.buttonStyle(.plain)
                            if g.id != picks.last?.id { Divider().padding(.leading, 76) }
                        }
                    }
                    .jungleCard()
                }
                SectionTitle(Grammar.pt(String(localized: "All guides", comment: "Section title above the list of every care guide")))
                VStack(spacing: 0) {
                    ForEach(Array(GuideLibrary.all.enumerated()), id: \.element.id) { i, g in
                        Button { open = g } label: { GuideRow(guide: g) }.buttonStyle(.plain)
                        if g.id != GuideLibrary.all.last?.id { Divider().padding(.leading, 76) }
                        if i == 4, AdPool.shared.ad(for: "guides") != nil {
                            NativeAdCard(slot: "guides", style: .row)
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .jungleCard()
            }
            .padding(16)
        }
        .jungleBackdrop()
        .navigationTitle("How-to guides")
        .fullScreenCover(item: $open) { GuidePlayerView(guide: $0, plant: plant) }
    }
}

struct GuideIcon: View {
    let guide: CareGuide
    var size: CGFloat = 52
    var body: some View {
        Icon3DView(guide.icon, size: size * 0.72)
            .frame(width: size, height: size)
            .background(guide.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

struct GuideRow: View {
    let guide: CareGuide
    var body: some View {
        HStack(spacing: 12) {
            GuideIcon(guide: guide)
            VStack(alignment: .leading, spacing: 2) {
                Text(guide.title).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                Text("\(guide.steps.count) steps · \(guide.minutes) min · \(guide.level.label)", comment: "Guide row meta: step count, minutes, difficulty").font(.subheadline).foregroundStyle(Jungle.subtle)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
        }
        .padding(12).contentShape(Rectangle())
    }
}

struct GuideHeroCard: View {
    let guide: CareGuide
    var body: some View {
        HStack(spacing: 10) {
            Icon3DView(guide.icon, size: 30)
                .frame(width: 44, height: 44)
                .background(guide.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(guide.title).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text).lineLimit(2)
                Text("\(guide.minutes) min").font(.caption).foregroundStyle(Jungle.subtle)
            }
            Spacer(minLength: 0)
        }
        .padding(8).frame(width: 210, height: 60).jungleCard()
    }
}

/// Full-screen step player: progress segments, big illustration, timer, Prev/Next, log when done.
struct GuidePlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let guide: CareGuide
    var plant: Plant?
    @State private var index = -1 // -1 = overview
    @State private var remaining = 0
    @State private var running = false
    @State private var logged = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var step: CareGuide.Step? { guide.steps.indices.contains(index) ? guide.steps[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    LinearGradient(colors: [guide.tint.opacity(0.28), Jungle.mint], startPoint: .top, endPoint: .bottom)
                    Image(systemName: step?.symbol ?? guide.symbol)
                        .font(.system(size: 120, weight: .regular))
                        .foregroundStyle(guide.tint)
                        .symbolEffect(.bounce, value: index)
                        .contentTransition(.symbolEffect(.replace))
                        .shadow(color: guide.tint.opacity(0.25), radius: 20, y: 10)
                }
                .frame(height: 340).frame(maxWidth: .infinity)
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                        .frame(width: 44, height: 44).background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Close").padding(.top, 56).padding(.trailing, 16)
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 4) {
                    ForEach(guide.steps.indices, id: \.self) { i in
                        Capsule().fill(i <= index ? guide.tint : Jungle.border).frame(height: 5)
                    }
                }
                .accessibilityLabel(index < 0 ? Grammar.pt(String(localized: "Overview", comment: "Care guide overview page")) : Grammar.pt(String(localized: "Step \(index + 1) of \(guide.steps.count)", comment: "Care guide progress")))
                if let step { stepBody(step) } else { overview }
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    Button { go(index - 1) } label: { Text("Back").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).fontDesign(.rounded).tint(Jungle.tint).disabled(index < 0)
                    if index == guide.steps.count - 1 {
                        Button { finish() } label: { Text(logged ? Grammar.pt(String(localized: "Logged", comment: "Care guide finished and logged")) : finishLabel).frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).fontDesign(.rounded).tint(Jungle.forest).disabled(logged)
                    } else {
                        Button { go(index + 1) } label: { Text(index < 0 ? Grammar.pt(String(localized: "Start", comment: "Start a care guide")) : Grammar.pt(String(localized: "Next", comment: "Next care guide step"))).frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).fontDesign(.rounded).tint(Jungle.forest)
                    }
                }
                .controlSize(.large).buttonBorderShape(.capsule)
            }
            .padding(20)
            .background(Jungle.surface, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous))
            .offset(y: -24).padding(.bottom, -24)
        }
        .background(Jungle.surface)
        .ignoresSafeArea(edges: .top)
        .animation(reduceMotion ? nil : .snappy, value: index)
        .onReceive(tick) { _ in
            guard running, remaining > 0 else { return }
            remaining -= 1
            if remaining == 0 { running = false; UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
        .sensoryFeedback(.selection, trigger: index)
    }

    private var finishLabel: String {
        guard let plant, guide.logs != nil else { return Grammar.pt(String(localized: "Done", comment: "Button finishing a care guide")) }
        return Grammar.pt(String(localized: "Done, log for \(plant.name)", comment: "Button finishing a care guide and logging it for the plant; max 28 chars"))
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(guide.title).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
            HStack(spacing: 8) {
                StatusPill(text: Grammar.pt(String(localized: "\(guide.minutes) min", comment: "Guide duration in minutes")), symbol: "clock", tint: guide.tint)
                StatusPill(text: Grammar.pt(String(localized: "\(guide.steps.count) steps", comment: "Number of steps in a care guide")), symbol: "list.number", tint: guide.tint)
                StatusPill(text: guide.level.label, tint: guide.tint)
            }
            Label(guide.when, systemImage: "calendar").font(.subheadline).foregroundStyle(Jungle.text)
            if let plant, guide.id == "water", let a = CareEngine.waterAmount(for: plant) {
                Label(Grammar.pt(String(localized: "For \(plant.name): about \(a.lo.formatted())–\(a.hi.formatted()) ml")), systemImage: "drop.fill").font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.accentText)
            }
            if !guide.tools.isEmpty {
                Text("You'll need").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text).padding(.top, 4)
                ForEach(guide.tools, id: \.self) { Label($0, systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(Jungle.text) }
            }
        }
    }

    private func stepBody(_ s: CareGuide.Step) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step \(index + 1) of \(guide.steps.count)").font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.subtle)
            Text(s.title).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
            Text(detail(s)).font(.body).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
            if let tip = s.tip {
                Label(tip, systemImage: "lightbulb.fill").font(.subheadline).foregroundStyle(Jungle.text)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Jungle.mist, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if let secs = s.seconds {
                HStack {
                    Text(timeString(running || remaining > 0 ? remaining : secs)).font(.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Jungle.text).contentTransition(.numericText(countsDown: true))
                    Spacer()
                    Button(running ? Grammar.pt(String(localized: "Pause", comment: "Pause step timer")) : Grammar.pt(String(localized: "Start timer", comment: "Start step timer")), systemImage: running ? "pause.fill" : "play.fill") {
                        if remaining == 0 { remaining = secs }
                        running.toggle()
                    }
                    .buttonStyle(.bordered).fontDesign(.rounded).buttonBorderShape(.capsule).tint(Jungle.tint)
                }
                .padding(14).background(Jungle.mist, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func detail(_ s: CareGuide.Step) -> String {
        if guide.id == "water", s.symbol == "drop.halffull", let plant, let a = CareEngine.waterAmount(for: plant) {
            return Grammar.pt(String(localized: "\(plant.name)'s pot needs about \(a.lo.formatted())–\(a.hi.formatted()) ml. Fill a jug to that line so you don't guess.", comment: "Water guide step with exact water amount range in millilitres for the plant"))
        }
        return s.detail
    }

    private func timeString(_ s: Int) -> String { Duration.seconds(s).formatted(.time(pattern: .minuteSecond)) }

    private func go(_ i: Int) {
        running = false; remaining = 0
        index = max(-1, min(guide.steps.count - 1, i))
    }

    private func finish() {
        if let plant, let kind = guide.logs {
            JungleBrain.quick(kind, plants: [plant], in: ctx, announce: true)
            logged = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
        } else { dismiss() }
    }
}

extension CareGuide {
    /// One distinct 3D icon per guide.
    var icon: Icon3D {
        switch id {
        case "water": .waterDrops
        case "soil": .soilTest
        case "prune": .herbs
        case "cutting": .seedling
        case "repot": .pot
        case "feed": .fertilizer
        case "clean": .leaves
        case "pests": .bug
        case "measure": .growth
        case "rotate": .repeat
        default: Icon3D.forSymbol(symbol) ?? .leaf
        }
    }
}
