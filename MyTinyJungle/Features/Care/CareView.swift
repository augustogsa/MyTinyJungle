import SwiftUI
import SwiftData

/// Care: this week / month agenda from the engine, seasonal guide, travel plan, propagation.
struct CareView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.createdAt) private var plants: [Plant]
    @Query private var tasks: [CareTask]
    enum Range: String, CaseIterable { case week = "This week", month = "Month", season = "Season" }
    @State private var range: Range = .week
    @State private var adding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Range", selection: $range) { ForEach(Range.allCases, id: \.self) { Text($0.rawValue) } }.pickerStyle(.segmented)
                    HStack(spacing: 10) {
                        NavigationLink { TravelPlanView() } label: { shortcut("Travel care", "airplane") }
                        NavigationLink { PropagationListView() } label: { shortcut("Propagate", "scissors") }
                        NavigationLink { SpacesView() } label: { shortcut("Spaces", "house") }
                    }
                    .buttonStyle(.plain)
                    if range == .season { SeasonGuideView(plants: plants) } else { agenda }
                }
                .padding(16)
            }
            .background(Jungle.cream)
            .navigationTitle("Care")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add care task") }
            .sheet(isPresented: $adding) { AddTaskView(plants: plants) }
            .animation(.snappy, value: range)
        }
    }

    private func shortcut(_ t: String, _ s: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: s).font(.title3).foregroundStyle(Jungle.leaf)
            Text(t).font(.caption.weight(.medium)).foregroundStyle(Jungle.text)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).jungleCard()
    }

    private var agenda: some View {
        let items = Agenda.items(plants: plants, tasks: tasks, days: range == .week ? 7 : 30)
        let cal = Calendar.current
        let grouped = Dictionary(grouping: items) { cal.startOfDay(for: $0.date) }
        return VStack(alignment: .leading, spacing: 14) {
            if items.isEmpty {
                Text(plants.isEmpty ? "Add a plant and its care shows up here." : "Nothing planned. Your jungle is relaxing. 🌿").foregroundStyle(Jungle.subtle)
            }
            ForEach(grouped.keys.sorted(), id: \.self) { day in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(dayTitle(day)).font(.headline).foregroundStyle(Jungle.text)
                        if cal.isDateInToday(day) { Text("Now").font(.caption.weight(.bold)).foregroundStyle(Jungle.warmText).padding(.horizontal, 8).padding(.vertical, 2).background(Jungle.peach.opacity(0.5), in: Capsule()) }
                    }
                    ForEach(grouped[day] ?? []) { item in
                        HStack(spacing: 12) {
                            Button { complete(item) } label: {
                                Image(systemName: "circle").font(.title3).foregroundStyle(Jungle.leaf)
                            }
                            .buttonStyle(.plain).accessibilityLabel("Done")
                            if let p = item.plant { PlantAvatar(data: p.photo, size: 34) }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title).foregroundStyle(Jungle.text)
                                if let loc = item.plant?.location, !loc.isEmpty { Text(loc).font(.caption).foregroundStyle(Jungle.subtle) }
                            }
                            Spacer()
                            Image(systemName: item.kind.symbol).foregroundStyle(Jungle.sage)
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
            if let p = item.plant, item.kind != .note, item.kind != .health {
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

    static func current(_ d: Date = Date()) -> Season {
        var m = Calendar.current.component(.month, from: d)
        if JungleSettings.shared.southernHemisphere { m = (m + 5) % 12 + 1 }
        switch m { case 3...5: return .spring; case 6...8: return .summer; case 9...10: return .autumn; default: return .winter }
    }
    @State private var season: Season = SeasonGuideView.current()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(Season.allCases, id: \.self) { s in
                    Button { season = s } label: {
                        VStack(spacing: 4) { Image(systemName: s.symbol); Text(s.rawValue).font(.caption) }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .foregroundStyle(season == s ? Color.white : Jungle.text)
                            .background(season == s ? Jungle.leaf : Jungle.mist, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("\(season.rawValue) for your plants").font(.title3.weight(.bold)).foregroundStyle(Jungle.text)
            ForEach(items, id: \.self) { item in
                Button { toggle(item) } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: checked(item) ? "checkmark.circle.fill" : "circle").foregroundStyle(Jungle.leaf)
                        Text(item).foregroundStyle(Jungle.text).strikethrough(checked(item)).multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
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
            out = ["Taper feeding, last feed of the year", "Bring outdoor plants in before nights drop below 10 °C", "Inspect for pests before moving plants inside", "Water less as growth slows"]
            let outdoor = plants.filter(\.isOutdoor).map(\.name)
            if !outdoor.isEmpty { out.append("Plan where \(outdoor.joined(separator: ", ")) will overwinter") }
        case .winter:
            out = ["Pause feeding until spring", "Water less: soil dries slower", "Keep plants away from radiators and cold glass", "Wipe dust off leaves to catch more light", "Don't repot unless roots are rotting"]
            let cold = names { $0.tempMin >= 16 }
            if !cold.isEmpty { out.append("Keep \(cold) above 16 °C") }
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
        List {
            Section {
                DatePicker("Leaving", selection: $leave, in: Date()..., displayedComponents: .date)
                DatePicker("Back", selection: $back, in: leave..., displayedComponents: .date)
                LabeledContent("Away", value: "\(days) days")
            }
            Section("Your plants") {
                ForEach(plants) { p in
                    let copes = Int(CareEngine.expectedDryDays(for: p) * 1.3)
                    HStack(spacing: 12) {
                        PlantAvatar(data: p.photo, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name)
                            Text(copes >= days ? "Fine for \(copes) days after a deep water" : "Needs a sitter or self-watering: copes ~\(copes) days")
                                .font(.caption).foregroundStyle(copes >= days ? Jungle.accentText : Jungle.warmText)
                        }
                    }
                }
            }
            Section("Before you go") {
                ForEach(["Water everyone deeply the day before", "Move plants a little back from hot windows", "Group humidity lovers together", "Use a water-wick or self-watering spike for thirsty plants", "Skip fertilizer the week before"], id: \.self) { Label($0, systemImage: "checkmark.circle") }
            }
            Section {
                Button(saved ? "Prep tasks added ✓" : "Add prep tasks to Care", systemImage: "calendar.badge.plus") {
                    let dayBefore = leave.addingTimeInterval(-86_400)
                    for p in plants { ctx.insert(CareTask(title: "Deep water \(p.name) before the trip", kind: .water, plantID: p.id, due: dayBefore)) }
                    try? ctx.save(); saved = true
                }
                .disabled(saved)
                ShareLink(item: sitterNote, subject: Text("Plant care while I'm away"), message: Text("Thank you for looking after my plants 🌿")) {
                    Label("Send plant-sitter instructions", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("Travel care")
    }

    private var sitterNote: String {
        var t = "🌿 My Tiny Jungle: plant care from \(leave.formatted(date: .abbreviated, time: .omitted)) to \(back.formatted(date: .abbreviated, time: .omitted))\n\n"
        for p in plants {
            let every = Int(CareEngine.expectedDryDays(for: p).rounded())
            t += "• \(p.name)\(p.species.map { " (\($0.en))" } ?? "")\(p.location.isEmpty ? "" : ", \(p.location)"): "
            t += p.species?.waterRule ?? "Water when the soil is dry."
            t += " Roughly every \(every) days. Feel the soil first.\n"
        }
        t += "\nIf a plant looks droopy and the soil is dry, give it a slow, deep drink. Thank you! 💚"
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
                            Text("\(parent?.name ?? "Cutting") cutting").font(.headline)
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
                            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.small)
                    } else {
                        Label("Joined your jungle", systemImage: "leaf.fill").foregroundStyle(Jungle.accentText)
                    }
                }
                .padding(.vertical, 4)
            }
            .onDelete { idx in idx.forEach { ctx.delete(props[$0]) }; try? ctx.save() }
        }
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
            ctx.insert(ChatMessage(text: "Hi! I'm \(child.name), grown from a cutting of \(parent.name). 🌱", fromUser: false, plant: child))
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
