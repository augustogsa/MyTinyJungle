import SwiftUI
import SwiftData

/// Today: what's coming, patterns, streaks, milestones, gentle check-ins.
struct ComingUpCard: View {
    let plants: [Plant]
    let propagations: [Propagation]
    var onOpen: (UUID) -> Void = { _ in }
    @State private var expanded = false

    var body: some View {
        let all = InsightEngine.insights(plants: plants, propagations: propagations)
        if !all.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(String(localized: "Coming up", comment: "Section title for upcoming care"), action: all.count > 4 ? (expanded ? String(localized: "Less", comment: "Collapse list button; max 10 chars") : String(localized: "More", comment: "Expand list button; max 10 chars")) : nil) { withAnimation(.snappy) { expanded.toggle() } }
                VStack(spacing: 0) {
                    let shown = Array(all.prefix(expanded ? 12 : 4))
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, insight in
                        let plant = plants.first { $0.id == insight.plantID }
                        if let plant {
                            Button { onOpen(plant.id) } label: { InsightRow(insight: insight, plant: plant) }
                                .buttonStyle(.plain)
                        } else {
                            // No single plant: the names in the line are the links.
                            InsightRow(insight: insight, plant: nil)
                        }
                        if i < shown.count - 1 { Divider().padding(.leading, 58) }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 4)
                .jungleCard()
            }
            .accessibilityElement(children: .contain)
        }
    }
}

struct InsightRow: View {
    let insight: JungleInsight
    let plant: Plant?
    var current: UUID? = nil
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let plant { PlantAvatar(data: plant.photo, size: 40) } else { Icon3DView(insight.icon, size: 36).frame(width: 40, height: 40) }
                if plant != nil { Icon3DView(insight.icon, size: 18).offset(x: 4, y: 4) }
            }
            PlantText(insight.text, current: current ?? plant?.id)
                .font(.subheadline).foregroundStyle(Jungle.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

/// Plant page: the next two weeks for one plant.
struct PlantForecastSection: View {
    let plant: Plant
    @Query private var props: [Propagation]
    var body: some View {
        let items = CareForecast.items(for: [plant], propagations: props.filter { $0.parentID == plant.id }, respectPrefs: false)
            .filter { $0.plantID == plant.id }
        let insights = InsightEngine.insights(plants: [plant]).filter { $0.tone != .comingUp }.prefix(2)
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(String(localized: "The next two weeks", comment: "Section title, care calendar"))
            VStack(spacing: 0) {
                ForEach(Array(insights)) { i in
                    InsightRow(insight: i, plant: nil, current: plant.id)
                    Divider().padding(.leading, 52)
                }
                if items.isEmpty {
                    Text("Nothing planned. \(plant.name) is simply enjoying life.").font(.subheadline).foregroundStyle(Jungle.subtle).padding(.vertical, 12)
                }
                ForEach(Array(items.prefix(8).enumerated()), id: \.element.id) { i, f in
                    HStack(spacing: 12) {
                        Icon3DView(f.kind.icon, size: 28).frame(width: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            PlantText(f.line, current: plant.id).font(.subheadline).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
                            Text({ let w = CareForecast.dayWord(f.date); return w.prefix(1).uppercased() + w.dropFirst() }()).font(.caption).foregroundStyle(Jungle.subtle)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    if i < min(items.count, 8) - 1 { Divider().padding(.leading, 52) }
                }
                if let learned = plant.learnedDryDays {
                    Divider().padding(.leading, 52)
                    HStack(spacing: 12) {
                        Icon3DView(.growth, size: 28).frame(width: 40)
                        Text("We've learned \(plant.name) dries in about \(Int(learned.rounded())) days at your place, and we'll keep listening.")
                            .font(.caption).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 4)
            .jungleCard()
        }
    }
}

/// Settings: reminders, in a plant-parent voice.
struct ReminderSettingsView: View {
    @Environment(\.modelContext) private var ctx
    @State private var on = CareReminders.enabled
    @State private var time: Date = Calendar.current.date(bySettingHour: CareReminders.hour, minute: CarePrefs.minute, second: 0, of: Date()) ?? Date()
    @State private var quietOn = CarePrefs.quietOn
    @State private var quietStart = CarePrefs.quietStart
    @State private var quietEnd = CarePrefs.quietEnd
    @State private var chat = CarePrefs.chatNudges
    @State private var kinds: [ReminderKind: Bool] = Dictionary(uniqueKeysWithValues: ReminderKind.allCases.map { ($0, CarePrefs.isOn($0)) })
    @State private var denied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                JungleGroup(title: String(localized: "Your daily note", comment: "Settings group title for daily notification"), footer: String(localized: "Everything your plants need, gathered into one gentle note at the time you choose. Never a flood.", comment: "Settings footer")) {
                    JungleRow(icon: .notification, title: String(localized: "Little nudges from your plants", comment: "Settings row: daily reminders toggle")) {
                        Toggle("", isOn: Binding(get: { on }, set: { v in
                            on = v; CareReminders.enabled = v
                            Task { if v { denied = !(await CareReminders.requestPermission()) }; await CareReminders.reschedule(ctx) }
                        })).labelsHidden()
                    }
                    if on {
                        JungleDivider()
                        JungleRow(icon: .sunny, title: String(localized: "Visit me at", comment: "Settings row: reminder time, plant speaking; max 20 chars")) {
                            DatePicker("", selection: Binding(get: { time }, set: { t in
                                time = t
                                let c = Calendar.current.dateComponents([.hour, .minute], from: t)
                                CareReminders.hour = c.hour ?? 9; CarePrefs.minute = c.minute ?? 0
                                changed()
                            }), displayedComponents: .hourAndMinute).labelsHidden()
                        }
                    }
                }
                if denied {
                    Text("Notifications are off for My Tiny Jungle. You can let your plants reach you in the iPhone Settings app.")
                        .font(.footnote).foregroundStyle(Jungle.warmText).padding(.horizontal, 4)
                }
                if on {
                    JungleGroup(title: String(localized: "Quiet hours", comment: "Settings group title"), footer: String(localized: "Your plants are patient. Anything that would arrive during quiet hours waits until morning.", comment: "Settings footer")) {
                        JungleRow(icon: .moon, title: String(localized: "Let me rest", comment: "Settings row: quiet hours toggle; max 20 chars")) {
                            Toggle("", isOn: Binding(get: { quietOn }, set: { quietOn = $0; CarePrefs.quietOn = $0; changed() })).labelsHidden()
                        }
                        if quietOn {
                            JungleDivider()
                            JungleRow(icon: .moon, title: String(localized: "From", comment: "Quiet hours start; max 10 chars")) { hourPicker($quietStart) { CarePrefs.quietStart = $0 } }
                            JungleDivider()
                            JungleRow(icon: .sun, title: String(localized: "Until", comment: "Quiet hours end; max 10 chars")) { hourPicker($quietEnd) { CarePrefs.quietEnd = $0 } }
                        }
                    }
                    JungleGroup(title: String(localized: "What your plants can ask for", comment: "Settings group title: reminder kinds"), footer: String(localized: "Turn off anything you'd rather handle on your own. We'll still keep an eye on it in the app.", comment: "Settings footer")) {
                        ForEach(Array(ReminderKind.allCases.enumerated()), id: \.element) { i, k in
                            JungleRow(icon: k.icon, title: k.title, subtitle: k.blurb) {
                                Toggle("", isOn: Binding(get: { kinds[k] ?? true }, set: { kinds[k] = $0; CarePrefs.set(k, $0); changed() })).labelsHidden()
                            }
                            if i < ReminderKind.allCases.count - 1 { JungleDivider() }
                        }
                    }
                }
                JungleGroup(title: String(localized: "In the chat", comment: "Settings group title"), footer: String(localized: "Your plants will say hello on their own when something's due or they notice a pattern. At most once a day each.", comment: "Settings footer")) {
                    JungleRow(icon: .chat, title: String(localized: "Plants speak up", comment: "Settings row: proactive chat toggle; max 22 chars")) {
                        Toggle("", isOn: Binding(get: { chat }, set: { chat = $0; CarePrefs.chatNudges = $0 })).labelsHidden()
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .jungleBackdrop()
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hourPicker(_ b: Binding<Int>, save: @escaping (Int) -> Void) -> some View {
        Picker("", selection: Binding(get: { b.wrappedValue }, set: { b.wrappedValue = $0; save($0); changed() })) {
            ForEach(0..<24, id: \.self) { h in Text(Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: Date())!.formatted(date: .omitted, time: .shortened)).tag(h) }
        }.labelsHidden().tint(Jungle.subtle)
    }

    private func changed() { Task { await CareReminders.reschedule(ctx) } }

    static var summary: String {
        guard CareReminders.enabled else { return String(localized: "Resting for now", comment: "Reminder summary when off; max 24 chars") }
        let t = Calendar.current.date(bySettingHour: CareReminders.hour, minute: CarePrefs.minute, second: 0, of: Date())!.formatted(date: .omitted, time: .shortened)
        return String(localized: "One gentle note at \(t)", comment: "Reminder summary; %@ time like 9:00")
    }
}
