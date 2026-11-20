import WidgetKit
import SwiftUI

struct JungleEntry: TimelineEntry {
    let date: Date
    let snap: JungleWidgetSnapshot?
}

struct JungleProvider: TimelineProvider {
    func placeholder(in context: Context) -> JungleEntry { JungleEntry(date: .now, snap: .sample) }
    func getSnapshot(in context: Context, completion: @escaping (JungleEntry) -> Void) {
        completion(JungleEntry(date: .now, snap: context.isPreview ? (JungleWidgetSnapshot.load() ?? .sample) : JungleWidgetSnapshot.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<JungleEntry>) -> Void) {
        // The app reloads us after every care change; redraw past midnight so the next care rolls in.
        let tomorrow = Calendar.current.startOfDay(for: .now).addingTimeInterval(86_400 + 300)
        completion(Timeline(entries: [JungleEntry(date: .now, snap: JungleWidgetSnapshot.load())], policy: .after(min(tomorrow, .now.addingTimeInterval(3 * 3600)))))
    }
}

enum WTheme {
    static let ink = Color(light: 0x3E4E3D, dark: 0xFFFFFF)
    static let subtle = Color(light: 0x5C6B5B, dark: 0x9E9EA4)
    static let accent = Color(light: 0x3F7A4A, dark: 0x6FD58C)
    static let warm = Color(light: 0xA9502F, dark: 0xFFB496)
    static let bg = Color(light: 0xF6F3EA, dark: 0x1C1C1E)
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { t in
            let v = t.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        })
    }
}

private let todayURL = URL(string: "mytinyjungle://today")!
private func plantURL(_ id: String?) -> URL { id.flatMap { URL(string: "mytinyjungle://plant/\($0)") } ?? todayURL }

struct JungleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var rendering
    let entry: JungleEntry

    var body: some View {
        Group {
            if let s = entry.snap {
                switch family {
                case .systemSmall: small(s)
                case .systemMedium: medium(s)
                case .accessoryCircular: circular(s)
                case .accessoryRectangular: rectangular(s)
                case .accessoryInline: inline(s)
                default: medium(s)
                }
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) { WTheme.bg }
        .widgetURL(todayURL)
    }

    private var empty: some View {
        VStack(spacing: 4) {
            if family == .accessoryInline || family == .accessoryCircular {
                Image(systemName: "leaf.fill")
            } else {
                Image("erty-wave").resizable().scaledToFit().frame(maxHeight: 60).accessibilityHidden(true)
                Text("Open My Tiny Jungle to start", comment: "Widget: no data yet; max 30 chars").font(.caption).multilineTextAlignment(.center).foregroundStyle(WTheme.subtle)
            }
        }
    }

    private func dueHeadline(_ s: JungleWidgetSnapshot) -> Text {
        s.due.isEmpty ? Text("All good today", comment: "Widget: no care due; max 18 chars") : Text("^[\(s.due.count) plants](inflect: true) today", comment: "Widget: number of plants needing care today; plural; max 18 chars")
    }

    private func small(_ s: JungleWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image("erty-\(s.mood)").resizable().scaledToFit().frame(width: 44, height: 44).accessibilityHidden(true)
                Spacer(minLength: 0)
                if !s.due.isEmpty {
                    Text("\(s.due.count)").font(.system(.title, design: .rounded).weight(.bold)).foregroundStyle(s.due.contains(where: \.urgent) ? WTheme.warm : WTheme.accent)
                        .accessibilityHidden(true)
                }
            }
            dueHeadline(s).font(.system(.headline, design: .rounded)).foregroundStyle(WTheme.ink).lineLimit(1).minimumScaleFactor(0.8)
            if let d = s.due.first {
                Label { Text("\(d.name): \(d.need)") } icon: { Image(systemName: d.symbol) }
                    .font(.caption).foregroundStyle(d.urgent ? WTheme.warm : WTheme.subtle).lineLimit(2)
            } else if let n = s.next {
                Text(n.line).font(.caption).foregroundStyle(WTheme.subtle).lineLimit(2)
            } else {
                Text(s.moodLine).font(.caption).foregroundStyle(WTheme.subtle).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private func medium(_ s: JungleWidgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Image("erty-\(s.mood)").resizable().scaledToFit().frame(width: 56, height: 56).accessibilityHidden(true)
                Text(s.moodLine).font(.caption.weight(.semibold)).foregroundStyle(WTheme.ink).lineLimit(2).frame(width: 84, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 5) {
                dueHeadline(s).font(.system(.headline, design: .rounded)).foregroundStyle(WTheme.ink)
                ForEach(s.due.prefix(3), id: \.id) { d in
                    Link(destination: plantURL(d.id)) {
                        Label { Text("\(d.name): \(d.need)").lineLimit(1) } icon: { Image(systemName: d.symbol).foregroundStyle(d.urgent ? WTheme.warm : WTheme.accent) }
                            .font(.caption).foregroundStyle(WTheme.ink)
                    }
                }
                Spacer(minLength: 0)
                if let n = s.next {
                    Link(destination: plantURL(n.id)) {
                        Label { Text(n.line).lineLimit(1) } icon: { Image(systemName: "calendar") }
                            .font(.caption2).foregroundStyle(WTheme.subtle)
                    }
                    .accessibilityLabel(Text("Next: \(n.line)", comment: "VoiceOver: widget next care line"))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func circular(_ s: JungleWidgetSnapshot) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: s.due.isEmpty ? "leaf.fill" : (s.due.first?.symbol ?? "drop.fill")).font(.caption)
                Text("\(s.due.count)").font(.system(.title3, design: .rounded).weight(.bold))
            }
        }
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dueHeadline(s))
    }

    private func rectangular(_ s: JungleWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label { dueHeadline(s) } icon: { Image(systemName: "leaf.fill") }.font(.headline).widgetAccentable()
            if s.due.isEmpty {
                if let n = s.next { Text(n.line).font(.caption).lineLimit(2) } else { Text(s.moodLine).font(.caption) }
            } else {
                Text(s.due.prefix(3).map(\.name).formatted(.list(type: .and))).font(.caption).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func inline(_ s: JungleWidgetSnapshot) -> some View {
        Label { dueHeadline(s) } icon: { Image(systemName: "leaf.fill") }
    }
}

struct JungleTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JungleToday", provider: JungleProvider()) { JungleWidgetView(entry: $0) }
            .configurationDisplayName(Text("Jungle Today", comment: "Widget gallery name; max 20 chars"))
            .description(Text("Plants that need you today, the next care and Erty's mood.", comment: "Widget gallery description"))
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct JungleWidgetsBundle: WidgetBundle {
    var body: some Widget { JungleTodayWidget() }
}

#Preview(as: .systemMedium) { JungleTodayWidget() } timeline: { JungleEntry(date: .now, snap: .sample) }
