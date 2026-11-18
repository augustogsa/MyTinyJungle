import SwiftUI
import SwiftData

/// Care: this week / month agenda from the engine, seasonal guide, travel plan, propagation.
struct CareView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.createdAt) private var plants: [Plant]
    @Query private var tasks: [CareTask]
    enum Range: String, CaseIterable { case week = "Week", month = "Month", calendar = "Calendar", season = "Season" }
    @State private var range: Range = .week
    @State private var adding = false
    /// Day picked in the week strip; nil shows every day.
    @State private var selectedDay: Date?
    @State private var weekOffset = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TabHeader(title: "Care", subtitle: stripMonth) {
                        HeaderButton(symbol: "plus", label: "Add care task") { adding = true }
                    }
                    WeekStrip(plants: plants, tasks: tasks, selected: $selectedDay, offset: $weekOffset)
                    Picker("Range", selection: $range) { ForEach(Range.allCases, id: \.self) { Text($0.rawValue) } }.pickerStyle(.segmented)
                    HStack(spacing: 10) {
                        NavigationLink { TravelPlanView() } label: { shortcut("Travel care", "airplane") }
                        NavigationLink { PropagationListView() } label: { shortcut("Propagate", "scissors") }
                        NavigationLink { GuidesView() } label: { shortcut("How-to", "book.fill") }
                    }
                    .buttonStyle(.plain)
                    switch range {
                    case .season: SeasonGuideView(plants: plants)
                    case .calendar: CareCalendarView(plants: plants, tasks: tasks)
                    default: agenda
                    }
                }
                .padding(16)
            }
            .jungleBackdrop()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $adding) { AddTaskView(plants: plants) }
            .animation(.snappy, value: range)
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
                Text(plants.isEmpty ? "Add a plant and its care shows up here." : selectedDay != nil ? "Nothing planned this day." : "Nothing planned. Your jungle is relaxing.").foregroundStyle(Jungle.subtle)
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
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInTomorrow(d) { return "Tomorrow" }
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
        JungleBrain.reply("How does my soil feel?", plant: p, in: ctx, suggestions: ["Dry", "Slightly moist", "Wet"])
        let m = ChatMessage(text: "Feel my soil and tell me in my chat: dry, moist or wet?", fromUser: false); m.speakerID = p.id
        ctx.insert(m)
        try? ctx.save()
    }
}

struct AddTaskView: View {
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
                        let t = title.isEmpty ? "\(kind.label.replacingOccurrences(of: "ed", with: ""))\(name.map { " \($0)" } ?? "")" : title
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
            if Climate.shared.profile != nil {
                Text(Climate.shared.summary).font(.footnote).foregroundStyle(Jungle.subtle)
            }
            HStack(spacing: 8) {
                ForEach(Season.allCases, id: \.self) { s in
                    Button { season = s } label: {
                        VStack(spacing: 4) { Image(systemName: s.symbol).frame(height: 22); Text(s.rawValue).font(.caption) }
                            .frame(maxWidth: .infinity).frame(height: 64)
                            .foregroundStyle(season == s ? Color.white : Jungle.text)
                            .background(season == s ? Jungle.leaf : Jungle.mist, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("\(season.rawValue) for your plants").font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
            ForEach(items, id: \.self) { item in
                if item == items.dropFirst(3).first { NativeAdCard(slot: "agenda") }
                Button { toggle(item) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: checked(item) ? "checkmark.circle.fill" : "circle").foregroundStyle(Jungle.leaf)
                        Text(item).foregroundStyle(Jungle.text).strikethrough(checked(item)).multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            NativeAdCard(slot: "season").padding(.top, 8)
        }
    }

    private var items: [String] {
        let names = { (f: (Species) -> Bool) in plants.filter { $0.species.map(f) ?? false }.map(\.name).joined(separator: ", ") }
        var out: [String]
        switch season {
        case .spring:
            out = ["Resume regular feeding", "Check every plant for new growth", "Repot the ones that are root-bound", "Increase watering gradually as days get longer", "Clean leaves and rotate toward the light"]
            let repot = plants.filter { p in p.species.map { CareEngine.days(from: p.lastRepotAt ?? p.acquiredAt) > $0.repotYears * 365 } ?? false }.map(\.name)
            if !repot.isEmpty { out.append("Root check: \(repot.joined(separator: ", "))") }
        case .summer:
            out = ["Water more often and check soil twice a week", "Move sun-sensitive plants back from hot windows", "Watch for spider mites in dry heat", "Plan holiday care (Travel care)"]
            let humid = names { $0.humidityMin >= 55 }
            if !humid.isEmpty { out.append("Extra humidity for \(humid)") }
        case .autumn:
            out = ["Taper feeding, last feed of the year", "Bring outdoor plants in before nights drop below \(Climate.temp(10))", "Inspect for pests before moving plants inside", "Water less as growth slows"]
            let outdoor = plants.filter(\.isOutdoor).map(\.name)
            if !outdoor.isEmpty { out.append("Plan where \(outdoor.joined(separator: ", ")) will overwinter") }
        case .winter:
            out = ["Pause feeding until spring", "Water less: soil dries slower", "Keep plants away from radiators and cold glass", "Wipe dust off leaves to catch more light", "Don't repot unless roots are rotting"]
            let cold = names { $0.tempMin >= 16 }
            if !cold.isEmpty { out.append("Keep \(cold) above \(Climate.temp(16))") }
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
                JungleGroup(title: "Dates") {
                    JungleRow(icon: .calendar, title: "Leaving") { DatePicker("", selection: $leave, in: Date()..., displayedComponents: .date).labelsHidden() }
                    JungleDivider()
                    JungleRow(icon: .calendarCheck, title: "Back") { DatePicker("", selection: $back, in: leave..., displayedComponents: .date).labelsHidden() }
                }
                HStack(spacing: 14) {
                    Icon3DView(.travel, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(days) days away").font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                        Text(atRisk == 0 ? "Everyone copes with a deep water before you go." : "\(atRisk) plant\(atRisk == 1 ? "" : "s") \(atRisk == 1 ? "needs" : "need") a sitter or self-watering.")
                            .font(.subheadline).foregroundStyle(atRisk == 0 ? Jungle.accentText : Jungle.warmText)
                    }
                }
                JungleGroup(title: "Your plants") {
                    ForEach(plants) { p in
                        let copes = Int(CareEngine.expectedDryDays(for: p) * 1.3)
                        HStack(spacing: 12) {
                            PlantAvatar(data: p.photo, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).foregroundStyle(Jungle.text)
                                Text(copes >= days ? "Fine for \(copes) days after a deep water" : "Copes about \(copes) days. Needs a sitter or a wick")
                                    .font(.caption).foregroundStyle(copes >= days ? Jungle.accentText : Jungle.warmText)
                            }
                            Spacer()
                            Icon3DView(copes >= days ? .shieldCheck : .waterDrops, size: 24)
                        }
                        .padding(.vertical, 10)
                        if p.id != plants.last?.id { Divider().padding(.leading, 48) }
                    }
                }
                JungleGroup(title: "Before you go") {
                    ForEach(Array(prep.enumerated()), id: \.offset) { i, item in
                        JungleRow(icon: item.0, title: item.1)
                        if i < prep.count - 1 { JungleDivider() }
                    }
                }
                VStack(spacing: 10) {
                    Button {
                        let dayBefore = leave.addingTimeInterval(-86_400)
                        for p in plants { ctx.insert(CareTask(title: "Deep water \(p.name) before the trip", kind: .water, plantID: p.id, due: dayBefore)) }
                        CarePrefs.trip = (leave, back)
                        try? ctx.save(); saved = true
                    } label: { Text(saved ? "We'll remind you before you go" : "Remind me to get everyone ready").font(.headline).frame(maxWidth: .infinity).frame(height: 48) }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Jungle.forest).disabled(saved)
                    ShareLink(item: sitterNote, subject: Text("Plant care while I'm away"), message: Text("Thank you for looking after my plants")) {
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
        (.waterDrops, "Water everyone deeply the day before"),
        (.hot, "Move plants back from hot windows"),
        (.humidity, "Group humidity lovers together"),
        (.waterTray, "Wick or self-watering spike for thirsty plants"),
        (.fertilizer, "Skip fertilizer the week before"),
    ]

    private var sitterNote: String {
        var t = " My Tiny Jungle: plant care from \(leave.formatted(date: .abbreviated, time: .omitted)) to \(back.formatted(date: .abbreviated, time: .omitted))\n\n"
        for p in plants {
            let every = Int(CareEngine.expectedDryDays(for: p).rounded())
            t += "• \(p.name)\(p.species.map { " (\($0.en))" } ?? "")\(p.location.isEmpty ? "" : ", \(p.location)"): "
            t += p.species?.waterRule ?? "Water when the soil is dry."
            t += " Roughly every \(every) days. Feel the soil first.\n"
        }
        t += "\nIf a plant looks droopy and the soil is dry, give it a slow, deep drink. Thank you!"
        return t
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
                Text("Take a cutting from one of your plants and track it here, from water to new plant.").foregroundStyle(Jungle.subtle)
            }
            ForEach(props) { pr in
                let parent = plants.first { $0.id == pr.parentID }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        PlantAvatar(data: parent?.photo, size: 36)
                        VStack(alignment: .leading) {
                            Text("\(parent?.name ?? "Cutting") cutting").font(.system(.headline, design: .rounded))
                            Text("\(pr.method) · day \(Int(CareEngine.days(from: pr.startedAt)) + 1)").font(.caption).foregroundStyle(Jungle.subtle)
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
                        Button(pr.stage == .growing ? "It's a plant now! Add to jungle" : "Next: \(Propagation.Stage(rawValue: pr.stage.rawValue + 1)?.label ?? "")") { advance(pr, parent: parent) }
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
        case .rooting: pr.method == "Water" ? "7–21 days" : "2–4 weeks"
        case .potting: "Roots 2–5 cm"
        case .growing: "First new leaf"
        case .done: ""
        }
    }

    private func advance(_ pr: Propagation, parent: Plant?) {
        guard let next = Propagation.Stage(rawValue: pr.stage.rawValue + 1) else { return }
        if next == .done, let parent {
            let child = Plant(name: "\(parent.name) Jr.", speciesID: parent.speciesID, personality: parent.personality, location: parent.location)
            child.photo = parent.photo
            ctx.insert(child)
            pr.childID = child.id
            ctx.insert(ChatMessage(text: "Hi! I'm \(child.name), grown from a cutting of \(parent.name).", fromUser: false, plant: child))
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
                ForEach(["Water", "Soil", "Sphagnum moss", "Division", "Leaf"], id: \.self) { Text($0) }
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
                .accessibilityLabel("\(d.formatted(date: .complete, time: .omitted)), \(count) planned, \(done) done")
                .accessibilityAddTraits(isSel ? .isSelected : [])
            }
        }
    }
}
