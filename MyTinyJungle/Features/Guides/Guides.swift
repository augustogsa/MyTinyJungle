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
    enum Level: String { case easy = "Easy", medium = "Medium", careful = "Take care" }
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
    static let all: [CareGuide] = core + lessons
    static let core: [CareGuide] = [
        CareGuide(id: "water", title: "Water the right amount", subtitle: "Deep, slow, then drain", symbol: "drop.fill", tint: Color(red: 0.27, green: 0.5, blue: 0.72), minutes: 3, level: .easy,
                  tools: ["Watering can", "Measuring jug", "Saucer"], when: "Only when the top of the soil is dry for most plants.", logs: .water, steps: [
            .init(title: "Check first", detail: "Push a finger 2–3 cm into the soil. Dry? Water. Still cool and damp? Wait a day or two.", symbol: "hand.point.down.fill", tip: "Lift the pot: a dry pot feels surprisingly light."),
            .init(title: "Measure", detail: "Use about a fifth of the pot's volume. I'll show the exact amount for your pot.", symbol: "drop.halffull"),
            .init(title: "Pour slowly", detail: "Circle the base, not the leaves, so all the soil gets wet evenly.", symbol: "arrow.trianglehead.clockwise", seconds: 30),
            .init(title: "Let it drain", detail: "Wait until water runs out of the holes, then empty the saucer.", symbol: "water.waves", tip: "Standing water rots roots.", seconds: 60),
        ]),
        CareGuide(id: "soil", title: "Read the soil", subtitle: "The finger test", symbol: "hand.point.down.fill", tint: Jungle.terracotta, minutes: 1, level: .easy,
                  tools: ["Your finger", "Optional: wooden skewer"], when: "Before every watering.", logs: .soilCheck, steps: [
            .init(title: "Go in 2–3 cm", detail: "Push one finger in near the edge of the pot, away from the stem.", symbol: "hand.point.down.fill"),
            .init(title: "Feel", detail: "Dry and crumbly: water. Cool and slightly damp: wait. Wet or muddy: definitely wait.", symbol: "hand.raised.fill"),
            .init(title: "For deep pots", detail: "Slide a wooden skewer to the bottom for 10 s. Damp soil sticks to it.", symbol: "line.diagonal", seconds: 10),
        ]),
        CareGuide(id: "prune", title: "Prune a leaf or stem", subtitle: "Clean cuts heal fast", symbol: "scissors", tint: Jungle.leaf, minutes: 5, level: .easy,
                  tools: ["Sharp scissors or pruners", "Alcohol wipe"], when: "Spring or summer. Remove yellow or brown leaves any time.", logs: .prune, steps: [
            .init(title: "Clean your blades", detail: "Wipe scissors with alcohol so you don't spread disease.", symbol: "sparkles", seconds: 15),
            .init(title: "Find the node", detail: "A node is the small bump where a leaf meets the stem. New growth starts there.", symbol: "smallcircle.filled.circle"),
            .init(title: "Cut above it", detail: "Cut about 1 cm above a node at a slight angle. For a dead leaf, cut its stalk at the base.", symbol: "scissors", tip: "Never remove more than a quarter of the plant at once."),
            .init(title: "Tidy up", detail: "Remove fallen leaves from the soil to keep pests away.", symbol: "leaf"),
        ]),
        CareGuide(id: "cutting", title: "Take a cutting", subtitle: "Make a new plant", symbol: "scissors.badge.ellipsis", tint: Jungle.forest, minutes: 10, level: .medium,
                  tools: ["Clean scissors", "Glass jar", "Room-temperature water"], when: "Spring to late summer, from a healthy stem.", logs: .propagate, steps: [
            .init(title: "Pick a stem", detail: "Choose a healthy stem with 1–3 leaves and at least one node (and an aerial root if it has one).", symbol: "leaf.fill"),
            .init(title: "Cut below the node", detail: "Cut 1 cm below the node. The node is where roots will grow.", symbol: "scissors"),
            .init(title: "Into water", detail: "Put it in a jar so the node is under water but the leaves stay dry.", symbol: "drop.fill"),
            .init(title: "Bright and warm", detail: "Bright indirect light, no direct sun. Change the water every week.", symbol: "sun.max", tip: "Roots appear in 1–3 weeks. Pot it once they're 2–5 cm long."),
        ]),
        CareGuide(id: "repot", title: "Repot a plant", subtitle: "Bigger home, fresh soil", symbol: "arrow.up.bin.fill", tint: Jungle.terracotta, minutes: 20, level: .medium,
                  tools: ["New pot 2–4 cm wider with drainage", "Fresh mix", "Newspaper", "Gloves"], when: "Spring, when roots circle the pot or poke out of the holes.", logs: .repot, steps: [
            .init(title: "Water the day before", detail: "Moist roots slide out easier and suffer less.", symbol: "drop"),
            .init(title: "Ease it out", detail: "Tip the pot sideways, hold the base of the stems and squeeze or tap the pot.", symbol: "hand.raised.fill"),
            .init(title: "Loosen the roots", detail: "Gently tease circling roots. Trim any black, mushy ones with clean scissors.", symbol: "scissors", tip: "Healthy roots are firm and white or tan."),
            .init(title: "Set the height", detail: "Add mix to the new pot so the plant sits at the same depth as before.", symbol: "ruler"),
            .init(title: "Fill and firm", detail: "Fill around the sides, tap the pot to settle. Don't pack it hard.", symbol: "square.stack.3d.down.forward"),
            .init(title: "Water and rest", detail: "Water until it drains. Keep it out of direct sun for a week and don't feed for a month.", symbol: "moon.zzz"),
        ]),
        CareGuide(id: "feed", title: "Feed with fertilizer", subtitle: "Dilute, never on dry soil", symbol: "leaf.arrow.triangle.circlepath", tint: Jungle.leaf, minutes: 3, level: .easy,
                  tools: ["Liquid fertilizer", "Measuring cap", "Watering can"], when: "Spring and summer, every 2–6 weeks. Pause in winter.", logs: .feed, steps: [
            .init(title: "Water first if dry", detail: "Fertilizer on dry roots can burn them.", symbol: "drop"),
            .init(title: "Half strength", detail: "Mix at half the dose on the label. Houseplants prefer little and often.", symbol: "drop.halffull"),
            .init(title: "Pour on the soil", detail: "Water it in like a normal watering and let it drain.", symbol: "drop.fill"),
        ]),
        CareGuide(id: "clean", title: "Clean the leaves", subtitle: "More light, fewer pests", symbol: "sparkles", tint: Color(red: 0.25, green: 0.55, blue: 0.55), minutes: 5, level: .easy,
                  tools: ["Soft damp cloth", "Lukewarm water"], when: "Once a month or when dust is visible.", logs: .clean, steps: [
            .init(title: "Support the leaf", detail: "Hold each leaf from underneath with one hand.", symbol: "hand.raised"),
            .init(title: "Wipe gently", detail: "Wipe from stem to tip, top and underside. Check for pests while you're there.", symbol: "sparkles", seconds: 60),
            .init(title: "No leaf shine", detail: "Skip shine sprays and oils: they block the leaf's pores.", symbol: "xmark.circle"),
        ]),
        CareGuide(id: "pests", title: "Treat common pests", subtitle: "Mites, mealybugs, gnats", symbol: "ant.fill", tint: Color(red: 0.75, green: 0.33, blue: 0.27), minutes: 15, level: .careful,
                  tools: ["Shower or spray bottle", "Insecticidal soap or neem", "Cotton buds", "Alcohol"], when: "As soon as you see webs, white fluff, sticky leaves or tiny flies.", logs: .treat, steps: [
            .init(title: "Isolate", detail: "Move it away from other plants straight away.", symbol: "arrow.left.and.right"),
            .init(title: "Rinse", detail: "Shower the leaves, especially undersides, with lukewarm water.", symbol: "shower.fill", seconds: 60),
            .init(title: "Spot-treat", detail: "Dab mealybugs with alcohol on a cotton bud. Spray soap or neem on the rest, following the label.", symbol: "drop.triangle"),
            .init(title: "Repeat weekly", detail: "Treat again every 5–7 days for 3–4 weeks to catch new hatchlings.", symbol: "calendar", tip: "Fungus gnats: let the top soil dry out fully between waterings."),
        ]),
        CareGuide(id: "measure", title: "Measure growth", subtitle: "See progress over months", symbol: "ruler.fill", tint: Color(red: 0.4, green: 0.42, blue: 0.68), minutes: 2, level: .easy,
                  tools: ["Tape measure", "Phone camera"], when: "Once a month, same spot, same angle.", logs: .measure, steps: [
            .init(title: "Soil to tip", detail: "Measure from the soil line to the tallest growing point.", symbol: "ruler"),
            .init(title: "Count new leaves", detail: "Note new leaves since last month.", symbol: "leaf"),
            .init(title: "Same photo", detail: "Take a photo from the same place each month. Your timeline will show the growth.", symbol: "camera.fill"),
        ]),
        CareGuide(id: "rotate", title: "Rotate for even growth", subtitle: "Stop the lean", symbol: "arrow.clockwise", tint: Color(red: 0.72, green: 0.56, blue: 0.2), minutes: 1, level: .easy,
                  tools: [], when: "Every 2 weeks for plants near a window.", logs: .rotate, steps: [
            .init(title: "Quarter turn", detail: "Turn the pot a quarter turn in the same direction every time.", symbol: "arrow.clockwise"),
            .init(title: "Mark it", detail: "A small mark on the pot helps you remember which way you turned.", symbol: "pencil"),
        ]),
    ]

    static func guide(_ id: String) -> CareGuide? { all.first { $0.id == id } }

    /// Guides worth doing now for this plant, most relevant first.
    static func suggested(for plant: Plant) -> [CareGuide] {
        var ids: [String] = []
        let reqs = CareEngine.requests(for: plant).map(\.kind)
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
            if CareEngine.isWinter() { ids.append("winter") }
        }
        if plant.sortedEvents.contains(where: { $0.kind == .health }) { ids.append("leaf-signs") }
        ids += ["clean", "prune", "cutting", "measure"]
        return ids.uniqued().compactMap(guide)
    }
}

/// Library of all guides.
struct GuidesView: View {
    var plant: Plant? = nil
    @State private var open: CareGuide?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let plant {
                    SectionTitle("Picked for \(plant.name)")
                    VStack(spacing: 0) {
                        let picks = Array(GuideLibrary.suggested(for: plant).prefix(3))
                        ForEach(picks) { g in
                            Button { open = g } label: { GuideRow(guide: g) }.buttonStyle(.plain)
                            if g.id != picks.last?.id { Divider().padding(.leading, 76) }
                        }
                    }
                    .jungleCard()
                }
                SectionTitle("All guides")
                VStack(spacing: 0) {
                    ForEach(GuideLibrary.all) { g in
                        Button { open = g } label: { GuideRow(guide: g) }.buttonStyle(.plain)
                        if g.id != GuideLibrary.all.last?.id { Divider().padding(.leading, 76) }
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
                Text("\(guide.steps.count) steps · \(guide.minutes) min · \(guide.level.rawValue)").font(.subheadline).foregroundStyle(Jungle.subtle)
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
                .accessibilityLabel(index < 0 ? "Overview" : "Step \(index + 1) of \(guide.steps.count)")
                if let step { stepBody(step) } else { overview }
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    Button { go(index - 1) } label: { Text("Back").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).fontDesign(.rounded).tint(Jungle.forest).disabled(index < 0)
                    if index == guide.steps.count - 1 {
                        Button { finish() } label: { Text(logged ? "Logged" : finishLabel).frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).fontDesign(.rounded).tint(Jungle.forest).disabled(logged)
                    } else {
                        Button { go(index + 1) } label: { Text(index < 0 ? "Start" : "Next").frame(maxWidth: .infinity) }
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
        guard let plant, guide.logs != nil else { return "Done" }
        return "Done, log for \(plant.name)"
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(guide.title).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
            HStack(spacing: 8) {
                StatusPill(text: "\(guide.minutes) min", symbol: "clock", tint: guide.tint)
                StatusPill(text: "\(guide.steps.count) steps", symbol: "list.number", tint: guide.tint)
                StatusPill(text: guide.level.rawValue, tint: guide.tint)
            }
            Label(guide.when, systemImage: "calendar").font(.subheadline).foregroundStyle(Jungle.text)
            if let plant, guide.id == "water", let a = CareEngine.waterAmount(for: plant) {
                Label("For \(plant.name): about \(a.lo)–\(a.hi) ml", systemImage: "drop.fill").font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.accentText)
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
                    .background(Jungle.sun.opacity(0.25), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if let secs = s.seconds {
                HStack {
                    Text(timeString(running || remaining > 0 ? remaining : secs)).font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Jungle.text).contentTransition(.numericText(countsDown: true))
                    Spacer()
                    Button(running ? "Pause" : "Start timer", systemImage: running ? "pause.fill" : "play.fill") {
                        if remaining == 0 { remaining = secs }
                        running.toggle()
                    }
                    .buttonStyle(.bordered).fontDesign(.rounded).buttonBorderShape(.capsule).tint(Jungle.forest)
                }
                .padding(14).background(Jungle.mist, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func detail(_ s: CareGuide.Step) -> String {
        if guide.id == "water", s.title == "Measure", let plant, let a = CareEngine.waterAmount(for: plant) {
            return "\(plant.name)'s pot needs about \(a.lo)–\(a.hi) ml. Fill a jug to that line so you don't guess."
        }
        return s.detail
    }

    private func timeString(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }

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
