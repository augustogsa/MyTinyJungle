import SwiftUI
import SwiftData
import PhotosUI

/// Rich "logged" card in the jungle chat: real plant photos, what was recorded,
/// what happens next, and actions (undo, change day, add photo, open plant).
struct LoggedCardView: View {
    @Environment(\.modelContext) private var ctx
    let message: ChatMessage
    let plants: [Plant]
    @State private var pick: PhotosPickerItem?
    @State private var pickingDate = false
    @State private var customDate = Date()

    private var card: LogCard? { message.logCard }

    private struct Row: Identifiable {
        let plant: Plant
        let kinds: [CareKind]
        let photos: [Data]
        var id: UUID { plant.id }
    }

    private var rows: [Row] {
        guard let card else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: plants.map { ($0.id, $0) })
        var order: [UUID] = []
        var grouped: [UUID: [LogCard.Entry]] = [:]
        for e in card.entries {
            if grouped[e.plantID] == nil { order.append(e.plantID) }
            grouped[e.plantID, default: []].append(e)
        }
        return order.compactMap { id in
            guard let p = byID[id] else { return nil }
            let entries = grouped[id] ?? []
            let events = entries.compactMap { en in p.events?.first { $0.id == en.eventID } }
            let kinds = entries.compactMap { CareKind(rawValue: $0.kind) }.filter { $0 != .photo }
            return Row(plant: p, kinds: kinds.uniqued(), photos: events.compactMap(\.photo))
        }
    }

    var body: some View {
        if let card {
            VStack(alignment: .leading, spacing: 12) {
                header(card)
                ForEach(rows) { row in
                    NavigationLink(value: row.plant.id) { plantRow(row, undone: card.undone) }
                        .buttonStyle(.plain)
                        .disabled(card.undone)
                }
                if !card.undone { actions(card) }
            }
            .padding(14)
            .jungleCard()
            .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).stroke(Jungle.border, lineWidth: 0.5))
            .opacity(card.undone ? 0.6 : 1)
            .animation(.snappy, value: card.undone)
            .onChange(of: pick) { _, item in
                guard let item else { return }
                Task {
                    if let d = try? await item.loadTransferable(type: Data.self) {
                        JungleBrain.attachPhoto(ImageShrinker.jpeg(d), to: message, plants: plants, in: ctx)
                    }
                    pick = nil
                }
            }
            .sheet(isPresented: $pickingDate) {
                NavigationStack {
                    DatePicker("When?", selection: $customDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical).padding()
                        .navigationTitle("When did it happen?")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { pickingDate = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") { JungleBrain.redate(message, to: customDate, plants: plants, in: ctx); pickingDate = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func header(_ card: LogCard) -> some View {
        HStack(spacing: 8) {
            Image(systemName: card.undone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(card.undone ? Jungle.subtle : Jungle.leaf)
                .font(.system(.title3, design: .rounded))
                .contentTransition(.symbolEffect(.replace))
            Text(card.undone ? "Undone" : "Logged" as LocalizedStringKey).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            Spacer()
            Text(dayLabel(card.date)).font(.subheadline).foregroundStyle(Jungle.subtle)
        }
        .accessibilityElement(children: .combine)
    }

    private func plantRow(_ row: Row, undone: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                PlantAvatar(data: row.plant.photo, size: 52)
                if let k = row.kinds.first {
                    Icon3DView(Icon3D.care(k), size: 18)
                        .frame(width: 24, height: 24)
                        .background(Jungle.surface, in: Circle())
                        .overlay(Circle().stroke(Jungle.mist, lineWidth: 2))
                        .offset(x: 4, y: 4)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(row.plant.name).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                    Spacer()
                    if !undone { Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle) }
                }
                Text(row.kinds.map(\.label).formatted(.list(type: .and)))
                    .font(.subheadline).foregroundStyle(Jungle.text)
                    .strikethrough(undone)
                if !undone, let next = nextStep(row) {
                    Label(next.text, systemImage: next.symbol)
                        .font(.caption).foregroundStyle(Jungle.subtle)
                }
                if !row.photos.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(row.photos.indices, id: \.self) { i in
                            if let img = UIImage(data: row.photos[i]) {
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func actions(_ card: LogCard) -> some View {
        HStack(spacing: 8) {
            Menu {
                Button("Today") { redate(daysAgo: 0) }
                Button("Yesterday") { redate(daysAgo: 1) }
                Button("2 days ago") { redate(daysAgo: 2) }
                Button("Pick a date…") { customDate = card.date; pickingDate = true }
            } label: {
                Label("Day", systemImage: "calendar")
            }
            PhotosPicker(selection: $pick, matching: .images) {
                Label("Photo", systemImage: "camera")
            }
            Spacer()
            Button(role: .destructive) {
                withAnimation { JungleBrain.undo(message, plants: plants, in: ctx) }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
        }
        .font(.subheadline.weight(.medium))
        .buttonStyle(.bordered).fontDesign(.rounded)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
    }

    private func redate(daysAgo: Int) {
        let base = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        JungleBrain.redate(message, to: base, plants: plants, in: ctx)
    }

    private func dayLabel(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return Grammar.pt(String(localized: "Today, \(d.formatted(date: .omitted, time: .shortened))", comment: "Logged card date; %@ time")) }
        if cal.isDateInYesterday(d) { return Grammar.pt(String(localized: "Yesterday", comment: "Logged card date")) }
        return d.formatted(.dateTime.weekday(.wide).day().month())
    }

    /// What the engine now expects, so the card says what happens next.
    private func nextStep(_ row: Row) -> (text: String, symbol: String)? {
        let p = row.plant
        if row.kinds.contains(.water) {
            let days = Int(CareEngine.expectedDryDays(for: p).rounded())
            let since = p.lastEvent(.water).map { CareEngine.days(from: $0.date) } ?? 0
            let left = max(0, days - Int(since.rounded(.down)))
            return (left == 0 ? Grammar.pt(String(localized: "Soil check due today", comment: "Next step after watering")) : Grammar.pt(String(localized: "I'll ask for a soil check in ~\(left) days", comment: "Next step after watering; %lld days (plural)")), "hand.point.down")
        }
        if row.kinds.contains(.feed), let s = p.species {
            return (CareEngine.isGrowingSeason() ? Grammar.pt(String(localized: "Next feed in about \(Int(s.feedWeeks)) weeks", comment: "Next step after feeding; %lld weeks (plural)")) : Grammar.pt(String(localized: "Next feed in about \(Int(s.feedWeeks)) weeks, but pause in winter", comment: "Next step after feeding in winter; %lld weeks (plural)")), "leaf.arrow.triangle.circlepath")
        }
        if row.kinds.contains(.repot) { return (Grammar.pt(String(localized: "Recovery: go easy on water for 2 weeks, and no food for 6 weeks", comment: "Next step after repotting")), "heart.text.square") }
        if row.kinds.contains(.move) { return (Grammar.pt(String(localized: "New spot: I'll watch for stress over the next 2–3 weeks", comment: "Next step after moving plant")), "eye") }
        if row.kinds.contains(.newLeaf) { return (Grammar.pt(String(localized: "Added to my growth timeline", comment: "Next step after new leaf")), "chart.line.uptrend.xyaxis") }
        if row.kinds.contains(.mist), let s = p.species { return (Grammar.pt(String(localized: "I like humidity above \((s.humidityMin / 100).formatted(.percent.precision(.fractionLength(0))))", comment: "Next step after misting; %@ percentage")), "humidity") }
        return nil
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] { var seen = Set<Element>(); return filter { seen.insert($0).inserted } }
}
