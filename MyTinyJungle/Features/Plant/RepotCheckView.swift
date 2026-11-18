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
                        LabeledContent("Best time", value: CareEngine.isWinter() ? "Spring, unless roots are rotting" : "Now: growing season")
                        LabeledContent("Material", value: s.waterStyle == .dry ? "Terracotta" : "Plastic or glazed ceramic")
                    }
                    Section("How") {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, t in Text("\(i + 1). \(t)").font(.subheadline) }
                    }
                }
                Section("Plan it") {
                    DatePicker("Repot on", selection: $planDate, in: Date()..., displayedComponents: .date)
                    Button("Plan repotting", systemImage: "calendar.badge.plus") {
                        ctx.insert(CareTask(title: "Repot \(plant.name) (\(potSize))", kind: .repot, plantID: plant.id, due: planDate))
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
                        ctx.insert(CareTask(title: "Recovery check \(plant.name)", kind: .health, plantID: plant.id, due: Date().addingTimeInterval(7 * 86_400)))
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
        switch v { case .recommended: "Repotting recommended"; case .mayBenefit: "Repotting may help"; case .monitor: "Monitor the roots"; case .notNow: "Not now"; case .notNeeded: "Not needed yet" }
    }
    private func explanation(_ v: Verdict) -> String {
        switch v {
        case .recommended: staysWet ? "Soggy soil risks root rot. Fresh, airy mix now, even in winter." : "Roots are running out of room."
        case .mayBenefit: CareEngine.isWinter() ? "There are signs, but it's resting season. Wait for spring if you can." : "Some signs of a crowded pot."
        case .monitor: "Fast drainage alone doesn't mean it needs a new pot. Peek at the roots in a month."
        case .notNow: "\(plant.name) is stressed. Fix the water and light first, since repotting adds stress."
        case .notNeeded: "Happy where it is. Unnecessary repotting does more harm than good."
        }
    }
    private func icon(_ v: Verdict) -> String { switch v { case .recommended: "arrow.up.bin.fill"; case .mayBenefit: "arrow.up.bin"; case .monitor: "eye"; case .notNow: "hand.raised.fill"; case .notNeeded: "checkmark.circle.fill" } }
    private func color(_ v: Verdict) -> Color { switch v { case .recommended: Jungle.terracotta; case .mayBenefit, .monitor: Jungle.sun; default: Jungle.leaf } }
    private var potSize: String {
        if let d = plant.potDiameterCm { return "Ø \(Int(d + 2))–\(Int(d + 5)) cm (2–5 cm larger)" }
        return "2–5 cm wider than now"
    }
    private var steps: [String] {
        ["Water a day before so the root ball slides out",
         "Loosen circling roots gently. Trim any black, mushy ones",
         "Put fresh mix at the bottom so the plant sits at the same depth",
         "Fill around it, firm lightly, water until it drains",
         "Bright indirect light, no fertilizer for 6 weeks"]
    }
}
