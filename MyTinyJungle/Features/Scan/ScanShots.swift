import SwiftUI

/// What one scan photo shows. The raw value is the wire `kind` for /v1/brain/identify and /v1/diagnose.
nonisolated enum ShotKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case leaf, whole, stem, flower, pot, soil, underside, roots, other
    var id: String { rawValue }

    /// Unknown kinds from the server read as `.other`.
    init(wire: String) { self = ShotKind(rawValue: wire.lowercased()) ?? .other }

    @MainActor var title: String {
        switch self {
        case .leaf: Grammar.pt(String(localized: "Leaf", comment: "Scan photo kind: a close-up of one leaf; max 14 chars"))
        case .whole: Grammar.pt(String(localized: "Whole plant", comment: "Scan photo kind: the entire plant in frame; max 14 chars"))
        case .stem: Grammar.pt(String(localized: "Stem", comment: "Scan photo kind: the stem up close; max 14 chars"))
        case .flower: Grammar.pt(String(localized: "Flower", comment: "Scan photo kind: a flower; max 14 chars"))
        case .pot: Grammar.pt(String(localized: "Pot", comment: "Scan photo kind: the pot and its drainage; max 14 chars"))
        case .soil: Grammar.pt(String(localized: "Soil", comment: "Scan photo kind: the soil surface up close; max 14 chars"))
        case .underside: Grammar.pt(String(localized: "Underside", comment: "Scan photo kind: the underside of a leaf, for pests; max 14 chars"))
        case .roots: Grammar.pt(String(localized: "Roots", comment: "Scan photo kind: the roots; max 14 chars"))
        case .other: Grammar.pt(String(localized: "Other", comment: "Scan photo kind: anything else; max 14 chars"))
        }
    }

    /// Erty's nudge for the next shot of this kind.
    @MainActor var hint: String {
        switch self {
        case .leaf: Grammar.pt(String(localized: "Get close to one leaf", comment: "Erty bubble in Scan asking for a leaf close-up; playful; max 32 chars"))
        case .whole: Grammar.pt(String(localized: "Now the whole plant!", comment: "Erty bubble in Scan asking for the whole plant; playful; max 32 chars"))
        case .stem: Grammar.pt(String(localized: "Now the stem, up close", comment: "Erty bubble in Scan asking for the stem; playful; max 32 chars"))
        case .flower: Grammar.pt(String(localized: "Got flowers? Snap one!", comment: "Erty bubble in Scan asking for a flower; playful; max 32 chars"))
        case .pot: Grammar.pt(String(localized: "Show me the pot and its holes", comment: "Erty bubble in Scan asking for the pot (drainage); playful; max 32 chars"))
        case .soil: Grammar.pt(String(localized: "Get close to the soil", comment: "Erty bubble in Scan asking for the soil; playful; max 32 chars"))
        case .underside: Grammar.pt(String(localized: "Flip a leaf, I'll check for bugs", comment: "Erty bubble in Scan asking for a leaf underside (pests); playful; max 32 chars"))
        case .roots: Grammar.pt(String(localized: "Roots peeking out? Show me!", comment: "Erty bubble in Scan asking for the roots; playful; max 32 chars"))
        case .other: Grammar.pt(String(localized: "Anything odd? Snap it too", comment: "Erty bubble in Scan asking for any other detail; playful; max 32 chars"))
        }
    }

    var icon: Icon3D {
        switch self {
        case .leaf: .leaf; case .whole: .pottedPlant; case .stem: .growth; case .flower: .flower; case .pot: .pot
        case .soil: .soil; case .underside: .bug; case .roots: .roots; case .other: .leafTag
        }
    }
}

/// Which brain call the photos feed.
nonisolated enum ScanPurpose: Sendable {
    case identify, doctor

    /// The order shots are suggested in; also the order of "Add more" chips.
    var order: [ShotKind] {
        switch self {
        case .identify: [.leaf, .whole, .flower, .stem, .underside, .pot, .soil, .roots, .other]
        case .doctor: [.leaf, .whole, .underside, .soil, .pot, .stem, .roots, .flower, .other]
        }
    }

    /// How much each distinct kind adds to the answer.
    func weight(_ k: ShotKind) -> Double {
        switch self {
        case .identify:
            switch k { case .leaf: 0.35; case .whole: 0.3; case .flower: 0.2; case .stem: 0.1; case .underside: 0.05; default: 0.03 }
        case .doctor:
            switch k { case .leaf: 0.3; case .whole: 0.2; case .underside: 0.2; case .soil: 0.15; case .pot: 0.1; case .stem, .roots: 0.05; default: 0.03 }
        }
    }

    /// Kinds worth a chip: the ones that move the answer.
    var useful: [ShotKind] { order.filter { weight($0) >= 0.1 } }
}

/// One photo in the scan tray. `data` is the camera or library original; the upload is made from it with BrainPhoto.
struct ScanShot: Identifiable, Equatable, Sendable {
    let id: UUID
    let data: Data
    var kind: ShotKind
    init(id: UUID = UUID(), data: Data, kind: ShotKind) { self.id = id; self.data = data; self.kind = kind }
}

/// Pure tray rules, kept apart from the view so they're testable.
nonisolated enum ScanPlan {
    static let cap = 8

    /// Next kind to ask for: the one the owner asked for, else the first in the purpose's order not yet taken.
    static func suggest(_ purpose: ScanPurpose, taken: [ShotKind], wanted: ShotKind? = nil) -> ShotKind {
        if let wanted { return wanted }
        return purpose.order.first { !taken.contains($0) } ?? .other
    }

    /// Up to three useful kinds still missing, the wanted one first.
    static func missing(_ purpose: ScanPurpose, taken: [ShotKind], wanted: ShotKind? = nil) -> [ShotKind] {
        var out = purpose.useful.filter { !taken.contains($0) }
        if let wanted, !taken.contains(wanted) { out.removeAll { $0 == wanted }; out.insert(wanted, at: 0) }
        return Array(out.prefix(3))
    }

    /// 0...1: distinct kinds by weight, plus a little for each repeat. One leaf is a fair start, never "sure".
    static func sureness(_ purpose: ScanPurpose, taken: [ShotKind]) -> Double {
        guard !taken.isEmpty else { return 0 }
        let distinct = Set(taken)
        let base = distinct.reduce(0) { $0 + purpose.weight($1) }
        return min(1, max(0.2, base + Double(taken.count - distinct.count) * 0.04))
    }
}

@MainActor @Observable final class ScanTray {
    private(set) var shots: [ScanShot] = []
    var purpose: ScanPurpose = .identify
    /// Kind the owner asked for with a chip or a result tip; the next shot takes it.
    var wanted: ShotKind?

    var isEmpty: Bool { shots.isEmpty }
    var isFull: Bool { shots.count >= ScanPlan.cap }
    var room: Int { max(0, ScanPlan.cap - shots.count) }
    var kinds: [ShotKind] { shots.map(\.kind) }
    var next: ShotKind { ScanPlan.suggest(purpose, taken: kinds, wanted: wanted) }
    var missing: [ShotKind] { ScanPlan.missing(purpose, taken: kinds, wanted: wanted) }
    var sureness: Double { ScanPlan.sureness(purpose, taken: kinds) }

    @discardableResult func add(_ data: Data) -> ScanShot? {
        guard !isFull else { return nil }
        let s = ScanShot(data: data, kind: next)
        shots.append(s)
        wanted = nil
        // Warm the 768 px upload so Check sends at once.
        Task.detached(priority: .utility) { _ = BrainPhoto.make(data) }
        return s
    }

    func remove(_ id: UUID) { shots.removeAll { $0.id == id } }
    func retag(_ id: UUID, _ kind: ShotKind) { if let i = shots.firstIndex(where: { $0.id == id }) { shots[i].kind = kind } }
    func clear() { shots = []; wanted = nil }
}

// MARK: - Tray UI

/// Thumbnails, "Add more" chips, the sureness meter and the Check button. Sits above the shutter.
struct ScanTrayView: View {
    @Bindable var tray: ScanTray
    var onCheck: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(tray.shots.enumerated()), id: \.element.id) { i, s in thumb(s, index: i).id(s.id) }
                    }
                    .padding(.horizontal, 4).padding(.top, 8)
                }
                .onChange(of: tray.shots.count) { _, _ in
                    guard let last = tray.shots.last?.id else { return }
                    withAnimation(reduceMotion ? nil : .snappy) { proxy.scrollTo(last, anchor: .trailing) }
                }
            }
            if !tray.missing.isEmpty && !tray.isFull { addMore }
            meter
            Button(action: onCheck) {
                Text(tray.shots.count == 1
                     ? Grammar.pt(String(localized: "Check this photo", comment: "Scan: send the one photo for an answer; max 24 chars"))
                     : Grammar.pt(String(localized: "Check \(tray.shots.count) photos", comment: "Scan: send all photos for an answer; arg count (2-8); max 24 chars")))
                    .font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 4)
                    .contentTransition(.numericText())
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large).junglePrimary()
        }
        .padding(10)
        .warmGlass(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(reduceMotion ? nil : .snappy, value: tray.shots)
    }

    private func thumb(_ s: ScanShot, index: Int) -> some View {
        Menu {
            Picker(Grammar.pt(String(localized: "What's in this photo?", comment: "Scan tray: retag a photo's kind")), selection: Binding(get: { s.kind }, set: { tray.retag(s.id, $0) })) {
                ForEach(ShotKind.allCases) { Label($0.title, systemImage: "tag").tag($0) }
            }
            Button(Grammar.pt(String(localized: "Remove photo", comment: "Scan tray: remove a photo")), systemImage: "trash", role: .destructive) { tray.remove(s.id) }
        } label: {
            VStack(spacing: 3) {
                Group {
                    if let img = Thumbs.image(s.data, side: 56) { Image(uiImage: img).resizable().scaledToFill() } else { Jungle.mint }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .bottomLeading) { Icon3DView(s.kind.icon, size: 20).padding(2).background(Jungle.surface, in: Circle()).offset(x: -4, y: 4) }
                HStack(spacing: 2) {
                    Text(s.kind.title).lineLimit(1).minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold))
                }
                .font(.caption2.weight(.semibold)).foregroundStyle(Jungle.text)
                .frame(width: 64)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { tray.remove(s.id) } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(Jungle.onForest)
                    .frame(width: 20, height: 20).background(Jungle.forest, in: Circle())
                    .frame(width: 32, height: 32).contentShape(Circle())
            }
            .offset(x: 10, y: -10)
            .accessibilityLabel(Grammar.pt(String(localized: "Remove photo \(index + 1)", comment: "VoiceOver: remove a scan photo; arg photo number")))
        }
        .accessibilityLabel(Grammar.pt(String(localized: "Photo \(index + 1): \(s.kind.title)", comment: "VoiceOver: scan tray photo; args number and kind")))
        .accessibilityHint(Grammar.pt(String(localized: "Change what this photo shows, or remove it", comment: "VoiceOver hint on a scan tray photo")))
    }

    private var addMore: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(Grammar.pt(String(localized: "Add more:", comment: "Scan tray: label before suggested photo chips; max 14 chars")))
                    .font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
                ForEach(tray.missing) { k in
                    Button { tray.wanted = k; UISelectionFeedbackGenerator().selectionChanged() } label: {
                        HStack(spacing: 4) {
                            Icon3DView(k.icon, size: 16)
                            Text(k.title).font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Jungle.text)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(tray.wanted == k ? Jungle.mint : Jungle.surface.opacity(0.8), in: Capsule())
                        .overlay(Capsule().strokeBorder(tray.wanted == k ? Jungle.leaf : Jungle.border, lineWidth: tray.wanted == k ? 1.5 : 0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Grammar.pt(String(localized: "Next photo: \(k.title)", comment: "VoiceOver: scan chip to take a photo of this kind next; arg kind")))
                    .accessibilityAddTraits(tray.wanted == k ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var meter: some View {
        let v = tray.sureness
        let label = v < 0.4 ? Grammar.pt(String(localized: "Good start", comment: "Scan sureness meter: one photo; max 18 chars"))
            : v < 0.75 ? Grammar.pt(String(localized: "Getting surer", comment: "Scan sureness meter: a few photos; max 18 chars"))
            : Grammar.pt(String(localized: "Very sure", comment: "Scan sureness meter: plenty of angles; max 18 chars"))
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Grammar.pt(String(localized: "The more you send, the surer I am", comment: "Scan sureness meter caption; max 36 chars")))
                    .font(.caption2).foregroundStyle(Jungle.subtle).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                Text(label).font(.caption2.weight(.bold)).foregroundStyle(Jungle.accentText)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Jungle.border.opacity(0.6))
                    Capsule().fill(LinearGradient(colors: [Jungle.sun, Jungle.leaf], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, g.size.width * v))
                }
            }
            .frame(height: 7)
            .animation(reduceMotion ? nil : .spring(duration: 0.5), value: v)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Grammar.pt(String(localized: "The more you send, the surer I am", comment: "Scan sureness meter caption; max 36 chars")))
        .accessibilityValue(label)
    }
}

/// The photos an answer was read from, small, with their kinds.
struct ScanShotStrip: View {
    let shots: [ScanShot]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Grammar.pt(String(localized: "Read from \(shots.count) photos", comment: "Scan result: how many photos the answer used; arg count (2-8); max 28 chars")))
                .font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(shots) { s in
                        VStack(spacing: 2) {
                            Group { if let img = Thumbs.image(s.data, side: 48) { Image(uiImage: img).resizable().scaledToFill() } else { Jungle.mint } }
                                .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Text(s.kind.title).font(.caption2).foregroundStyle(Jungle.subtle).lineLimit(1).minimumScaleFactor(0.75).frame(width: 64)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Grammar.pt(String(localized: "Read from \(shots.count) photos", comment: "Scan result: how many photos the answer used; arg count (2-8); max 28 chars")) + ": " + shots.map(\.kind.title).joined(separator: ", "))
    }
}

// MARK: - Tips from the answer

/// The server's `tips`: kinds that would firm up the answer. Tapping one reopens the camera on that kind.
nonisolated struct ScanTip: Decodable, Hashable, Sendable {
    let kind: String
    let why: String
    var shotKind: ShotKind { ShotKind(wire: kind) }
}

struct ScanTipsCard: View {
    let tips: [ScanTip]
    var onPick: (ShotKind) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(Grammar.pt(String(localized: "Add this photo for a surer answer", comment: "Scan result: header over suggested extra photos; max 40 chars")))
                    .font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            } icon: { Icon3DView(.leafTag, size: 24) }
            ForEach(tips, id: \.self) { t in
                Button { onPick(t.shotKind) } label: {
                    HStack(spacing: 10) {
                        Icon3DView(t.shotKind.icon, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.shotKind.title).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                            if !t.why.isEmpty { Text(t.why).font(.caption).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true) }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "camera.fill").font(.subheadline).foregroundStyle(Jungle.accentText)
                    }
                    .padding(12)
                    .background(Jungle.mint.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Grammar.pt(String(localized: "Take a photo: \(t.shotKind.title)", comment: "VoiceOver: scan result tip opening the camera; arg kind")))
                .accessibilityHint(t.why)
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
    }
}

// MARK: - How to scan

struct HowToScanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private struct Step { let icon: Icon3D; let title: String; let text: String }
    private var steps: [Step] {
        [
            Step(icon: .sunny, title: Grammar.pt(String(localized: "Good light, one plant", comment: "How to scan step 1 title; max 28 chars")),
                 text: Grammar.pt(String(localized: "Daylight by a window is best. Keep just one plant in the shot.", comment: "How to scan step 1 text"))),
            Step(icon: .leaf, title: Grammar.pt(String(localized: "Get close", comment: "How to scan step 2 title; max 28 chars")),
                 text: Grammar.pt(String(localized: "For a leaf, get close so it's sharp. For the whole plant, step back until it all fits.", comment: "How to scan step 2 text"))),
            Step(icon: .pottedPlant, title: Grammar.pt(String(localized: "Mix your angles", comment: "How to scan step 3 title; max 28 chars")),
                 text: ""),
            Step(icon: .award, title: Grammar.pt(String(localized: "More photos, surer answers", comment: "How to scan step 4 title; max 28 chars")),
                 text: Grammar.pt(String(localized: "Send one, or up to eight. I'll tell you what's missing as you go.", comment: "How to scan step 4 text"))),
        ]
    }

    private var angles: [(ShotKind, String)] {
        [
            (.leaf, Grammar.pt(String(localized: "who it is", comment: "How to scan: what a leaf close-up helps with; max 24 chars"))),
            (.whole, Grammar.pt(String(localized: "its shape and size", comment: "How to scan: what a whole-plant photo helps with; max 24 chars"))),
            (.underside, Grammar.pt(String(localized: "hidden bugs", comment: "How to scan: what a leaf underside photo helps with; max 24 chars"))),
            (.soil, Grammar.pt(String(localized: "watering", comment: "How to scan: what a soil photo helps with; max 24 chars"))),
            (.pot, Grammar.pt(String(localized: "drainage", comment: "How to scan: what a pot photo helps with; max 24 chars"))),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Grammar.pt(String(localized: "How to scan", comment: "How to scan card title; max 24 chars")))
                    .font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text).accessibilityAddTraits(.isHeader)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Jungle.forest)
                        .frame(width: 36, height: 36).background(Jungle.surface, in: Circle())
                }
                .accessibilityLabel(Grammar.pt(String(localized: "Close", comment: "VoiceOver: close button")))
            }
            .padding(.horizontal, 20).padding(.top, 18)
            TabView(selection: $page) {
                ForEach(steps.indices, id: \.self) { i in stepView(steps[i], index: i).tag(i) }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            HStack(spacing: 7) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule().fill(i == page ? Jungle.forest : Jungle.border).frame(width: i == page ? 20 : 7, height: 7)
                }
            }
            .animation(reduceMotion ? nil : .snappy, value: page)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Grammar.pt(String(localized: "Step \(page + 1) of \(steps.count)", comment: "VoiceOver: how to scan page indicator")))
            Button {
                if page < steps.count - 1 { withAnimation(reduceMotion ? nil : .snappy) { page += 1 } } else { dismiss() }
            } label: {
                Text(page < steps.count - 1 ? Grammar.pt(String(localized: "Next", comment: "How to scan: next step button; max 16 chars"))
                                            : Grammar.pt(String(localized: "Let's scan!", comment: "How to scan: last step button; max 16 chars")))
                    .font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large).junglePrimary()
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 20)
        }
        .background(Color.clear.jungleBackdrop())
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
    }

    private func stepView(_ s: Step, index: Int) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Icon3DView(s.icon, size: index == 2 ? 72 : 110)
                    if index == 0 || index == steps.count - 1 {
                        ErtyView(mood: index == 0 ? .wave : .happy, size: 70).offset(x: 46, y: 10)
                    }
                }
                .frame(height: index == 2 ? 84 : 140)
                .accessibilityHidden(true)
                Text(s.title).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text).multilineTextAlignment(.center)
                if index == 2 {
                    VStack(spacing: 8) {
                        ForEach(angles, id: \.0) { k, why in
                            HStack(spacing: 12) {
                                Icon3DView(k.icon, size: 30)
                                Text(k.title).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                                Spacer(minLength: 6)
                                Text(why).font(.subheadline).foregroundStyle(Jungle.subtle).multilineTextAlignment(.trailing)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Jungle.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityElement(children: .combine)
                        }
                    }
                } else {
                    Text(s.text).font(.body).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24).padding(.top, 12)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Every "add a plant" entry point opens the Scan tab in Identify mode.
enum ScanRoute {
    @MainActor static func addPlant() {
        let d = UserDefaults.standard
        d.set("identify", forKey: "scanMode")
        d.set(3, forKey: "selectedTab")
    }
}
