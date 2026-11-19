import SwiftUI
import SwiftData

/// Month calendar: each day shows a ring (done vs planned) and dots for what was done.
/// Tap a day for its full history and plan.
struct CareCalendarView: View {
    let plants: [Plant]
    let tasks: [CareTask]
    /// Day picked in the Care tab's week strip; drives this calendar.
    var day: Date? = nil
    /// False on a wide page, where the agenda beside the calendar already shows the picked day.
    var showsDetail = true
    /// False when only the picked day's detail is wanted (the wide Care page's trailing page).
    var showsGrid = true
    /// Reports a tapped day to the page (the wide Care page filters its agenda with it).
    var onSelect: ((Date) -> Void)? = nil
    @Query(sort: \CareEvent.date, order: .reverse) private var events: [CareEvent]
    @State private var month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    @State private var selected = Calendar.current.startOfDay(for: Date())
    private let cal = Calendar.current

    private var careEvents: [CareEvent] { events.filter { $0.plant != nil && $0.note != "safety-ack" } }
    private var doneByDay: [Date: [CareEvent]] { Dictionary(grouping: careEvents) { cal.startOfDay(for: $0.date) } }
    private var plannedByDay: [Date: [AgendaItem]] {
        Dictionary(grouping: Agenda.items(plants: plants, tasks: tasks, days: 62)) { cal.startOfDay(for: $0.date) }
    }

    var body: some View {
        let done = doneByDay, planned = plannedByDay
        VStack(alignment: .leading, spacing: 16) {
            if showsGrid {
            VStack(spacing: 12) {
                HStack {
                    Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("Previous month")
                    Spacer()
                    Text(month.formatted(.dateTime.month(.wide).year())).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                    Spacer()
                    Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .accessibilityLabel("Next month")
                }
                .foregroundStyle(Jungle.accentText)
                let symbols = cal.veryShortStandaloneWeekdaySymbols
                let first = cal.firstWeekday - 1
                HStack { ForEach(0..<7, id: \.self) { i in Text(symbols[(i + first) % 7]).font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle).frame(maxWidth: .infinity) } }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 10) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, d in
                        if let d {
                            Button { withAnimation(.snappy) { selected = d }; onSelect?(d) } label: {
                                DayCell(date: d, done: done[d] ?? [], planned: planned[d]?.count ?? 0, selected: cal.isDate(d, inSameDayAs: selected))
                            }
                            .buttonStyle(.plain)
                        } else { Color.clear.frame(height: 50) }
                    }
                }
            }
            .padding(12).jungleCard()
            }
            if showsDetail { dayDetail(done: done[selected] ?? [], planned: planned[selected] ?? []) }
        }
        .sensoryFeedback(.selection, trigger: selected)
        .onChange(of: day, initial: true) { _, d in
            guard let d else { return }
            withAnimation(.snappy) { selected = cal.startOfDay(for: d); month = cal.date(from: cal.dateComponents([.year, .month], from: d))! }
        }
    }

    private var days: [Date?] {
        let range = cal.range(of: .day, in: .month, for: month)!
        let weekday = cal.component(.weekday, from: month)
        let lead = (weekday - cal.firstWeekday + 7) % 7
        return Array(repeating: nil, count: lead) + range.map { cal.date(byAdding: .day, value: $0 - 1, to: month)! }
    }

    private func shift(_ n: Int) { withAnimation(.snappy) { month = cal.date(byAdding: .month, value: n, to: month)! } }

    private func weekStrip(done: [Date: [CareEvent]], planned: [Date: [AgendaItem]]) -> some View {
        let today = cal.startOfDay(for: Date())
        let start = cal.dateInterval(of: .weekOfYear, for: today)!.start
        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                let d = cal.date(byAdding: .day, value: i, to: start)!
                Button { withAnimation(.snappy) { selected = d; month = cal.date(from: cal.dateComponents([.year, .month], from: d))! } } label: {
                    VStack(spacing: 6) {
                        Text(d.formatted(.dateTime.weekday(.narrow))).font(.caption.weight(.semibold))
                            .foregroundStyle(cal.isDateInToday(d) ? Jungle.warmText : Jungle.subtle)
                        DayRing(progress: progress(done[d]?.count ?? 0, planned[d]?.count ?? 0, future: d > today), size: 38)
                            .overlay { Text(d.formatted(.dateTime.day())).font(.caption.weight(cal.isDate(d, inSameDayAs: selected) ? .bold : .regular)).foregroundStyle(Jungle.text) }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 8).jungleCard()
    }

    @ViewBuilder private func dayDetail(done: [CareEvent], planned: [AgendaItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(cal.isDateInToday(selected) ? Grammar.pt(String(localized: "Today", comment: "Care agenda day header")) : selected.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
            if done.isEmpty && planned.isEmpty {
                ErtyEmpty(text: selected > Date() ? Grammar.pt(String(localized: "Nothing planned.", comment: "Care calendar: empty future day")) : Grammar.pt(String(localized: "Nothing logged this day.", comment: "Care calendar: empty past day")), mood: selected > Date() ? .happy : .notes)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
            }
            if !done.isEmpty {
                VStack(spacing: 0) {
                    ForEach(done) { e in
                        HStack(spacing: 12) {
                            PlantAvatar(data: e.plant?.photo, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(Grammar.pt(String(localized: "\(e.kind.label) · \(e.plant?.name ?? String())", comment: "Care calendar row: care action and plant name"))).foregroundStyle(Jungle.text)
                                Text(e.date.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(Jungle.subtle)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Jungle.leaf)
                        }
                        .padding(12)
                        if e.id != done.last?.id { Divider().padding(.leading, 60) }
                    }
                }
                .jungleCard()
            }
            if !planned.isEmpty {
                Text("Planned").font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.subtle).padding(.top, 4)
                VStack(spacing: 0) {
                    ForEach(planned) { item in
                        HStack(spacing: 12) {
                            if let p = item.plant { PlantAvatar(data: p.photo, size: 36) }
                            Text(item.title).foregroundStyle(Jungle.text)
                            Spacer()
                            Icon3DView(Icon3D.care(item.kind), size: 26)
                        }
                        .padding(12)
                        if item.id != planned.last?.id { Divider().padding(.leading, 60) }
                    }
                }
                .jungleCard()
            }
        }
    }

    private func progress(_ done: Int, _ planned: Int, future: Bool) -> Double {
        if future { return 0 }
        if done + planned == 0 { return 0 }
        return Double(done) / Double(done + planned)
    }
}

struct DayRing: View {
    let progress: Double
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            Circle().stroke(Jungle.mint, lineWidth: size * 0.14)
            Circle().trim(from: 0, to: progress).stroke(Jungle.leaf, style: StrokeStyle(lineWidth: size * 0.14, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

private struct DayCell: View {
    let date: Date
    let done: [CareEvent]
    let planned: Int
    let selected: Bool

    var body: some View {
        let cal = Calendar.current
        let future = date > cal.startOfDay(for: Date())
        let kinds = Array(Set(done.map(\.kind))).prefix(3)
        VStack(spacing: 3) {
            ZStack {
                if selected { Circle().fill(Jungle.forest) }
                else if cal.isDateInToday(date) { Circle().strokeBorder(Jungle.forest, lineWidth: 1.5) }
                Text(date.formatted(.dateTime.day())).font(.subheadline.weight(cal.isDateInToday(date) ? .bold : .regular))
                    .foregroundStyle(selected ? Color.white : Jungle.text)
            }
            .frame(width: 34, height: 34)
            HStack(spacing: 2) {
                ForEach(Array(kinds), id: \.self) { k in Circle().fill(color(k)).frame(width: 5, height: 5) }
                if future && planned > 0 { Circle().strokeBorder(Jungle.leaf, lineWidth: 1).frame(width: 5, height: 5) }
            }
            .frame(height: 6)
        }
        .frame(height: 50)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Grammar.pt(String(localized: "\(date.formatted(date: .complete, time: .omitted)), \(done.count) done, \(planned) planned", comment: "Accessibility for calendar day: date, done count, planned count")))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func color(_ k: CareKind) -> Color {
        switch k { case .water: .blue; case .feed: Jungle.leaf; case .repot, .prune: Jungle.terracotta; case .health, .treat: .red; default: Jungle.sage }
    }
}
