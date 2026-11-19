import SwiftUI
import SwiftData

/// How a plant lives, before it's saved: filled from the photo scene when the server is sure.
struct PlantSetupDraft: Equatable {
    var medium: GrowingMedium = .soil
    var stage: LifeStage? = .acclimating
    var selfWatering = false
    var cachepot = false
    var drainage = true
    var sizeFit: PotSizeFit?
    var artificial = false
    var multiple = false
    /// Which fields came from the photo, so the user sees why.
    var fromPhoto = false

    @MainActor mutating func apply(_ s: PhotoScene) {
        if let m = s.medium { medium = m; fromPhoto = true }
        if let st = s.lifeStage { stage = st; fromPhoto = true }
        if s.artificial { artificial = true; fromPhoto = true }
        if s.multiple { multiple = true; fromPhoto = true }
        if s.potSure, let p = s.pot {
            if let v = p.selfWatering { selfWatering = v }
            if let v = p.cachepot { cachepot = v }
            if let v = p.drainage { drainage = v }
            if let f = p.sizeFit.flatMap(PotSizeFit.init(rawValue:)) { sizeFit = f }
            fromPhoto = true
        }
    }

    @MainActor func write(to p: Plant) {
        p.growingMedium = medium
        p.setLifeStage(stage)
        if medium.inPot {
            p.potSelfWatering = selfWatering ? true : nil
            p.potCachepot = cachepot ? true : nil
            p.potHasDrainage = drainage
            p.sizeFit = sizeFit
        }
        p.isArtificial = artificial
        p.sharesPot = multiple
        if medium == .ground { p.isOutdoor = true }
    }
}

private func stageLabel(_ s: LifeStage?) -> String {
    s?.label ?? Grammar.pt(String(localized: "Doing its thing", comment: "Life stage option: normal, nothing special; max 16 chars"))
}

/// Add-plant card: medium, stage, pot setup, faux and shared pot.
struct PlantSetupCard: View {
    @Binding var draft: PlantSetupDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Grammar.pt(String(localized: "How do I live?", comment: "Add plant section title: growing medium, pot and life stage; plant voice; max 24 chars")))
                .font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            if draft.fromPhoto {
                Label(Grammar.pt(String(localized: "Filled in from your photo. Tap to change.", comment: "Add plant: setup fields were guessed from the photo")), systemImage: "camera.viewfinder")
                    .font(.caption).foregroundStyle(Jungle.subtle)
            }
            if draft.artificial {
                Label(Grammar.pt(String(localized: "Looks like a faux plant! I'll keep it in your jungle for the looks, no care needed.", comment: "Add plant: artificial plant detected; friendly")), systemImage: "sparkles")
                    .font(.subheadline).foregroundStyle(Jungle.text)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Jungle.sunFill, in: RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
            }
            Text(Grammar.pt(String(localized: "Roots in", comment: "Add plant: growing medium label; max 16 chars"))).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.subtle)
            FlowChips(items: GrowingMedium.allCases.map(\.label), selected: draft.medium.label) { l in
                withAnimation(.snappy) { draft.medium = GrowingMedium.allCases.first { $0.label == l } ?? .soil }
            }
            Text(Grammar.pt(String(localized: "Right now", comment: "Add plant: life stage label; max 16 chars"))).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.subtle)
            FlowChips(items: ([nil] + LifeStage.allCases.map { Optional($0) }).map(stageLabel), selected: stageLabel(draft.stage)) { l in
                withAnimation(.snappy) { draft.stage = LifeStage.allCases.first { $0.label == l } }
            }
            if draft.medium.inPot {
                Toggle(Grammar.pt(String(localized: "Drainage holes", comment: "Toggle")), isOn: $draft.drainage)
                Toggle(Grammar.pt(String(localized: "Inside a cachepot", comment: "Toggle: plant pot sits inside a decorative outer pot without holes")), isOn: $draft.cachepot)
                Toggle(Grammar.pt(String(localized: "Self-watering pot", comment: "Toggle")), isOn: $draft.selfWatering)
                Picker(Grammar.pt(String(localized: "Pot size", comment: "Picker label: how the pot fits the plant")), selection: $draft.sizeFit) {
                    Text(Grammar.pt(String(localized: "Not sure", comment: "Pot size fit option; max 12 chars"))).tag(PotSizeFit?.none)
                    ForEach(PotSizeFit.allCases) { Text($0.label).tag(Optional($0)) }
                }
            }
            Toggle(Grammar.pt(String(localized: "Several plants in this pot", comment: "Toggle")), isOn: $draft.multiple)
            Toggle(Grammar.pt(String(localized: "Faux plant", comment: "Toggle: artificial plant")), isOn: $draft.artificial)
        }
        .tint(Jungle.forest)
        .padding(14).jungleCard()
    }
}

/// Plant settings rows (inside a Form).
struct PlantSetupSections: View {
    @Bindable var plant: Plant

    var body: some View {
        Section {
            Picker(Grammar.pt(String(localized: "Roots in", comment: "Add plant: growing medium label; max 16 chars")), selection: Binding(get: { plant.growingMedium }, set: { plant.growingMedium = $0 })) {
                ForEach(GrowingMedium.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
            }
            Picker(Grammar.pt(String(localized: "Right now", comment: "Add plant: life stage label; max 16 chars")), selection: Binding(get: { plant.activeLifeStage() }, set: { plant.setLifeStage($0) })) {
                Text(stageLabel(nil)).tag(LifeStage?.none)
                ForEach(LifeStage.allCases) { Text($0.label).tag(Optional($0)) }
            }
            Toggle(Grammar.pt(String(localized: "Several plants in this pot", comment: "Toggle")), isOn: $plant.sharesPot)
            Toggle(Grammar.pt(String(localized: "Faux plant", comment: "Toggle: artificial plant")), isOn: $plant.isArtificial)
        } header: {
            Text(Grammar.pt(String(localized: "How it lives", comment: "Plant settings section title; max 24 chars")))
        } footer: {
            Text(Grammar.pt(String(localized: "Reminders follow this: plants in water get fresh-water days, not soil checks.", comment: "Plant settings footer under growing medium")))
        }
    }
}

/// Plants that passed away: kept with their story, never deleted.
struct MemorialSection: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { $0.isArchived }, sort: \Plant.createdAt) private var archived: [Plant]

    var body: some View {
        let gone = archived.filter { $0.archivedReason == "passed" }
        if !gone.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(Grammar.pt(String(localized: "In loving memory", comment: "Plants tab section: plants that died; gentle; max 24 chars")))
                ForEach(gone) { p in
                    HStack(spacing: 12) {
                        PlantAvatar(data: p.photo, size: 44).saturation(0.4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                            Text(Grammar.pt(String(localized: "With you from \(p.acquiredAt.formatted(.dateTime.month().year())) · \((p.events ?? []).count) moments", comment: "Memorial row subtitle; args start month/year and number of logged moments (plural)")))
                                .font(.caption).foregroundStyle(Jungle.subtle)
                        }
                        Spacer()
                        Menu {
                            Button(Grammar.pt(String(localized: "It came back!", comment: "Memorial menu: restore a plant marked as dead")), systemImage: "leaf") {
                                p.isArchived = false; p.archivedReason = nil; p.setLifeStage(.recovering); try? ctx.save()
                            }
                        } label: { Image(systemName: "ellipsis.circle").foregroundStyle(Jungle.subtle).frame(width: 44, height: 44) }
                        .accessibilityLabel(Grammar.pt(String(localized: "More for \(p.name)", comment: "VoiceOver: menu button for a plant")))
                    }
                    .accessibilityElement(children: .contain)
                }
                .padding(14).jungleCard()
            }
        }
    }
}
