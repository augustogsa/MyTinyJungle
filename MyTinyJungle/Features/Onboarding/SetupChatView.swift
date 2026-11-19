import SwiftUI
import SwiftData

/// First run after sign-in: the mascot sets up the jungle in a short chat, one question at a time.
/// Every answer writes the same stored settings the Settings screens use.
struct SetupChatView: View {
    var onDone: () -> Void
    @Environment(\.modelContext) private var ctx
    @State private var lines: [Line] = []
    @State private var step: Step = .name
    @State private var typing = true
    @State private var picked: Set<String> = []
    @State private var lightQueue: [String] = []
    @State private var addingPlant = false
    @State private var text = ""
    @FocusState private var focused: Bool

    struct Line: Identifiable, Equatable { let id = UUID(); let fromUser: Bool; let text: String }

    enum Step: Equatable {
        case name, place, heating, aircon, air, drafts, outside, weather, family, rooms, light(String), plant, finished
    }

    struct Chip: Identifiable { let id: String; let title: String; var icon: Icon3D? = nil; var multi = false }

    private var climate: Climate { Climate.shared }
    private var settings: JungleSettings { JungleSettings.shared }
    private var firstName: String { settings.ownerName.split(separator: " ").first.map(String.init) ?? "" }

    var body: some View {
        NavigationStack {
            SideBySide {
                header(erty: 150).padding(.horizontal, 32)
            } main: { paged in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if !paged { header(erty: 112) }
                        ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                            // Avatar only on the last bubble of a run, like Messages.
                            bubble(line, avatar: !typing && i == lines.count - 1 || i < lines.count - 1 && lines[i + 1].fromUser).id(line.id)
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                        }
                        if typing { TypingBubble().id("typing").transition(.opacity) }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16).padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: lines.count) { withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: typing) { withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: picked) { withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: step) {
                    // Wait for the answer bar to take its new height, then keep the last question in view.
                    Task { try? await Task.sleep(for: .milliseconds(150)); withAnimation(.snappy) { proxy.scrollTo("bottom", anchor: .bottom) } }
                }
            }
            .safeAreaInset(edge: .bottom) { answerBar(paged: paged) }
            }
            .jungleBackdrop()
            .navigationTitle(Grammar.pt(String(localized: "Getting set up", comment: "Setup chat navigation title")))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $addingPlant, onDismiss: { wrapUp(addedPlant: true) }) { AddPlantFlow() }
            .task { if lines.isEmpty { await open() } }
        }
    }

    // MARK: Views

    private func header(erty: CGFloat) -> some View {
        VStack(spacing: 8) {
            ErtyView(mood: step == .finished ? .love : .wave, size: erty)
            Text(Grammar.pt(String(localized: "A few quick questions so your plants get care that fits your home.", comment: "Setup chat intro under the mascot")))
                .font(.subheadline).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 8)
    }

    private func bubble(_ line: Line, avatar: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if line.fromUser { Spacer(minLength: 48) } else { mascot.opacity(avatar ? 1 : 0) }
            Text(line.text).font(.body).foregroundStyle(Jungle.text)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(line.fromUser ? Jungle.userBubble : Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
                .overlay { if !line.fromUser { RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5) } }
            if !line.fromUser { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
    }

    private var mascot: some View {
        Image("erty-idle").resizable().scaledToFit().frame(width: 32, height: 32).accessibilityHidden(true)
    }

    @ViewBuilder private func answerBar(paged: Bool) -> some View {
        if step != .finished && !typing {
            VStack(alignment: .leading, spacing: 8) {
                SetupChips(chips: chips, picked: picked) { tap($0) }
                if isMulti && !picked.isEmpty {
                    // Distinct primary action, so it never reads as one more option.
                    Button { tap(done) } label: {
                        HStack(spacing: 6) {
                            Text(done.title)
                            Image(systemName: "arrow.right").font(.subheadline.weight(.bold))
                        }
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Jungle.forest, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if allowsText {
                    HStack(spacing: 8) {
                        TextField(placeholder, text: $text)
                            .focused($focused).submitLabel(.send).onSubmit(sendText)
                            .textContentType(step == .name ? .givenName : step == .place ? .addressCity : nil)
                            .padding(.horizontal, 14).frame(minHeight: 40)
                        Button(action: sendText) {
                            Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(Jungle.surface)
                                .frame(width: 36, height: 36)
                                .background(canSend ? Jungle.forest : Jungle.subtle.opacity(0.4), in: Circle())
                        }
                        .disabled(!canSend)
                        .accessibilityLabel(Grammar.pt(String(localized: "Send", comment: "Send button accessibility label")))
                    }
                    .padding(4)
                    .glassEffect(.regular, in: Capsule())
                }
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)
            // On a phone the bar sits on a soft material band; on its own page (Duo, wide) the band's hard
            // leading edge would cut the page, so the field floats on the backdrop instead.
            .background { if !paged { Rectangle().fill(.ultraThinMaterial).mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.15)], startPoint: .top, endPoint: .bottom)).ignoresSafeArea() } }
            .transition(.opacity)
        }
    }

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: Script

    private var allowsText: Bool {
        switch step { case .name, .place, .rooms: true; default: false }
    }

    private var placeholder: String {
        switch step {
        case .name: Grammar.pt(String(localized: "Your name", comment: "Setup chat text field placeholder"))
        case .place: Grammar.pt(String(localized: "Type your city", comment: "Setup chat text field placeholder"))
        default: Grammar.pt(String(localized: "Or type a room", comment: "Setup chat text field placeholder: add a custom room name"))
        }
    }

    private var yesNo: [Chip] {
        [Chip(id: "yes", title: Grammar.pt(String(localized: "Yes", comment: "Setup chat chip answer"))),
         Chip(id: "no", title: Grammar.pt(String(localized: "No", comment: "Setup chat chip answer")))]
    }

    private var chips: [Chip] {
        switch step {
        case .name:
            return firstName.isEmpty ? [] : [Chip(id: "keep", title: firstName, icon: .profile)] 
        case .place:
            return [Chip(id: "here", title: Grammar.pt(String(localized: "Use my location", comment: "Setup chat chip: use device location")), icon: .pin)]
        case .heating, .aircon, .drafts:
            return yesNo.prefix(1) + [Chip(id: "sometimes", title: Grammar.pt(String(localized: "Sometimes", comment: "Setup chat chip answer between yes and no")))] + yesNo.suffix(1)
        case .outside, .weather:
            return yesNo
        case .air:
            return Climate.HomeAir.allCases.map { Chip(id: "air\($0.rawValue)", title: $0.label) }
        case .family:
            return [Chip(id: "cats", title: Grammar.pt(String(localized: "Cats", comment: "Setup chat chip: cats at home")), icon: .cat, multi: true),
                    Chip(id: "dogs", title: Grammar.pt(String(localized: "Dogs", comment: "Setup chat chip: dogs at home")), icon: .dog, multi: true),
                    Chip(id: "kids", title: Grammar.pt(String(localized: "Small children", comment: "Setup chat chip: small children at home")), icon: .kid, multi: true),
                    picked.isEmpty ? Chip(id: "none", title: Grammar.pt(String(localized: "None of these", comment: "Setup chat chip: no pets or small kids"))) as Chip? : nil].compactMap { $0 }
        case .rooms:
            let rooms = Self.roomChips.map { Chip(id: $0.0, title: $0.0, icon: $0.1, multi: true) }
            let custom = picked.subtracting(Self.roomChips.map(\.0)).sorted().map { Chip(id: $0, title: $0, icon: .homeLeaf, multi: true) }
            return rooms + custom
        case .light:
            return Self.lights.map { Chip(id: "light.\($0.0.rawValue)", title: $0.1, icon: $0.2) }
        case .plant:
            return [Chip(id: "add", title: Grammar.pt(String(localized: "Add my first plant", comment: "Setup chat chip: open add-plant flow")), icon: .addPlant),
                    Chip(id: "later", title: Grammar.pt(String(localized: "Later", comment: "Setup chat chip: add a plant later")))]
        case .finished:
            return []
        }
    }

    private var done: Chip { Chip(id: "done", title: Grammar.pt(String(localized: "Continue", comment: "Setup chat: main button to confirm a multi-choice answer; max 20 chars"))) }
    private var isMulti: Bool { step == .family || step == .rooms }

    static let roomChips: [(String, Icon3D)] = [
        (Grammar.pt(String(localized: "Living room", comment: "Suggested room name")), .livingRoom),
        (Grammar.pt(String(localized: "Bedroom", comment: "Suggested room name")), .bedroom),
        (Grammar.pt(String(localized: "Kitchen", comment: "Suggested room name")), .kitchen),
        (Grammar.pt(String(localized: "Bathroom", comment: "Suggested room name")), .bathroom),
        (Grammar.pt(String(localized: "Office", comment: "Suggested room name")), .office),
        (Grammar.pt(String(localized: "Balcony", comment: "Suggested room name")), .balcony),
    ]

    static let lights: [(Species.Light, String, Icon3D)] = [
        (.low, Grammar.pt(String(localized: "Dim: lamps on even by day", comment: "Setup chat chip: room light level, low")), .moon),
        (.medium, Grammar.pt(String(localized: "Some light, away from windows", comment: "Setup chat chip: room light level, medium")), .lamp),
        (.bright, Grammar.pt(String(localized: "Bright, by a window, no sun on leaves", comment: "Setup chat chip: room light level, bright, no direct sun")), .sunny),
        (.direct, Grammar.pt(String(localized: "Sun shines right on the plants", comment: "Setup chat chip: room light level, direct sun")), .sun),
    ]

    /// "in the living room" with the right preposition and article for each language.
    static func roomPhrase(_ room: String) -> String {
        switch roomChips.firstIndex(where: { $0.0 == room }) {
        case 0: Grammar.pt(String(localized: "in the living room", comment: "Setup chat room phrase, used in 'How much light is there …?'. pt: na sala"))
        case 1: Grammar.pt(String(localized: "in the bedroom", comment: "Setup chat room phrase, used in 'How much light is there …?'"))
        case 2: Grammar.pt(String(localized: "in the kitchen", comment: "Setup chat room phrase, used in 'How much light is there …?'"))
        case 3: Grammar.pt(String(localized: "in the bathroom", comment: "Setup chat room phrase, used in 'How much light is there …?'"))
        case 4: Grammar.pt(String(localized: "in the office", comment: "Setup chat room phrase, used in 'How much light is there …?'"))
        case 5: Grammar.pt(String(localized: "on the balcony", comment: "Setup chat room phrase, used in 'How much light is there …?'"))
        default: Grammar.pt(String(localized: "in “\(room)”", comment: "Setup chat room phrase for a custom room name, used in 'How much light is there …?'. Arg: room name"))
        }
    }

    private func question(_ s: Step) -> String {
        switch s {
        case .name: Grammar.pt(String(localized: "Hi! I'm Erty, your plants' best friend, here to help you care for them. What should I call you?", comment: "Setup chat: first mascot question"))
        case .place: Grammar.pt(String(localized: "Where do you live? Your city is enough. Local climate and weather change how much water your plants need.", comment: "Setup chat: mascot asks for city"))
        case .heating: Grammar.pt(String(localized: "Do you turn the heating on in winter?", comment: "Setup chat: mascot asks about home heating"))
        case .aircon: Grammar.pt(String(localized: "And air conditioning in summer?", comment: "Setup chat: mascot asks about AC"))
        case .air: Grammar.pt(String(localized: "Is the air at home dry or damp?", comment: "Setup chat: mascot asks about indoor humidity"))
        case .drafts: Grammar.pt(String(localized: "Any draughty windows or doors?", comment: "Setup chat: mascot asks about drafts"))
        case .outside: Grammar.pt(String(localized: "Do you grow plants outside too, on a balcony, terrace or in a garden?", comment: "Setup chat: mascot asks about outdoor plants"))
        case .weather: Grammar.pt(String(localized: "Want a heads-up before frost or a heatwave? I'll warn you so you can protect your outdoor plants.", comment: "Setup chat: mascot offers frost and heatwave push alerts for outdoor plants"))
        case .family: Grammar.pt(String(localized: "Who else lives with you? I'll warn you about any plant that could hurt them.", comment: "Setup chat: mascot asks about pets and small kids; multi-select"))
        case .rooms: Grammar.pt(String(localized: "Which rooms will have plants? Pick all that apply.", comment: "Setup chat: mascot asks which rooms; multi-select"))
        case .light(let room): Grammar.pt(String(localized: "How much light is there \(Self.roomPhrase(room))?", comment: "Setup chat: mascot asks light level of a room. Arg is a place phrase with preposition, e.g. 'in the living room' / 'na sala'"))
        case .plant: Grammar.pt(String(localized: "All set! Want to meet your first plant now? Just snap a photo.", comment: "Setup chat: mascot offers adding the first plant"))
        case .finished: ""
        }
    }

    // MARK: Flow

    private func open() async { await say(question(.name)) }

    private func say(_ s: String) async {
        withAnimation(.snappy) { typing = true }
        try? await Task.sleep(for: .milliseconds(600))
        withAnimation(.snappy) { typing = false; lines.append(Line(fromUser: false, text: s)) }
    }

    private func user(_ s: String) { withAnimation(.snappy) { lines.append(Line(fromUser: true, text: s)) } }

    private func tap(_ chip: Chip) {
        if chip.multi {
            if picked.contains(chip.id) { picked.remove(chip.id) } else { picked.insert(chip.id) }
            return
        }
        Task { await answer(chip) }
    }

    private func sendText() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        text = ""
        if step == .rooms {
            for r in t.split(whereSeparator: { ",;\n".contains($0) }) {
                let n = r.trimmingCharacters(in: .whitespaces).capitalizedFirst
                if !n.isEmpty { picked.insert(n) }
            }
            return
        }
        Task { await answer(Chip(id: "text", title: t)) }
    }

    private func next(_ s: Step) async {
        picked = []
        step = s
        if s == .finished { return }
        await say(question(s))
    }

    @MainActor private func answer(_ chip: Chip) async {
        let current = step
        // Multi-choice answers are echoed as one line of what was picked.
        let titles = chips.filter { picked.contains($0.id) }.map(\.title)   // before the bar hides
        switch current {
        case .family, .rooms:
            user(titles.isEmpty ? chip.title : titles.formatted(.list(type: .and)))
        default: user(chip.title)
        }
        step = .finished   // hide the answer bar while the mascot replies

        switch current {
        case .name:
            if chip.id == "text" { settings.ownerName = chip.title.capitalizedFirst }
            if !firstName.isEmpty {
                await say(Grammar.pt(String(localized: "Lovely to meet you, \(firstName)!", comment: "Setup chat: mascot greets user by first name")))
            }
            await next(.place)
        case .place:
            let before = climate.profile.map { "\($0.lat),\($0.lon),\($0.place)" }
            withAnimation(.snappy) { typing = true }
            if chip.id == "here" { await climate.useMyLocation() } else { await climate.setPlace(named: chip.title) }
            withAnimation(.snappy) { typing = false }
            let after = climate.profile.map { "\($0.lat),\($0.lon),\($0.place)" }
            if let e = climate.lastError, after == nil || after == before {
                await say(e)
                step = .place   // ask again without repeating the whole question
                return
            }
            if let p = climate.profile {
                await say(climate.hasClimate
                    ? Grammar.pt(String(localized: "Got it, \(p.place). \(climate.biome) climate. I'll keep an eye on the weather there.", comment: "Setup chat: place confirmed. Args: city, climate type name (capitalized, e.g. 'Humid subtropical')"))
                    : Grammar.pt(String(localized: "Got it, \(p.place). I'll keep an eye on the weather there.", comment: "Setup chat: place confirmed without climate data. Arg: city")))
            }
            await next(.heating)
        case .heating:
            climate.heating = chip.id != "no"
            await next(.aircon)
        case .aircon:
            climate.aircon = chip.id != "no"
            await next(.air)
        case .air:
            if let a = Climate.HomeAir.allCases.first(where: { chip.id == "air\($0.rawValue)" }) { climate.homeAir = a }
            await next(.drafts)
        case .drafts:
            climate.drafts = chip.id != "no"
            await next(.outside)
        case .outside:
            climate.growsOutside = chip.id == "yes"
            await say(Grammar.pt(String(localized: "Thanks! That tells me how fast pots dry out at your place.", comment: "Setup chat: mascot thanks after home conditions")))
            await next(climate.growsOutside ? .weather : .family)
        case .weather:
            if chip.id == "yes" { await WeatherWatch.set(true) }
            await next(.family)
        case .family:
            do {
                settings.hasCats = picked.contains("cats"); settings.hasDogs = picked.contains("dogs"); settings.hasKids = picked.contains("kids")
                if !picked.isEmpty { await say(Grammar.pt(String(localized: "Noted. I'll flag any plant that isn't safe for them.", comment: "Setup chat: mascot confirms pet/kid safety warnings"))) }
            }
            await next(.rooms)
        case .rooms:
            let rooms = titles
            for r in rooms { ensureRoom(r) }
            lightQueue = rooms
            await nextLight()
        case .light(let room):
            if let l = Self.lights.first(where: { chip.id == "light.\($0.0.rawValue)" }) { ensureRoom(room).light = l.0; saveRooms() }
            await nextLight()
        case .plant:
            if chip.id == "add" { addingPlant = true } else { wrapUp(addedPlant: false) }
        case .finished: break
        }
    }

    private func nextLight() async {
        if lightQueue.isEmpty { await next(.plant); return }
        await next(.light(lightQueue.removeFirst()))
    }

    @discardableResult private func ensureRoom(_ name: String) -> Space {
        let all = (try? ctx.fetch(FetchDescriptor<Space>())) ?? []
        if let s = all.first(where: { $0.name.folded == name.folded }) { return s }
        let outdoor = name == Grammar.pt(String(localized: "Balcony", comment: "Suggested room name"))
        let s = Space(name: name, light: outdoor ? .direct : .medium, outdoor: outdoor)
        ctx.insert(s); saveRooms()
        return s
    }

    private func saveRooms() {
        try? ctx.save()
        JungleRooms.sync((try? ctx.fetch(FetchDescriptor<Space>())) ?? [])
    }

    private func wrapUp(addedPlant: Bool) {
        step = .finished
        Task {
            let n = firstName
            await say(n.isEmpty
                ? Grammar.pt(String(localized: "Your jungle is ready. You can change any of this later in Settings.", comment: "Setup chat: closing line without a name"))
                : Grammar.pt(String(localized: "Your jungle is ready, \(n). You can change any of this later in Settings.", comment: "Setup chat: closing line. Arg: first name")))
            try? await Task.sleep(for: .seconds(1.2))
            finish()
        }
    }

    private func finish() {
        Task { await CareReminders.requestPermission() }
        onDone()
    }
}

/// Wrapping row of quick-reply chips. Multi-choice chips show a check when picked.
private struct SetupChips: View {
    let chips: [SetupChatView.Chip]
    let picked: Set<String>
    var onTap: (SetupChatView.Chip) -> Void

    var body: some View {
        SetupFlowLayout(spacing: 8) {
            ForEach(chips) { c in
                let on = picked.contains(c.id)
                Button { onTap(c) } label: {
                    HStack(spacing: 6) {
                        if on { Image(systemName: "checkmark").font(.footnote.weight(.bold)) }
                        else if let i = c.icon { Icon3DView(i, size: 20) }
                        Text(c.title)
                    }
                    .font(.subheadline.weight(on ? .semibold : .medium)).foregroundStyle(on ? Jungle.accentText : Jungle.text)
                    .padding(.horizontal, 14).frame(minHeight: 40)
                    .background(on ? Jungle.mint : Jungle.surface, in: Capsule())
                    .overlay(Capsule().strokeBorder(on ? Jungle.forest : Jungle.border, lineWidth: on ? 1.5 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: picked)
    }
}

/// Left-aligned wrapping layout.
private struct SetupFlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let r = rows(proposal.width ?? .infinity, subviews).size
        return CGSize(width: proposal.width.map { min($0, r.width) } ?? r.width, height: r.height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, p) in rows(bounds.width, subviews).points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }
    private func rows(_ width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var pts: [CGPoint] = [], x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            pts.append(CGPoint(x: x, y: y))
            x += sz.width + spacing; rowH = max(rowH, sz.height); maxX = max(maxX, x - spacing)
        }
        return (pts, CGSize(width: maxX, height: y + rowH))
    }
}

/// Three soft dots while the mascot "types".
private struct TypingBubble: View {
    @State private var on = false
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image("erty-idle").resizable().scaledToFit().frame(width: 32, height: 32).accessibilityHidden(true)
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle().fill(Jungle.subtle).frame(width: 7, height: 7)
                        .opacity(on ? 1 : 0.3)
                        .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: on)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5))
        }
        .onAppear { on = true }
        .accessibilityLabel(Grammar.pt(String(localized: "Typing", comment: "Accessibility label for the mascot typing indicator")))
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
