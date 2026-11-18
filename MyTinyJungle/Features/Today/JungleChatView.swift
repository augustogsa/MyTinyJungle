import SwiftUI
import SwiftData

/// The whole jungle in one thread: tell it what you did, ask anything, every plant can answer.
struct JungleChatView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.createdAt) private var plants: [Plant]
    @Query(sort: \ChatMessage.date) private var all: [ChatMessage]
    @State private var soilAsk = false
    private var messages: [ChatMessage] { all.filter { $0.plant == nil } }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: -10) {
                        ForEach(plants.prefix(5)) { p in
                            PlantAvatar(data: p.photo, size: 40).overlay(Circle().strokeBorder(Jungle.surface, lineWidth: 2))
                        }
                    }
                    .frame(maxWidth: .infinity).padding(.top, 8)
                    Text(messages.isEmpty ? "Tell your plants what you did today, or ask them anything. They'll answer." : "Everyone's listening." as LocalizedStringKey)
                        .font(.subheadline).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.bottom, 6)
                    ForEach(messages) { m in
                        Group {
                            if m.logCard != nil { LoggedCardView(message: m, plants: plants) }
                            else { MessageBubble(message: m, speaker: m.speakerID.flatMap { id in plants.first { $0.id == id } }) { send($0) } }
                        }
                        .id(m.id)
                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { proxy.scrollTo("bottom") }
            .onChange(of: messages.count) { withAnimation(.snappy) { proxy.scrollTo("bottom") } }
        }
        .safeAreaInset(edge: .bottom) {
            GlassComposer(placeholder: String(localized: "Tell me how your plants are doing…", comment: "Chat input placeholder"), showChips: !plants.isEmpty, onChip: { kind in
                if kind == .soilCheck { soilAsk = true } else { JungleBrain.quick(kind, plants: plants, in: ctx) }
            }) { text, photo in
                JungleBrain.handle(text, photo: photo, plant: nil, plants: plants, in: ctx)
            }
        }
        .jungleBackdrop()
        .navigationTitle("Your jungle")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("How does the soil feel?", isPresented: $soilAsk, titleVisibility: .visible) {
            ForEach(SoilState.allCases, id: \.self) { s in
                Button(s.label) { JungleBrain.quick(.soilCheck, soil: s, plants: plants, in: ctx) }
            }
        }
    }

    private func send(_ text: String) { JungleBrain.handle(text, plant: nil, plants: plants, in: ctx) }
}
