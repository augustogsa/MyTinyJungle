import SwiftUI
import SwiftData

/// Repotting intelligence: signs + season + health + time in pot → verdict, pot size, mix, timing, plan.
struct RepotCheckView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let plant: Plant

    @State private var rootsOut = false
    @State private var rootsCircling = false
    @State private var drainsFast = false
    @State private var staysWet = false
    @State private var unstable = false
    @State private var slowGrowth = false
    @State private var planDate = Date().addingTimeInterval(3 * 86_400)
    @State private var newPot: Double?
    @State private var didRepot = false

    enum Verdict { case recommended, mayBenefit, monitor, notNow, notNeeded }

    var body: some View {
        NavigationStack {
            Form {
                Section("What do you notice?") {
                    Toggle("Roots coming out of the drainage holes", isOn: $rootsOut)
                    Toggle("Roots circling or on the surface", isOn: $rootsCircling)
                    Toggle("Water runs straight through", isOn: $drainsFast)
                    Toggle("Soil stays wet or smells", isOn: $staysWet)
                    Toggle("Top-heavy, tips over", isOn: $unstable)
                    Toggle("Growth has slowed", isOn: $slowGrowth)
                }
                Section {
                    let v = verdict
                    Label { VStack(alignment: .leading, spacing: 3) {
                        Text(title(v)).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                        Text(explanation(v)).font(.subheadline).foregroundStyle(Jungle.subtle)
                    } } icon: { Image(systemName: icon(v)).foregroundStyle(color(v)) }
                }
                if let s = plant.species {
                    Section("Recommended") {
                        LabeledContent("New pot", value: potSize)
                        LabeledContent("Soil", value: s.mixLabel)
                        LabeledContent("Best time", value: CareEngine.isWinter() ? Grammar.pt(String(localized: "Spring, unless roots are rotting", comment: "Repot best time in cool season; max 34 chars")) : Grammar.pt(String(localized: "Now: growing season", comment: "Repot best time in growing season; max 24 chars")))
                        LabeledContent("Material", value: s.waterStyle == .dry ? Grammar.pt(String(localized: "Terracotta", comment: "Pot material")) : Grammar.pt(String(localized: "Plastic or glazed ceramic", comment: "Pot material recommendation; max 28 chars")))
                    }
                    Section("How") {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, t in Text(verbatim: "\((i + 1).formatted()). \(t)").font(.subheadline) }
                    }
                }
                Section("Plan it") {
                    DatePicker("Repot on", selection: $planDate, in: Date()..., displayedComponents: .date)
                    Button("Plan repotting", systemImage: "calendar.badge.plus") {
                        ctx.insert(CareTask(title: Grammar.pt(String(localized: "Repot \(plant.name) (\(potSize))", comment: "Care task title; args plant name, pot size text")), kind: .repot, plantID: plant.id, due: planDate))
                        try? ctx.save(); dismiss()
                    }
                }
                Section("Already did it?") {
                    LabeledContent("New pot Ø") {
                        TextField("cm", value: $newPot, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Button("I repotted today", systemImage: "checkmark.circle") {
                        let e = CareEvent(kind: .repot, source: "repot"); e.value = newPot; e.plant = plant
                        ctx.insert(e)
                        plant.lastRepotAt = Date()
                        if let newPot { plant.potDiameterCm = newPot }
                        if let s = plant.species, plant.substrate.isEmpty { plant.substrate = s.mixLabel }
                        let m = ChatMessage(text: PlantVoice.thanks(.repot, plant: plant), fromUser: false); m.speakerID = plant.id; ctx.insert(m)
                        ctx.insert(CareTask(title: Grammar.pt(String(localized: "Recovery check \(plant.name)", comment: "Care task title after repotting; arg plant name; max 40 chars")), kind: .health, plantID: plant.id, due: Date().addingTimeInterval(7 * 86_400)))
                        try? ctx.save(); dismiss()
                    }
                }
            }
            .navigationTitle("Repotting check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private var verdict: Verdict {
        if CareEngine.mood(for: plant) == .needsYou && !staysWet { return .notNow }
        let strong = [rootsOut, rootsCircling, unstable].filter { $0 }.count
        let weak = [drainsFast, slowGrowth].filter { $0 }.count
        let years = CareEngine.days(from: plant.lastRepotAt ?? plant.acquiredAt) / 365
        let due = years >= (plant.species?.repotYears ?? 2)
        if staysWet { return .recommended }
        if strong >= 2 || (strong == 1 && (weak >= 1 || due)) { return CareEngine.isWinter() ? .mayBenefit : .recommended }
        if strong == 1 || (weak >= 1 && due) { return .mayBenefit }
        if weak >= 1 || due { return .monitor }
        return .notNeeded
    }
    private func title(_ v: Verdict) -> String {
        switch v { case .recommended: Grammar.pt(String(localized: "Repotting recommended", comment: "Repot verdict title; max 26 chars")); case .mayBenefit: Grammar.pt(String(localized: "Repotting may help", comment: "Repot verdict title; max 26 chars")); case .monitor: Grammar.pt(String(localized: "Monitor the roots", comment: "Repot verdict title; max 26 chars")); case .notNow: Grammar.pt(String(localized: "Not now", comment: "Repot verdict title; max 26 chars")); case .notNeeded: Grammar.pt(String(localized: "Not needed yet", comment: "Repot verdict title; max 26 chars")) }
    }
    private func explanation(_ v: Verdict) -> String {
        switch v {
        case .recommended: staysWet ? Grammar.pt(String(localized: "Soggy soil risks root rot. Fresh, airy mix now, even in winter.", comment: "Repot verdict explanation")) : Grammar.pt(String(localized: "Roots are running out of room.", comment: "Repot verdict explanation"))
        case .mayBenefit: CareEngine.isWinter() ? Grammar.pt(String(localized: "There are signs, but it's resting season. Wait for spring if you can.", comment: "Repot verdict explanation, cool season")) : Grammar.pt(String(localized: "Some signs of a crowded pot.", comment: "Repot verdict explanation"))
        case .monitor: Grammar.pt(String(localized: "Fast drainage alone doesn't mean it needs a new pot. Peek at the roots in a month.", comment: "Repot verdict explanation"))
        case .notNow: Grammar.pt(String(localized: "\(plant.name) is stressed. Fix the water and light first, since repotting adds stress.", comment: "Repot verdict explanation; arg plant name"))
        case .notNeeded: Grammar.pt(String(localized: "Happy where it is. Unnecessary repotting does more harm than good.", comment: "Repot verdict explanation"))
        }
    }
    private func icon(_ v: Verdict) -> String { switch v { case .recommended: "arrow.up.bin.fill"; case .mayBenefit: "arrow.up.bin"; case .monitor: "eye"; case .notNow: "hand.raised.fill"; case .notNeeded: "checkmark.circle.fill" } }
    private func color(_ v: Verdict) -> Color { switch v { case .recommended: Jungle.terracotta; case .mayBenefit, .monitor: Jungle.sun; default: Jungle.leaf } }
    private var potSize: String {
        if let d = plant.potDiameterCm { return Grammar.pt(String(localized: "Ø \(Int(d + 2))–\(PlantFormat.cm(d + 5)) (2–5 cm larger)", comment: "New pot size range; args low number, high size with unit; max 30 chars")) }
        return Grammar.pt(String(localized: "2–5 cm wider than now", comment: "New pot size when current size unknown; max 26 chars"))
    }
    private var steps: [String] {
        [Grammar.pt(String(localized: "Water a day before so the root ball slides out", comment: "Repotting step; imperative; max 70 chars")),
         Grammar.pt(String(localized: "Loosen circling roots gently. Trim any black, mushy ones", comment: "Repotting step; imperative; max 70 chars")),
         Grammar.pt(String(localized: "Put fresh mix at the bottom so the plant sits at the same depth", comment: "Repotting step; imperative; max 70 chars")),
         Grammar.pt(String(localized: "Fill around it, firm lightly, water until it drains", comment: "Repotting step; imperative; max 70 chars")),
         Grammar.pt(String(localized: "Bright indirect light, no fertilizer for 6 weeks", comment: "Repotting step; imperative; max 70 chars"))]
    }
}
