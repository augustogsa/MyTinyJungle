import SwiftUI
import SwiftData

struct PlantChatView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    @Bindable var plant: Plant
    @State private var showProfile = false
    @State private var soilAsk = false

    private var messages: [ChatMessage] { (plant.messages ?? []).sorted { $0.date < $1.date } }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    statusCard
                    ForEach(messages) { m in
                        MessageBubble(message: m, showAvatar: false) { send($0) }.id(m.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .onAppear { greetIfNeeded() }
            .onChange(of: messages.count) { withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) } }
        }
        .safeAreaInset(edge: .bottom) {
            GlassComposer(placeholder: String(localized: "Message \(plant.name)…", comment: "Chat composer placeholder; arg plant name; max 30 chars"), onChip: { kind in
                if kind == .soilCheck { soilAsk = true } else { JungleBrain.quick(kind, plants: [plant], in: ctx) }
            }) { text, photo in
                JungleBrain.handle(text, photo: photo, plant: plant, plants: plants, in: ctx)
            }
        }
        .jungleBackdrop()
        .navigationTitle(plant.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button { showProfile = true } label: { Image(systemName: "info.circle") }.accessibilityLabel("\(plant.name)'s profile")
        }
        .sheet(isPresented: $showProfile) { PlantProfileView(plant: plant) }
        .confirmationDialog("How does the soil feel?", isPresented: $soilAsk, titleVisibility: .visible) {
            ForEach(SoilState.allCases, id: \.self) { s in
                Button(s.label) { JungleBrain.quick(.soilCheck, soil: s, plants: [plant], in: ctx) }
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            PlantAvatar(data: plant.photo, size: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(plant.species?.commonName ?? String(localized: "Unknown species", comment: "Shown when species not set; max 20 chars")).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                Text(statusLine).font(.caption).foregroundStyle(Jungle.subtle)
            }
            Spacer()
        }
        .padding(12)
        .jungleCard()
        .padding(.top, 8)
        .onTapGesture { showProfile = true }
    }

    private var statusLine: String {
        var parts: [String] = []
        if let w = plant.lastEvent(.water) { parts.append(String(localized: "Watered \(CareEngine.relative(w.date))", comment: "Chat status; arg relative date like 2 days ago; max 26 chars")) }
        parts.append(String(localized: "dries in ~\(Int(CareEngine.expectedDryDays(for: plant).rounded())) d", comment: "Chat status: soil dries in about N days (d = days abbrev); lowercase; max 18 chars"))
        if !plant.location.isEmpty { parts.append(plant.location) }
        return parts.joined(separator: " · ")
    }

    private func send(_ text: String) {
        JungleBrain.handle(text, plant: plant, plants: plants, in: ctx)
    }

    /// The plant speaks first when it has something to say today.
    private func greetIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard !messages.contains(where: { !$0.fromUser && $0.date >= today }) else { return }
        if let r = CareEngine.requests(for: plant).first(where: { $0.priority <= 2 }) {
            JungleBrain.reply(PlantVoice.say(r, plant: plant), plant: plant, in: ctx, suggestions: Answerer.suggestions(for: r))
        } else if !messages.isEmpty {
            JungleBrain.reply(PlantVoice.happy(plant), plant: plant, in: ctx)
        }
        try? ctx.save()
    }
}
