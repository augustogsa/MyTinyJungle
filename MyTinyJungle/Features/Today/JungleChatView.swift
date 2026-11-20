import SwiftUI
import SwiftData

/// The whole jungle in one thread: tell it what you did, ask anything, every plant can answer.
struct JungleChatView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.createdAt) private var plants: [Plant]
    @Query(sort: \ChatMessage.date) private var all: [ChatMessage]
    @State private var soilAsk = false
    private var messages: [ChatMessage] { all.filter { $0.plant == nil } }
    /// Actions logged anywhere that don't already have a card in this thread.
    private var items: [ThreadItem] {
        let carded = Set(messages.compactMap(\.logCard).flatMap { $0.entries.map(\.eventID) })
        let since = messages.first?.date ?? .distantPast
        let events = plants.flatMap { $0.events ?? [] }.filter { !carded.contains($0.id) && $0.date >= since && $0.source != "onboarding" }
        return ThreadItem.merge(messages, events)
    }

    var body: some View { tracked.screen("jungle_chat") }
    @ViewBuilder private var tracked: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: -10) {
                        ForEach(plants.prefix(5)) { p in
                            PlantAvatar(data: p.photo, size: 40).overlay(Circle().strokeBorder(Jungle.surface, lineWidth: 2))
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.top, 8)
                    Text("Tell your plants what you did today, or ask them anything. They'll answer.")
                        .font(.subheadline).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.bottom, 6)
                    ForEach(items) { item in
                        switch item {
                        case .message(let m):
                            Group {
                                if m.logCard != nil { LoggedCardView(message: m, plants: plants) }
                                else { MessageBubble(message: m, speaker: m.speakerID.flatMap { id in plants.first { $0.id == id } }) { send($0) } }
                            }
                            .id(m.id)
                        case .action(let e): ActionReceipt(event: e, showPlant: true).id(e.id)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .defaultScrollAnchor(.bottom, for: .sizeChanges)
            .onChange(of: items.count) { withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) } }
        }
        .safeAreaInset(edge: .bottom) {
            GlassComposer(placeholder: Grammar.pt(String(localized: "Tell me how your plants are doing…", comment: "Chat input placeholder")), showChips: !plants.isEmpty, onChip: { kind in
                if kind == .soilCheck { soilAsk = true } else { JungleBrain.quick(kind, plants: plants, in: ctx, announce: true) }
            }) { text, photo in
                JungleBrain.handle(text, photo: photo, plant: nil, plants: plants, in: ctx)
            }
        }
        .jungleBackdrop()
        .navigationTitle("Your jungle")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("How does the soil feel?", isPresented: $soilAsk, titleVisibility: .visible) {
            ForEach(SoilState.allCases, id: \.self) { s in
                Button(s.label) { JungleBrain.quick(.soilCheck, soil: s, plants: plants, in: ctx, announce: true) }
            }
        }
    }

    private func send(_ text: String) { JungleBrain.handle(text, plant: nil, plants: plants, in: ctx) }
}
