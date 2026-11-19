import SwiftUI
import SwiftData

/// Care: this week / month agenda from the engine, seasonal guide, travel plan, propagation.
struct CareView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.createdAt) private var plants: [Plant]
    @Query private var tasks: [CareTask]
    enum Range: String, CaseIterable { case week = "Week", month = "Month", calendar = "Calendar", season = "Season"
        var label: String {
            switch self {
            case .week: Grammar.pt(String(localized: "Week", comment: "Care range segment; max 8 chars"))
            case .month: Grammar.pt(String(localized: "Month", comment: "Care range segment; max 8 chars"))
            case .calendar: Grammar.pt(String(localized: "Calendar", comment: "Care range segment; max 10 chars"))
            case .season: Grammar.pt(String(localized: "Season", comment: "Care range segment; max 8 chars"))
            }
        }
    }
    @State private var range: Range = .week
    @State private var adding = false
    /// Day picked in the week strip; nil shows every day.
    @State private var selectedDay: Date?
    @State private var weekOffset = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TabHeader(title: Grammar.pt(String(localized: "Care", comment: "Care tab title")), subtitle: stripMonth) {
                        HeaderButton(symbol: "plus", label: Grammar.pt(String(localized: "Add care task", comment: "Accessibility label for add task button"))) { adding = true }
                    }
                    WithPageSpread { spread in
                    TwoPage(spacing: 14) {
                    if spread.isWide {
                        // Room for the whole month: the calendar drives the agenda on the other page.
                        CareCalendarView(plants: plants, tasks: tasks, day: selectedDay, showsDetail: false) { d in
                            withAnimation(.snappy) {
                                selectedDay = Calendar.current.isDate(d, inSameDayAs: selectedDay ?? .distantPast) ? nil : d
                                if range == .calendar || range == .season { range = .week }
                            }
                        }
                        CareStatsCard(plants: plants, tasks: tasks)
                        HouseholdTodayCard(plants: plants)
                    } else {
                        WeekStrip(plants: plants, tasks: tasks, selected: $selectedDay, offset: $weekOffset)
                        HouseholdTodayCard(plants: plants)
                        Picker("Range", selection: $range) { ForEach(Range.allCases, id: \.self) { Text($0.label) } }.pickerStyle(.segmented)
                    }
                    HStack(spacing: 10) {
                        NavigationLink { TravelPlanView() } label: { shortcut(Grammar.pt(String(localized: "Travel care", comment: "Care shortcut tile; max 12 chars")), "airplane") }
                        NavigationLink { PropagationListView() } label: { shortcut(Grammar.pt(String(localized: "Propagate", comment: "Care shortcut tile: propagation cuttings; max 12 chars")), "scissors") }
                        NavigationLink { GuidesView() } label: { shortcut(Grammar.pt(String(localized: "How-to", comment: "Care shortcut tile: guides; max 12 chars")), "book.fill") }
                    }
                    .buttonStyle(.plain)
                    } trailing: {
                    if spread.isWide {
                        Picker("Range", selection: Binding(get: { range }, set: { r in withAnimation(.snappy) { range = r; selectedDay = nil } })) { ForEach(Range.allCases.filter { $0 != .calendar }, id: \.self) { Text($0.label) } }.pickerStyle(.segmented)
                    }
                    if spread.isWide, let d = selectedDay, range != .season {
                        CareCalendarView(plants: plants, tasks: tasks, day: d, showsGrid: false)
                    } else {
                    switch range {
                    case .season: SeasonGuideView(plants: plants)
                    case .calendar: if spread.isWide { agenda } else { CareCalendarView(plants: plants, tasks: tasks, day: selectedDay) }
                    default: agenda
                    }
                    }
                    }
                    }
                }
                .padding(16)
            }
            .measuresPageSpread()
            .jungleBackdrop()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $adding) { AddTaskView(plants: plants) }
            .animation(.snappy, value: range)
            .onChange(of: selectedDay) { _, d in if d != nil && range == .season { range = .week } }
        }
    }

    private func shortcut(_ t: String, _ s: String) -> some View {
        VStack(spacing: 6) {
            SmartIcon(symbol: s, size: 34)
            Text(t).font(.caption.weight(.medium)).foregroundStyle(Jungle.text)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).jungleCard()
    }

    private var stripMonth: String {
        let d = Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: selectedDay ?? Date()) ?? Date()
        return (selectedDay ?? d).formatted(.dateTime.month(.wide).year())
    }

    private var agenda: some View {
        let cal0 = Calendar.current
        let all = Agenda.items(plants: plants, tasks: tasks, days: selectedDay.map { max(7, Int(($0.timeIntervalSinceNow / 86_400).rounded(.up)) + 1) } ?? (range == .week ? 7 : 30))
        let items = selectedDay.map { d in all.filter { cal0.isDate($0.date, inSameDayAs: d) } } ?? all
        let cal = Calendar.current
        let grouped = Dictionary(grouping: items) { cal.startOfDay(for: $0.date) }
        return VStack(alignment: .leading, spacing: 14) {
            if items.isEmpty {
                ErtyEmpty(text: plants.isEmpty ? Grammar.pt(String(localized: "Add a plant and its care shows up here.", comment: "Care agenda empty state with no plants")) : selectedDay != nil ? Grammar.pt(String(localized: "Nothing planned this day.", comment: "Care agenda empty for selected day")) : Grammar.pt(String(localized: "Nothing planned. Your jungle is relaxing.", comment: "Care agenda empty state; playful")))
            }
            let days = grouped.keys.sorted()
            ForEach(days, id: \.self) { day in
                if AdSlots.agendaAd(before: days.firstIndex(of: day) ?? 0) { NativeAdCard(slot: "agenda") }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(dayTitle(day)).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                        if cal.isDateInToday(day) { Text("Now").font(.caption.weight(.bold)).foregroundStyle(Jungle.warmText).padding(.horizontal, 8).padding(.vertical, 2).background(Jungle.peach.opacity(0.5), in: Capsule()) }
                    }
                    ForEach(grouped[day] ?? []) { item in
                        HStack(spacing: 12) {
                            Button { complete(item) } label: {
                                Image(systemName: "circle").font(.system(.title3, design: .rounded)).foregroundStyle(Jungle.leaf)
                            }
                            .buttonStyle(.plain).accessibilityLabel("Done")
                            if let p = item.plant { PlantAvatar(data: p.photo, size: 34) }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                                if let loc = item.plant?.location, !loc.isEmpty { Text(loc).font(.caption).foregroundStyle(Jungle.subtle) }
                            }
                            Spacer()
                            Icon3DView(Icon3D.care(item.kind), size: 28)
                        }
                        .padding(12).jungleCard()
                    }
                }
            }
        }
    }

    private func dayTitle(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return Grammar.pt(String(localized: "Today", comment: "Care agenda day header")) }
        if cal.isDateInTomorrow(d) { return Grammar.pt(String(localized: "Tomorrow", comment: "Care agenda day header")) }
        return d.formatted(.dateTime.weekday(.wide).day().month())
    }

    private func complete(_ item: AgendaItem) {
        withAnimation(.snappy) {
            item.task?.done = true
            if let p = item.plant, item.kind != .note {
                if item.kind == .soilCheck { return openSoil(p) }
                JungleBrain.quick(item.kind, plants: [p], in: ctx, announce: true)
            }
            try? ctx.save()
        }
    }
    private func openSoil(_ p: Plant) {
        // Soil checks need an answer: ask in the plant's thread.
        JungleBrain.reply(Grammar.pt(String(localized: "How does my soil feel?", comment: "Chat message from plant asking user about soil moisture")), plant: p, in: ctx, suggestions: [Grammar.pt(String(localized: "Dry", comment: "Soil moisture quick reply chip")), Grammar.pt(String(localized: "Slightly moist", comment: "Soil moisture quick reply chip")), Grammar.pt(String(localized: "Wet", comment: "Soil moisture quick reply chip"))])
        let m = ChatMessage(text: Grammar.pt(String(localized: "Feel my soil and tell me in my chat: dry, moist or wet?", comment: "Plant speaks in first person in chat; playful")), fromUser: false); m.speakerID = p.id
        ctx.insert(m)
        try? ctx.save()
    }
}

struct AddTaskView: View {
    static func defaultTitle(_ kind: CareKind, _ name: String?) -> String {
        let verb: String = switch kind {
        case .water: Grammar.pt(String(localized: "Water", comment: "Care task verb (imperative)"))
        case .feed: Grammar.pt(String(localized: "Feed", comment: "Care task verb (imperative): fertilize"))
        case .mist: Grammar.pt(String(localized: "Mist", comment: "Care task verb (imperative)"))
        case .rotate: Grammar.pt(String(localized: "Rotate", comment: "Care task verb (imperative): turn the pot"))
        case .clean: Grammar.pt(String(localized: "Clean leaves of", comment: "Care task verb (imperative), followed by plant name"))
        case .prune: Grammar.pt(String(localized: "Prune", comment: "Care task verb (imperative)"))
        case .repot: Grammar.pt(String(localized: "Repot", comment: "Care task verb (imperative)"))
        case .health: Grammar.pt(String(localized: "Health check", comment: "Care task title"))
        default: kind.label
        }
        guard let name else { return verb }
        return Grammar.pt(String(localized: "\(verb) \(name)", comment: "Care task title: verb then plant name, e.g. Water Monstera"))
    }

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let plants: [Plant]
    @State private var title = ""
    @State private var kind: CareKind = .water
    @State private var plantID: UUID?
    @State private var due = Date().addingTimeInterval(86_400)

    var body: some View {
        NavigationStack {
            Form {
                Picker("Plant", selection: $plantID) {
                    Text("None").tag(UUID?.none)
                    ForEach(plants) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("Type", selection: $kind) {
                    ForEach([CareKind.water, .feed, .mist, .rotate, .clean, .prune, .repot, .health, .note], id: \.self) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
                TextField("Note (optional)", text: $title)
                DatePicker("When", selection: $due)
            }
            .navigationTitle("Add care task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let name = plants.first { $0.id == plantID }?.name
                        let t = title.isEmpty ? Self.defaultTitle(kind, name) : title
                        ctx.insert(CareTask(title: t, kind: kind, plantID: plantID, due: due)); try? ctx.save(); dismiss()
                    }
                }
            }
        }
    }
}

/// Seasonal guide: generic + plant-specific to-dos for the current season (hemisphere aware).
struct SeasonGuideView: View {
    let plants: [Plant]
    @AppStorage("seasonChecks") private var checksRaw = ""

    enum Season: String, CaseIterable { case spring = "Spring", summer = "Summer", autumn = "Autumn", winter = "Winter"
        var label: String {
            switch self {
            case .spring: Grammar.pt(String(localized: "Spring", comment: "Season name"))
            case .summer: Grammar.pt(String(localized: "Summer", comment: "Season name"))
            case .autumn: Grammar.pt(String(localized: "Autumn", comment: "Season name (fall)"))
            case .winter: Grammar.pt(String(localized: "Winter", comment: "Season name"))
            }
        }
        var symbol: String { switch self { case .spring: "camera.macro"; case .summer: "sun.max.fill"; case .autumn: "leaf.fill"; case .winter: "snowflake" } }
    }

    /// Climate-aware: hemisphere from where you live, tropics follow the rains, mild places skip winter.
    static func current(_ d: Date = Date()) -> Season {
        switch Climate.shared.phase(d) { case .spring: .spring; case .summer: .summer; case .autumn: .autumn; case .winter: .winter }
    }
    @State private var season: Season = SeasonGuideView.current()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Climate.shared.alerts(for: plants)) { a in
                HStack(alignment: .top, spacing: 12) {
                    Icon3DView(a.icon, size: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(a.title).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                        Text(a.detail).font(.subheadline).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
            }
            Picker(Grammar.pt(String(localized: "Season", comment: "Accessibility label for the season picker")), selection: $season) {
                ForEach(Season.allCases, id: \.self) { Text($0.label) }
            }
            .pickerStyle(.segmented)
            .padding(.top, 6)
            ErtyView(mood: season == .winter ? .sleep : season == .autumn ? .rain : season == .spring ? .soil : .mist, size: 88)
                .frame(maxWidth: .infinity)
            if let line = Climate.shared.shortSummary {
                Label(line, systemImage: "location.fill").font(.footnote).foregroundStyle(Jungle.subtle).labelStyle(.titleAndIcon).lineLimit(1).minimumScaleFactor(0.85)
            }
            Text(Grammar.pt(String(localized: "\(season.label) for your plants", comment: "Season guide title, e.g. Summer for your plants"))).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text).padding(.top, 4)
            let list = items
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element) { i, item in
                    Button { toggle(item) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: checked(item) ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(Jungle.leaf)
                            Text(item).font(.subheadline).foregroundStyle(checked(item) ? Jungle.subtle : Jungle.text).strikethrough(checked(item)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if i < list.count - 1 { Divider().padding(.leading, 48) }
                }
            }
            .jungleCard()
            NativeAdCard(slot: "season").padding(.top, 8)
        }
    }

    private var items: [String] {
        let names = { (f: (Species) -> Bool) in plants.filter { $0.species.map(f) ?? false }.map(\.name).formatted(.list(type: .and)) }
        var out: [String]
        switch season {
        case .spring:
            out = [Grammar.pt(String(localized: "Resume regular feeding", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Check every plant for new growth", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Repot the ones that are root-bound", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Increase watering gradually as days get longer", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Clean leaves and rotate toward the light", comment: "Seasonal plant care to-do; short imperative"))]
            let repot = plants.filter { p in p.species.map { CareEngine.days(from: p.lastRepotAt ?? p.acquiredAt) > $0.repotYears * 365 } ?? false }.map(\.name)
            if !repot.isEmpty { out.append(Grammar.pt(String(localized: "Root check: \(repot.formatted(.list(type: .and)))", comment: "Seasonal to-do; arg is list of plant names"))) }
        case .summer:
            out = [Grammar.pt(String(localized: "Water more often and check soil twice a week", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Move sun-sensitive plants back from hot windows", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Watch for spider mites in dry heat", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Plan holiday care (Travel care)", comment: "Seasonal plant care to-do; short imperative"))]
            let humid = names { $0.humidityMin >= 55 }
            if !humid.isEmpty { out.append(Grammar.pt(String(localized: "Extra humidity for \(humid)", comment: "Seasonal to-do; arg is list of plant names"))) }
        case .autumn:
            out = [Grammar.pt(String(localized: "Taper feeding, last feed of the year", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Bring outdoor plants in before nights drop below \(Climate.temp(10))", comment: "Seasonal to-do; arg is a temperature like 10°C")), Grammar.pt(String(localized: "Inspect for pests before moving plants inside", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Water less as growth slows", comment: "Seasonal plant care to-do; short imperative"))]
            let outdoor = plants.filter(\.isOutdoor).map(\.name)
            if !outdoor.isEmpty { out.append(Grammar.pt(String(localized: "Plan where \(outdoor.formatted(.list(type: .and))) will overwinter", comment: "Seasonal to-do; arg is list of outdoor plant names"))) }
        case .winter:
            out = [Grammar.pt(String(localized: "Pause feeding until spring", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Water less: soil dries slower", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Keep plants away from radiators and cold glass", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Wipe dust off leaves to catch more light", comment: "Seasonal plant care to-do; short imperative")), Grammar.pt(String(localized: "Don't repot unless roots are rotting", comment: "Seasonal plant care to-do; short imperative"))]
            let cold = names { $0.tempMin >= 16 }
            if !cold.isEmpty { out.append(Grammar.pt(String(localized: "Keep \(cold) above \(Climate.temp(16))", comment: "Seasonal to-do; args: plant names list, temperature"))) }
        }
        return out
    }

    private var key: String { "\(season.rawValue)-\(Calendar.current.component(.year, from: Date()))" }
    private func checked(_ i: String) -> Bool { checksRaw.components(separatedBy: "\n").contains("\(key)|\(i)") }
    private func toggle(_ i: String) {
        var set = Set(checksRaw.components(separatedBy: "\n").filter { !$0.isEmpty })
        let k = "\(key)|\(i)"
        if set.contains(k) { set.remove(k) } else { set.insert(k) }
        checksRaw = set.joined(separator: "\n")
    }
}

/// Travel care: how long each plant copes, prep tasks, and a plant-sitter note to share.
struct TravelPlanView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    @State private var leave = Date().addingTimeInterval(3 * 86_400)
    @State private var back = Date().addingTimeInterval(13 * 86_400)
    @State private var saved = false

    private var days: Int { max(1, Int(back.timeIntervalSince(leave) / 86_400)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                JungleGroup(title: Grammar.pt(String(localized: "Dates", comment: "Travel plan section title"))) {
                    JungleRow(icon: .calendar, title: Grammar.pt(String(localized: "Leaving", comment: "Travel plan: departure date row"))) { DatePicker("", selection: $leave, in: Date()..., displayedComponents: .date).labelsHidden() }
                    JungleDivider()
                    JungleRow(icon: .calendarCheck, title: Grammar.pt(String(localized: "Back", comment: "Travel plan: return date row"))) { DatePicker("", selection: $back, in: leave..., displayedComponents: .date).labelsHidden() }
                }
                HStack(spacing: 14) {
                    Icon3DView(.travel, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Grammar.pt(String(localized: "\(days) days away", comment: "Travel plan: trip length"))).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                        Text(atRisk == 0 ? Grammar.pt(String(localized: "Everyone copes with a deep water before you go.", comment: "Travel plan: all plants fine")) : Grammar.pt(String(localized: "\(atRisk) plants need a sitter or self-watering.", comment: "Travel plan: number of plants at risk; plural")))
                            .font(.subheadline).foregroundStyle(atRisk == 0 ? Jungle.accentText : Jungle.warmText)
                    }
                }
                JungleGroup(title: Grammar.pt(String(localized: "Your plants", comment: "Travel plan section title"))) {
                    ForEach(plants) { p in
                        let copes = Int(CareEngine.expectedDryDays(for: p) * 1.3)
                        HStack(spacing: 12) {
                            PlantAvatar(data: p.photo, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).foregroundStyle(Jungle.text)
                                Text(copes >= days ? Grammar.pt(String(localized: "Fine for \(copes) days after a deep water", comment: "Travel plan per plant; plural")) : Grammar.pt(String(localized: "Copes about \(copes) days. Needs a sitter or a wick", comment: "Travel plan per plant at risk; plural")))
                                    .font(.caption).foregroundStyle(copes >= days ? Jungle.accentText : Jungle.warmText)
                            }
                            Spacer()
                            Icon3DView(copes >= days ? .shieldCheck : .waterDrops, size: 24)
                        }
                        .padding(.vertical, 10)
                        if p.id != plants.last?.id { Divider().padding(.leading, 48) }
                    }
                }
                JungleGroup(title: Grammar.pt(String(localized: "Before you go", comment: "Travel plan prep section title"))) {
                    ForEach(Array(prep.enumerated()), id: \.offset) { i, item in
                        JungleRow(icon: item.0, title: item.1)
                        if i < prep.count - 1 { JungleDivider() }
                    }
                }
                VStack(spacing: 10) {
                    Button {
                        let dayBefore = leave.addingTimeInterval(-86_400)
                        for p in plants { ctx.insert(CareTask(title: Grammar.pt(String(localized: "Deep water \(p.name) before the trip", comment: "Care task title; arg is plant name")), kind: .water, plantID: p.id, due: dayBefore)) }
                        CarePrefs.trip = (leave, back)
                        try? ctx.save(); saved = true
                    } label: { Text(saved ? Grammar.pt(String(localized: "We'll remind you before you go", comment: "Travel plan button after saving")) : Grammar.pt(String(localized: "Remind me to get everyone ready", comment: "Travel plan primary button"))).font(.headline).frame(maxWidth: .infinity).frame(height: 48) }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Jungle.forest).disabled(saved)
                    ShareLink(item: sitterNote, subject: Text("Plant care while I'm away", comment: "Share subject for plant-sitter note"), message: Text("Thank you for looking after my plants", comment: "Share message for plant-sitter note")) {
                        Text("Send plant-sitter instructions").font(.headline).frame(maxWidth: .infinity).frame(height: 48)
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule).tint(Jungle.forest)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .jungleBackdrop()
        .navigationTitle("Going away")
    }

    private var atRisk: Int { plants.filter { Int(CareEngine.expectedDryDays(for: $0) * 1.3) < days }.count }
    private let prep: [(Icon3D, String)] = [
        (.waterDrops, Grammar.pt(String(localized: "Water everyone deeply the day before", comment: "Travel prep item"))),
        (.hot, Grammar.pt(String(localized: "Move plants back from hot windows", comment: "Travel prep item"))),
        (.humidity, Grammar.pt(String(localized: "Group humidity lovers together", comment: "Travel prep item"))),
        (.waterTray, Grammar.pt(String(localized: "Wick or self-watering spike for thirsty plants", comment: "Travel prep item"))),
        (.fertilizer, Grammar.pt(String(localized: "Skip fertilizer the week before", comment: "Travel prep item"))),
    ]

    private var sitterNote: String {
        let from = leave.formatted(date: .abbreviated, time: .omitted), to = back.formatted(date: .abbreviated, time: .omitted)
        var lines = [Grammar.pt(String(localized: "My Tiny Jungle: plant care from \(from) to \(to)", comment: "Plant-sitter note heading; args are dates. Keep brand in English"))]
        lines.append("")
        for p in plants {
            let every = Int(CareEngine.expectedDryDays(for: p).rounded())
            let rule = p.species?.waterRule ?? Grammar.pt(String(localized: "Water when the soil is dry.", comment: "Plant-sitter note default watering rule"))
            let label = p.location.isEmpty ? p.name : Grammar.pt(String(localized: "\(p.name), \(p.location)", comment: "Plant-sitter note: plant name, room"))
            lines.append("• " + Grammar.pt(String(localized: "\(label): \(rule) Roughly every \(every) days. Feel the soil first.", comment: "Plant-sitter note line; args: plant, watering rule sentence, day count")))
        }
        lines.append("")
        lines.append(Grammar.pt(String(localized: "If a plant looks droopy and the soil is dry, give it a slow, deep drink. Thank you!", comment: "Plant-sitter note closing")))
        return lines.joined(separator: "\n")
    }
}

/// Propagation tracker with stages; finishing creates the new plant (lineage kept).
struct PropagationListView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Propagation.startedAt, order: .reverse) private var props: [Propagation]
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    @State private var starting = false

    var body: some View {
        List {
            if props.isEmpty {
                Text("Take a cutting from one of your plants and track it here, from water to new plant.", comment: "Propagation empty state").foregroundStyle(Jungle.subtle)
            }
            ForEach(props) { pr in
                let parent = plants.first { $0.id == pr.parentID }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        PlantAvatar(data: parent?.photo, size: 36)
                        VStack(alignment: .leading) {
                            Text(parent.map { Grammar.pt(String(localized: "\($0.name) cutting", comment: "Propagation row title; arg is parent plant name")) } ?? Grammar.pt(String(localized: "Cutting", comment: "Propagation row title when parent plant is gone"))).font(.system(.headline, design: .rounded))
                            Text(Grammar.pt(String(localized: "\(Propagation.methodLabel(pr.method)) · day \(Int(CareEngine.days(from: pr.startedAt)) + 1)", comment: "Propagation row subtitle: method and day number"))).font(.caption).foregroundStyle(Jungle.subtle)
                        }
                    }
                    ForEach(Propagation.Stage.allCases.filter { $0 != .done }, id: \.self) { st in
                        HStack(spacing: 10) {
                            Image(systemName: pr.stage.rawValue > st.rawValue ? "checkmark.circle.fill" : pr.stage == st ? "circle.inset.filled" : "circle")
                                .foregroundStyle(Jungle.leaf)
                            Text(st.label)
                            Spacer()
                            Text(hint(st, pr)).font(.caption).foregroundStyle(Jungle.subtle)
                        }
                    }
                    if pr.stage != .done {
                        Button(pr.stage == .growing ? Grammar.pt(String(localized: "It's a plant now! Add to jungle", comment: "Propagation button on final stage")) : (Propagation.Stage(rawValue: pr.stage.rawValue + 1)?.label).map { Grammar.pt(String(localized: "Next: \($0)", comment: "Propagation advance button; arg is next stage name")) } ?? "") { advance(pr, parent: parent) }
                            .buttonStyle(.borderedProminent).fontDesign(.rounded).buttonBorderShape(.capsule).controlSize(.small)
                    } else {
                        Label("Joined your jungle", systemImage: "leaf.fill").foregroundStyle(Jungle.accentText)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { idx in idx.forEach { ctx.delete(props[$0]) }; try? ctx.save() }
        }
        .safeAreaInset(edge: .bottom) { BottomBannerAd() }
        .navigationTitle("Propagation")
        .toolbar { Button { starting = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $starting) { NavigationStack { StartPropagationView(parent: nil) } }
    }

    private func hint(_ st: Propagation.Stage, _ pr: Propagation) -> String {
        switch st {
        case .cutting: pr.startedAt.formatted(.dateTime.day().month())
        case .rooting: pr.method == "Water" ? Grammar.pt(String(localized: "7–21 days", comment: "Propagation rooting time hint")) : Grammar.pt(String(localized: "2–4 weeks", comment: "Propagation rooting time hint"))
        case .potting: Grammar.pt(String(localized: "Roots 2–5 cm", comment: "Propagation potting hint: root length"))
        case .growing: Grammar.pt(String(localized: "First new leaf", comment: "Propagation growing stage hint"))
        case .done: ""
        }
    }

    private func advance(_ pr: Propagation, parent: Plant?) {
        guard let next = Propagation.Stage(rawValue: pr.stage.rawValue + 1) else { return }
        if next == .done, let parent {
            let child = Plant(name: Grammar.pt(String(localized: "\(parent.name) Jr.", comment: "Default name for plant grown from a cutting; arg parent name")), speciesID: parent.speciesID, personality: parent.personality, location: parent.location)
            child.photo = parent.photo
            ctx.insert(child)
            pr.childID = child.id
            ctx.insert(ChatMessage(text: Grammar.pt(String(localized: "Hi! I'm \(child.name), grown from a cutting of \(parent.name).", comment: "First chat message from new plant, first person; playful")), fromUser: false, plant: child))
        }
        pr.stage = next
        try? ctx.save()
    }
}

struct StartPropagationView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    var parent: Plant?
    @State private var parentID: UUID?
    @State private var method = "Water"

    var body: some View {
        Form {
            Picker("From", selection: $parentID) {
                Text("Choose").tag(UUID?.none)
                ForEach(plants) { Text($0.name).tag(Optional($0.id)) }
            }
            Picker("Method", selection: $method) {
                ForEach(["Water", "Soil", "Sphagnum moss", "Division", "Leaf"], id: \.self) { Text(Propagation.methodLabel($0)) }
            }
            Section("How") {
                Text("Cut just below a node (the bump where a leaf meets the stem), with 1–2 leaves. Keep it warm, in bright indirect light. Change the water weekly.").font(.subheadline)
            }
        }
        .navigationTitle("New cutting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Start") {
                    guard let id = parentID, let p = plants.first(where: { $0.id == id }) else { return }
                    ctx.insert(Propagation(parentID: id, method: method))
                    let e = CareEvent(kind: .propagate, note: method, source: "propagation"); e.plant = p; ctx.insert(e)
                    try? ctx.save(); dismiss()
                }
                .disabled(parentID == nil)
            }
        }
        .onAppear { parentID = parent?.id }
    }
}


/// Apple Calendar/Fitness style week strip: swipe between weeks, tap a day to see only its care.
struct WeekStrip: View {
    let plants: [Plant]
    let tasks: [CareTask]
    @Binding var selected: Date?
    @Binding var offset: Int
    private let cal = Calendar.current

    var body: some View {
        TabView(selection: $offset) {
            ForEach(-8...12, id: \.self) { w in week(w).tag(w).padding(.horizontal, 2) }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 76)
        .padding(.vertical, 6)
        .jungleCard()
    }

    private func days(_ w: Int) -> [Date] {
        let base = cal.date(byAdding: .weekOfYear, value: w, to: Date())!
        let start = cal.dateInterval(of: .weekOfYear, for: base)!.start
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: start)! }
    }

    private func week(_ w: Int) -> some View {
        let planned = Agenda.items(plants: plants, tasks: tasks, days: 7 * (max(w, 0) + 1) + 1)
        return HStack(spacing: 0) {
            ForEach(days(w), id: \.self) { d in
                let isSel = selected.map { cal.isDate($0, inSameDayAs: d) } ?? false
                let isToday = cal.isDateInToday(d)
                let count = planned.filter { cal.isDate($0.date, inSameDayAs: d) }.count
                let done = plants.flatMap { $0.events ?? [] }.filter { cal.isDate($0.date, inSameDayAs: d) && $0.kind != .photo && $0.kind != .note }.count
                Button {
                    withAnimation(.snappy) { selected = isSel ? nil : d }
                } label: {
                    VStack(spacing: 5) {
                        Text(d.formatted(.dateTime.weekday(.narrow))).font(.caption2.weight(.semibold))
                            .foregroundStyle(isToday ? Jungle.warmText : Jungle.subtle)
                        Text(d.formatted(.dateTime.day()))
                            .font(.system(.body, design: .rounded, weight: isSel || isToday ? .bold : .regular))
                            .foregroundStyle(isSel ? Color.white : Jungle.text)
                            .frame(width: 36, height: 36)
                            .background { if isSel { Circle().fill(Jungle.forest) } else if isToday { Circle().strokeBorder(Jungle.forest, lineWidth: 1.5) } }
                        HStack(spacing: 3) {
                            if done > 0 { Circle().fill(Jungle.leaf).frame(width: 5, height: 5) }
                            if count > 0 && d >= cal.startOfDay(for: Date()) { Circle().strokeBorder(Jungle.terracotta, lineWidth: 1.2).frame(width: 5, height: 5) }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Grammar.pt(String(localized: "\(d.formatted(date: .complete, time: .omitted)), \(count) planned, \(done) done", comment: "Accessibility for week strip day: date, planned tasks, done tasks")))
                .accessibilityAddTraits(isSel ? .isSelected : [])
            }
        }
    }
}

extension Propagation {
    /// Display name for the stored (English id) propagation method.
    static func methodLabel(_ m: String) -> String {
        switch m {
        case "Water": Grammar.pt(String(localized: "propagation.method.water", defaultValue: "Water", comment: "Propagation method: rooting in water"))
        case "Soil": Grammar.pt(String(localized: "Soil", comment: "Propagation method"))
        case "Sphagnum moss": Grammar.pt(String(localized: "Sphagnum moss", comment: "Propagation method"))
        case "Division": Grammar.pt(String(localized: "Division", comment: "Propagation method: splitting the plant"))
        case "Leaf": Grammar.pt(String(localized: "Leaf", comment: "Propagation method: leaf cutting"))
        default: m
        }
    }
}

/// The month at a glance, for a page with room beside the agenda (Duo, iPad).
private struct CareStatsCard: View {
    let plants: [Plant]
    let tasks: [CareTask]
    @Query(sort: \CareEvent.date, order: .reverse) private var events: [CareEvent]

    var body: some View {
        let cal = Calendar.current
        let monthStart = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        let done = events.filter { $0.plant != nil && $0.note != "safety-ack" && $0.date >= monthStart }
        let week = Agenda.items(plants: plants, tasks: tasks, days: 7).count
        let needs = plants.filter { CareEngine.needsYou($0) }.count
        let thriving = plants.filter { CareEngine.mood(for: $0) == .thriving }.count
        let activeDays = Set(done.map { cal.startOfDay(for: $0.date) }).count
        VStack(alignment: .leading, spacing: 12) {
            Text(Grammar.pt(String(localized: "This month", comment: "Care stats card title"))).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    stat("\(done.count)", Grammar.pt(String(localized: "care moments", comment: "Care stat label")), Jungle.leaf)
                    stat("\(activeDays)", Grammar.pt(String(localized: "days you showed up", comment: "Care stat label: days with care this month")), Jungle.forest)
                }
                GridRow {
                    stat("\(week)", Grammar.pt(String(localized: "due this week", comment: "Care stat label")), Jungle.accentText)
                    stat(needs == 0 ? "\(thriving)" : "\(needs)", needs == 0 ? Grammar.pt(String(localized: "thriving", comment: "Care stat label")) : Grammar.pt(String(localized: "need you today", comment: "Care stat label")), needs == 0 ? Jungle.leaf : Jungle.terracotta)
                }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
    }

    private func stat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(tint).contentTransition(.numericText())
            Text(label).font(.footnote).foregroundStyle(Jungle.subtle).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Jungle.mint.opacity(0.45), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
