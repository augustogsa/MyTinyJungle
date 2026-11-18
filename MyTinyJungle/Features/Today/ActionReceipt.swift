import SwiftUI

/// Every care action shows up in the chat thread as a small centered receipt, wherever it was logged
/// (chips, Today, Care, plant page, notifications, guides, health checks, housemates).
struct ActionReceipt: View {
    let event: CareEvent
    var showPlant = false

    var body: some View {
        HStack(spacing: 6) {
            Icon3DView(Icon3D.care(event.kind), size: 16)
            Text(line).font(.footnote.weight(.medium)).foregroundStyle(Jungle.text)
            Text(when).font(.caption2).foregroundStyle(Jungle.subtle)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Jungle.incoming.opacity(0.6), in: Capsule())
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var when: String {
        let cal = Calendar.current
        let t = event.date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(event.date) { return t }
        if cal.isDateInYesterday(event.date) { return String(localized: "Yesterday \(t)", comment: "Chat receipt time; arg time") }
        return event.date.formatted(.dateTime.day().month(.abbreviated))
    }

    private var line: String {
        var s = event.kind.label
        if event.kind == .soilCheck, let soil = event.soil { s += " · \(soil.label)" }
        if event.kind == .move, !event.note.isEmpty { s += " · \(event.note)" }
        if showPlant, let p = event.plant { s += " · \(p.name)" }
        if event.source.hasPrefix("house:") {
            let id = String(event.source.dropFirst(6))
            s = String(localized: "\(Household.shared.name(id)): \(s)", comment: "Chat receipt: housemate did a care action. Args: first name, action like 'Watered'")
        }
        return s
    }
}

/// One row in a chat thread: a message or a care receipt, merged by time.
enum ThreadItem: Identifiable {
    case message(ChatMessage), action(CareEvent)
    var id: UUID { switch self { case .message(let m): m.id; case .action(let e): e.id } }
    var date: Date { switch self { case .message(let m): m.date; case .action(let e): e.date } }

    /// Receipts start where the conversation starts; with no messages yet, only the last few actions show.
    static func merge(_ messages: [ChatMessage], _ events: [CareEvent]) -> [ThreadItem] {
        var ev = events.filter { $0.kind != .note }.sorted { $0.date < $1.date }
        if let first = messages.map(\.date).min() { ev = ev.filter { $0.date >= first.addingTimeInterval(-600) } } else { ev = Array(ev.suffix(3)) }
        return (messages.map(ThreadItem.message) + ev.map(ThreadItem.action)).sorted { $0.date < $1.date }
    }
}
