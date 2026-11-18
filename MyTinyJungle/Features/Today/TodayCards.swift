import SwiftUI

/// Mon–Sun strip. Dots mark days with care: filled = done, hollow = planned.
struct TodayWeekStrip: View {
    let plants: [Plant]
    var onTap: (Date) -> Void = { _ in }

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        let planned = Agenda.items(plants: plants, tasks: [], days: 7)
        let events = plants.flatMap { $0.events ?? [] }.filter { $0.kind != .note }
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { d in
                let isToday = cal.isDate(d, inSameDayAs: today)
                let done = events.contains { cal.isDate($0.date, inSameDayAs: d) }
                let due = planned.contains { cal.isDate($0.date, inSameDayAs: d) } || (isToday && planned.contains { $0.date < today })
                Button { onTap(d) } label: {
                    VStack(spacing: 6) {
                        Text(d.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.footnote.weight(isToday ? .semibold : .regular))
                        Text(d.formatted(.dateTime.day()))
                            .font(.system(.body, design: .rounded, weight: .semibold)).monospacedDigit()
                        Circle()
                            .fill(done ? Jungle.leaf : .clear)
                            .strokeBorder(due && !done ? Jungle.leaf : .clear, lineWidth: 1.5)
                            .frame(width: 6, height: 6)
                    }
                    .foregroundStyle(isToday ? Jungle.forest : Jungle.subtle)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background { if isToday { Capsule().fill(Jungle.surface).shadow(color: .black.opacity(0.06), radius: 8, y: 2) } }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(d.formatted(.dateTime.weekday(.wide).day())), \(done ? "care done" : due ? "care planned" : "nothing planned")")
            }
        }
    }
}

/// Photo-led care card: the plant fills the card, the task floats on glass.
struct CareStoryCard: View {
    let plant: Plant
    let request: PlantRequest
    var onAction: (RequestCard.Action) -> Void
    var onOpen: () -> Void
    var fullWidth = false

    private var task: String {
        switch request.kind {
        case .water:
            if let a = CareEngine.waterAmount(for: plant) { return "Water · \(a.lo)–\(a.hi) ml" }
            return "Water"
        case .checkSoil: return "Check the soil"
        case .feed: return "Feed"
        case .checkRoots: return "Check the roots"
        case .portrait: return "Take a photo"
        case .safety: return "Keep away from pets"
        case .pauseFeeding: return "Rest from feeding"
        }
    }

    private var progress: Double {
        guard let last = plant.lastEvent(.water)?.date else { return 1 }
        return min(1, CareEngine.days(from: last) / max(1, CareEngine.expectedDryDays(for: plant)))
    }

    private var lastLine: String {
        guard let last = plant.lastEvent(.water)?.date else { return "Not watered yet" }
        return "Watered " + last.formatted(.relative(presentation: .named))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .overlay {
                    if let d = plant.photo, let img = UIImage(data: d) { Image(uiImage: img).resizable().scaledToFill() }
                    else { ZStack { Jungle.mint; Icon3DView(.pottedPlant, size: 96) } }
                }
                .clipped()
                .onTapGesture(perform: onOpen)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plant.name).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                        if !plant.location.isEmpty {
                            Text(plant.location).font(.caption).foregroundStyle(Jungle.subtle)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Jungle.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    Spacer()
                    Button(action: onOpen) {
                        Image(systemName: "arrow.up.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Jungle.text)
                            .frame(width: 36, height: 36)
                            .background(Jungle.surface.opacity(0.92), in: Circle())
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    }
                    .accessibilityLabel("Open \(plant.name)")
                }
                .padding(12)
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text).lineLimit(1)
                        Capsule().fill(Jungle.mint).frame(height: 5)
                            .overlay(alignment: .leading) {
                                GeometryReader { g in Capsule().fill(Jungle.leaf).frame(width: g.size.width * progress) }
                            }
                        Text(lastLine).font(.caption).foregroundStyle(Jungle.subtle).lineLimit(1)
                    }
                    action
                }
                .padding(12)
                .background(Jungle.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .padding(10)
            }
        }
        .frame(width: fullWidth ? nil : 272, height: fullWidth ? 300 : 340)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    @ViewBuilder private var action: some View {
        switch request.kind {
        case .checkSoil:
            Menu {
                ForEach(SoilState.allCases, id: \.self) { s in Button(s.label) { onAction(.soil(s)) } }
            } label: { check }
            .accessibilityLabel("How does the soil feel?")
        case .safety:
            Button { onAction(.ack) } label: { check }.accessibilityLabel("Got it")
        case .portrait, .checkRoots:
            Button(action: onOpen) { check }.accessibilityLabel(task)
        default:
            Button { onAction(.care(request.kind == .feed ? .feed : .water)) } label: { check }.accessibilityLabel("Mark done")
        }
    }

    private var check: some View {
        Image(systemName: "checkmark").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            .frame(width: 48, height: 48).background(Jungle.forest, in: Circle())
    }
}

/// Ring card: how the whole jungle is doing today.
struct JungleHealthCard: View {
    let plants: [Plant]
    var needIDs: Set<UUID> = []
    var body: some View {
        let rest = plants.filter { !needIDs.contains($0.id) }
        let needs = plants.count - rest.count
        let thriving = rest.filter { CareEngine.mood(for: $0) == .thriving }.count
        let fine = rest.count - thriving
        let score = (Double(thriving) + Double(fine) * 0.7) / Double(max(1, plants.count))
        let caredToday = plants.flatMap { $0.events ?? [] }.filter { Calendar.current.isDateInToday($0.date) && $0.kind != .note }.count
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(Jungle.mint, lineWidth: 12)
                Circle().trim(from: 0, to: score)
                    .stroke(Jungle.leaf, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int((score * 100).rounded()))%").font(.system(.title2, design: .rounded, weight: .bold)).monospacedDigit().foregroundStyle(Jungle.text)
                    Text("healthy").font(.caption2).foregroundStyle(Jungle.subtle)
                }
            }
            .frame(width: 104, height: 104)
            VStack(alignment: .leading, spacing: 10) {
                Text(needs == 0 ? (fine == 0 ? "Your jungle is thriving" : "Your jungle is doing well") : "\(needs) \(needs == 1 ? "plant would" : "plants would") love some attention")
                    .font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    stat(thriving, "Thriving", Jungle.leaf)
                    stat(fine, "Okay", Jungle.sun)
                    stat(needs, "Need you", Jungle.terracotta)
                }
                if caredToday > 0 {
                    Text("\(caredToday) care moment\(caredToday == 1 ? "" : "s") today").font(.caption).foregroundStyle(Jungle.accentText)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .jungleCard()
        .accessibilityElement(children: .combine)
    }

    private func stat(_ n: Int, _ label: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(n)").font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit().foregroundStyle(Jungle.text)
            HStack(spacing: 4) { Circle().fill(c).frame(width: 6, height: 6); Text(label).font(.caption2).foregroundStyle(Jungle.subtle) }
        }
    }
}
