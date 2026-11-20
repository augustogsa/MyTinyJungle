import SwiftUI
import SwiftData

/// Store screenshots: `-demoOpen doctor|identify|digest|passport|paywall` (demo jungle only) opens that screen
/// filled with sample results, no network. Text is English or Brazilian Portuguese (the two shot languages).
struct DemoShotSheet: ViewModifier {
    @Query(sort: \Plant.createdAt) private var plants: [Plant]
    @State private var open: String?
    @State private var board = false
    @State private var notes = false
    private static let kinds = ["doctor", "identify", "digest", "passport", "paywall", "widgets", "talk", "jungle", "season", "notes", "trip"]

    func body(content: Content) -> some View {
        content
            .task {
                guard let k = DemoSeeder.demoOpen, Self.kinds.contains(k) else { return }
                for _ in 0..<60 where plants.count < 8 { try? await Task.sleep(for: .seconds(0.5)) }
                try? await Task.sleep(for: .seconds(1.5))
                if k == "widgets" { board = true } else if k == "notes" { notes = true } else { open = k }
            }
            .fullScreenCover(isPresented: $board) { DemoWidgetBoard(snap: WidgetSnapshot.make(plants)) }
            .fullScreenCover(isPresented: $notes) { DemoNotifyBoard(plants: plants) }
            .sheet(item: Binding(get: { open.map(DemoKey.init) }, set: { open = $0?.id })) { k in
                switch k.id {
                case "talk": if let p = plants.first(where: { !($0.messages ?? []).isEmpty }) ?? plant("monstera-deliciosa") { NavigationStack { PlantChatView(plant: p) } }
                case "jungle": NavigationStack { JungleChatView() }
                case "season": NavigationStack { ScrollView { SeasonGuideView(plants: plants).padding(16) }.jungleBackdrop().navigationTitle("Seasons") }
                case "trip": NavigationStack { TravelPlanView() }
                case "doctor": if let p = plant("spathiphyllum") { HealthCheckView(plant: p, demo: DemoShots.diagnosis) }
                case "identify": ShelfImportView(onDone: {}, preset: DemoShots.shelf)
                case "digest": NavigationStack { DigestView(preset: DemoShots.digest(plants)) }
                case "passport": if let p = plant("monstera-deliciosa") { PassportSheet(plant: p, preset: DemoShots.passport, presetNotes: DemoShots.passportNotes) }
                default: PaywallView(reason: nil)
                }
            }
    }
    private func plant(_ species: String) -> Plant? { plants.first { $0.speciesID == species } ?? plants.first }
}

private struct DemoKey: Identifiable { let id: String }

@MainActor
enum DemoShots {
    static var pt: Bool { Locale.current.language.languageCode?.identifier == "pt" }
    static func t(_ en: String, _ br: String) -> String { pt ? br : en }

    static var diagnosis: AIDiagnosis {
        AIDiagnosis(
            problem: t("Overwatering", "Excesso de água"),
            confidence: "high",
            why: t("The yellow lower leaves and soft stems point to soggy roots. The soil stayed wet for 9 days after the last watering.",
                   "As folhas de baixo amarelando e os talos molinhos mostram raiz encharcada. A terra ficou molhada 9 dias depois da última rega."),
            steps: [
                t("Skip watering until the top 3 cm feel dry.", "Segura a rega até os 3 cm de cima secarem."),
                t("Empty the saucer so the roots can breathe.", "Esvazia o pratinho pra raiz respirar."),
                t("Snip the yellow leaves at the base.", "Corta as folhas amarelas rente à base."),
                t("Move her to bright, indirect light.", "Deixa ela num lugar claro, sem sol direto."),
            ],
            urgent: true, source: nil,
            context: t("Rainy week ahead: the bathroom stays humid, so she'll dry slower than usual.",
                       "Semana de chuva pela frente: o banheiro fica úmido e ela vai secar mais devagar."),
            ref: "demo", weather: nil)
    }

    static var shelf: [ShelfImportView.Row] {
        guard let dir = DemoSeeder.photoDir else { return [] }
        let lib = SpeciesLibrary.shared
        return [("monstera", "monstera-deliciosa"), ("pothos", "epipremnum-aureum"), ("zz", "zamioculcas"), ("orchid", "phalaenopsis"), ("basil", "ocimum-basilicum")].compactMap { f, id in
            guard let d = try? Data(contentsOf: URL(fileURLWithPath: dir).appendingPathComponent("\(f).jpg")), let img = UIImage(data: ImageShrinker.jpeg(d, maxSide: 400)) else { return nil }
            let sp = lib.species(id: id)
            return ShelfImportView.Row(crop: img, species: sp, suggested: id, name: sp?.commonName ?? f)
        }
    }

    static func digest(_ plants: [Plant]) -> Digest? {
        func n(_ s: String) -> String { plants.first { $0.speciesID == s }?.name ?? "" }
        let iso = ISO8601DateFormatter()
        func day(_ d: Int) -> String { iso.string(from: Calendar.current.date(byAdding: .day, value: d, to: Date())!) }
        let json = """
        {"week":"w","due":[
          {"kind":"water","plant":"\(n("monstera-deliciosa"))","date":"\(day(1))"},
          {"kind":"feed","plant":"\(n("epipremnum-aureum"))","date":"\(day(2))"},
          {"kind":"water","plant":"\(n("phalaenopsis"))","date":"\(day(4))"}],
         "watch":[{"kind":"repot","plant":"\(n("zamioculcas"))"}],
         "grew":[{"kind":"newLeaf","plant":"\(n("monstera-deliciosa"))"},{"kind":"measure","plant":"\(n("ocimum-basilicum"))","value":24}],
         "photos":[],
         "next":{"week":"n","due":[
          {"kind":"water","plant":"\(n("spathiphyllum"))","date":"\(day(8))"},
          {"kind":"water","plant":"\(n("echeveria"))","date":"\(day(10))"},
          {"kind":"feed","plant":"\(n("monstera-deliciosa"))","date":"\(day(12))"}],
          "weather":[{"kind":"hot_dry_week","from":"\(day(8))","to":"\(day(11))"}]}}
        """
        return try? JungleAPI.decoder.decode(Digest.self, from: Data(json.utf8))
    }

    static var passport: PassportAPI.Shared { .init(token: "monty", url: "https://mytinyjungle.com/p/monty", card: nil) }
    static var passportNotes: String { t("Loves the morning sun by the window. Wipe the leaves once a month.", "Ama o solzinho da manhã na janela. Passa um paninho nas folhas uma vez por mês.") }
}

/// Store screenshot of the Home and Lock Screen widgets on a leafy wallpaper; same layout as JungleWidgets.
struct DemoWidgetBoard: View {
    let snap: JungleWidgetSnapshot
    private let ink = Color(red: 0x3E/255, green: 0x4E/255, blue: 0x3D/255), subtle = Color(red: 0x5C/255, green: 0x6B/255, blue: 0x5B/255)
    private let accent = Color(red: 0x3F/255, green: 0x7A/255, blue: 0x4A/255), warm = Color(red: 0xA9/255, green: 0x50/255, blue: 0x2F/255)
    private let bg = Color(red: 0xF6/255, green: 0xF3/255, blue: 0xEA/255)
    private var mood: ErtyMood { ErtyMood(rawValue: snap.mood) ?? .love }
    private var headline: String { snap.due.isEmpty ? DemoShots.t("All good today", "Tudo certo hoje") : DemoShots.t("\(snap.due.count) plants today", "\(snap.due.count) plantas hoje") }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.42, green: 0.62, blue: 0.45), Color(red: 0.16, green: 0.36, blue: 0.24)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            if let d = DemoSeeder.photoDir, let img = UIImage(contentsOfFile: d + "/monstera.jpg") {
                Color.clear.overlay(Image(uiImage: img).resizable().scaledToFill().opacity(0.55).blur(radius: 6)).clipped().ignoresSafeArea()
            }
            VStack(spacing: 22) {
                VStack(spacing: 2) {
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.system(.title3, design: .rounded).weight(.semibold))
                    Text("9:41").font(.system(size: 88, weight: .bold, design: .rounded))
                }.foregroundStyle(.white).shadow(radius: 8).padding(.top, 30)
                HStack(spacing: 12) { circular; rectangular }.foregroundStyle(.white)
                Spacer(minLength: 0)
                medium.frame(height: 180).layoutPriority(2)
                HStack(spacing: 22) { small.frame(width: 175, height: 175); smallNext.frame(width: 175, height: 175) }.layoutPriority(2)
            }.padding(.horizontal, 24)
        }
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(bg, in: RoundedRectangle(cornerRadius: 24, style: .continuous)).shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }
    private var circular: some View {
        VStack(spacing: 0) { Image(systemName: snap.due.first?.symbol ?? "leaf.fill").font(.caption); Text("\(snap.due.count)").font(.system(.title3, design: .rounded).weight(.bold)) }
            .frame(width: 66, height: 66).background(.ultraThinMaterial, in: Circle())
    }
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(headline, systemImage: "leaf.fill").font(.headline)
            Text(snap.due.prefix(3).map(\.name).formatted(.list(type: .and))).font(.caption).lineLimit(2)
        }.padding(.horizontal, 12).frame(width: 190, height: 66, alignment: .leading).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    private var small: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    ErtyView(mood: mood, size: 48); Spacer(minLength: 0)
                    Text("\(snap.due.count)").font(.system(.title, design: .rounded).weight(.bold)).foregroundStyle(snap.due.contains(where: \.urgent) ? warm : accent)
                }
                Text(headline).font(.system(.headline, design: .rounded)).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.8)
                if let d = snap.due.first { Label("\(d.name): \(d.need)", systemImage: d.symbol).font(.caption).foregroundStyle(d.urgent ? warm : subtle).lineLimit(2) }
            }
        }
    }
    private var smallNext: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                ErtyView(mood: .happy, size: 48)
                Text(DemoShots.t("Coming up", "Vem aí")).font(.system(.headline, design: .rounded)).foregroundStyle(ink)
                Label(snap.next?.line ?? snap.moodLine, systemImage: "calendar").font(.caption).foregroundStyle(subtle).lineLimit(3)
            }
        }
    }
    private var medium: some View {
        card {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    ErtyView(mood: mood, size: 60)
                    Text(snap.moodLine).font(.caption.weight(.semibold)).foregroundStyle(ink).lineLimit(2).frame(width: 90, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(headline).font(.system(.headline, design: .rounded)).foregroundStyle(ink)
                    ForEach(snap.due.prefix(3), id: \.id) { d in
                        Label { Text("\(d.name): \(d.need)").lineLimit(1) } icon: { Image(systemName: d.symbol).foregroundStyle(d.urgent ? warm : accent) }.font(.caption).foregroundStyle(ink)
                    }
                    Spacer(minLength: 0)
                    if let n = snap.next { Label(n.line, systemImage: "calendar").font(.caption2).foregroundStyle(subtle).lineLimit(1) }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Store screenshot: the plants' own notifications on a leafy Lock Screen, real copy from PlantNote.
struct DemoNotifyBoard: View {
    let plants: [Plant]
    @State private var notes: [(String, String, Data?)] = []

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.42, green: 0.62, blue: 0.45), Color(red: 0.16, green: 0.36, blue: 0.24)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            if let d = DemoSeeder.photoDir, let img = UIImage(contentsOfFile: d + "/pothos.jpg") {
                Color.clear.overlay(Image(uiImage: img).resizable().scaledToFill().opacity(0.6).blur(radius: 8)).clipped().ignoresSafeArea()
            }
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.system(.title3, design: .rounded).weight(.semibold))
                    Text("9:41").font(.system(size: 96, weight: .bold, design: .rounded))
                }.foregroundStyle(.white).shadow(radius: 8).padding(.top, 24).padding(.bottom, 20)
                ForEach(Array(notes.enumerated()), id: \.offset) { _, n in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            Image("AppMark").resizable().scaledToFit().frame(width: 42, height: 42).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            if let p = n.2 { PlantAvatar(data: p, size: 22).overlay(Circle().strokeBorder(.white, lineWidth: 1.5)).offset(x: 6, y: 6) }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text(n.0).font(.subheadline.weight(.semibold)); Spacer(); Text(DemoShots.t("now", "agora")).font(.caption).foregroundStyle(.secondary) }
                            Text(n.1).font(.subheadline).lineLimit(3)
                        }
                    }
                    .foregroundStyle(.black.opacity(0.85))
                    .padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                Spacer()
            }.padding(.horizontal, 14)
        }
        .environment(\.colorScheme, .light)
        .task {
            func named(_ sp: String) -> Plant { plants.first { $0.speciesID == sp } ?? plants[0] }
            guard !plants.isEmpty else { return }
            let list: [(PlantNote.Kind, Plant, String?, String?)] = [
                (.weather, named("echeveria"), Grammar.pt(String(localized: "Frost tonight (0°C)", comment: "Demo notification title")), Grammar.pt(String(localized: "Rosetta lives on the balcony. Please bring her inside or wrap her in fleece before bed. Frost hurts tender leaves.", comment: "Demo frost notification body in the plant's voice"))),
                (.water, named("monstera-deliciosa"), nil, nil),
                (.chat, named("phalaenopsis"), nil, Grammar.pt(String(localized: "Hey, it's me. I haven't seen you in a few days. How does my soil feel?", comment: "Demo chat notification body, plant missing its owner"))),
                (.struggling, named("spathiphyllum"), nil, nil),
                (.feed, named("ocimum-basilicum"), nil, nil),
            ]
            var out: [(String, String, Data?)] = []
            for (k, p, t, b) in list { let c = await PlantNote.make(k, plants: [p], title: t, body: b); out.append((c.title, c.body, p.photo)) }
            notes = out
        }
    }
}
