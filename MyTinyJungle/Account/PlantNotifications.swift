import Foundation
import UIKit
import Intents
import UserNotifications
import SwiftData

/// Every note a plant can send you, built the same way: its own voice, its own face, its own thread.
enum PlantNote {
    enum Kind: String, CaseIterable {
        case water, soil, feed, many, struggling, weather, travel, chat
        var category: String { "care.\(rawValue)" }
    }

    enum Action: String {
        case watered = "care.watered", wet = "care.wet", dry = "care.dry", fed = "care.fed", movedIn = "care.movedIn"
        case snooze = "care.snooze", tonight = "care.tonight", openChat = "care.openChat", reply = "care.reply"
    }

    static func registerCategories() {
        func a(_ id: Action, _ title: String, _ symbol: String, _ opts: UNNotificationActionOptions = []) -> UNNotificationAction {
            UNNotificationAction(identifier: id.rawValue, title: title, options: opts, icon: .init(systemImageName: symbol))
        }
        let watered = a(.watered, "Watered", "drop.fill")
        let wet = a(.wet, "Still wet", "hand.point.down.fill")
        let dry = a(.dry, "Feels dry", "sun.max.fill")
        let fed = a(.fed, "Fed", "leaf.fill")
        let moved = a(.movedIn, "Tucked in safe", "house.fill")
        let tonight = a(.tonight, "Remind me tonight", "moon.stars.fill")
        let snooze = a(.snooze, "Snooze to tomorrow", "moon.zzz.fill")
        let chat = a(.openChat, "Open chat", "bubble.left.and.bubble.right.fill", [.foreground])
        let reply = UNTextInputNotificationAction(identifier: Action.reply.rawValue, title: "Reply", options: [],
                                                  icon: .init(systemImageName: "arrowshape.turn.up.left.fill"),
                                                  textInputButtonTitle: "Send", textInputPlaceholder: "Say something sweet…")
        func cat(_ k: Kind, _ actions: [UNNotificationAction]) -> UNNotificationCategory {
            UNNotificationCategory(identifier: k.category, actions: actions, intentIdentifiers: ["INSendMessageIntent"],
                                   hiddenPreviewsBodyPlaceholder: "A plant is thinking of you",
                                   categorySummaryFormat: "%u notes from %@", options: [.customDismissAction])
        }
        UNUserNotificationCenter.current().setNotificationCategories([
            cat(.water, [watered, wet, tonight, reply, chat]),
            cat(.struggling, [watered, wet, tonight, chat]),
            cat(.soil, [dry, wet, tonight, reply]),
            cat(.feed, [fed, tonight, chat]),
            cat(.many, [watered, tonight, snooze]),
            cat(.weather, [moved, tonight]),
            cat(.travel, [watered, tonight]),
            cat(.chat, [reply, chat]),
        ])
    }

    // MARK: composing

    /// Builds the note. One plant: it texts you with its own face. Several: a warm jungle note with a collage.
    static func make(_ kind: Kind, plants: [Plant], title: String? = nil, body: String? = nil, now: Date = Date()) async -> UNNotificationContent {
        let c = UNMutableNotificationContent()
        let p = plants.first
        c.categoryIdentifier = kind.category
        c.sound = .default
        c.title = title ?? defaultTitle(kind, plants)
        c.body = body ?? voice(kind, plants: plants, now: now)
        c.userInfo = [
            "kind": kind.rawValue,
            "plants": plants.map(\.id.uuidString),
            "names": plants.map(\.name),
            "status": plants.map { p in
                switch kind {
                case .water: "Thirsty"
                case .soil: "Check my soil"
                case .feed: "Hungry"
                case .struggling: "Needs a drink"
                case .weather: title?.lowercased().contains("hot") == true ? "Heat ahead" : "Cold ahead"
                default: CareEngine.status(for: p, now: now).label
                }
            },
        ]
        c.threadIdentifier = plants.count == 1 ? "plant-\(p!.id)" : "jungle-\(kind.rawValue)"
        if plants.count == 1 { c.targetContentIdentifier = p!.id.uuidString }
        c.attachments = plants.prefix(4).compactMap(attachment)
        switch kind {
        case .struggling, .weather:
            c.interruptionLevel = .timeSensitive; c.relevanceScore = 1
        case .water, .soil:
            c.interruptionLevel = .active; c.relevanceScore = 0.7
        case .many, .travel, .chat:
            c.interruptionLevel = .active; c.relevanceScore = 0.6
        case .feed:
            c.interruptionLevel = .passive; c.relevanceScore = 0.3
        }
        // A plant that texts you: communication-style, its photo as the avatar.
        if plants.count == 1, let p, [.water, .soil, .feed, .struggling, .chat].contains(kind) {
            return (try? c.updating(from: await messageIntent(from: p, body: c.body))) ?? c
        }
        return c
    }

    static func messageIntent(from p: Plant, body: String) async -> INSendMessageIntent {
        let avatar = p.photo.flatMap(UIImage.init(data:))?.preparingThumbnail(of: CGSize(width: 240, height: 240))?.jpegData(compressionQuality: 0.85)
        let sender = INPerson(personHandle: INPersonHandle(value: p.id.uuidString, type: .unknown),
                              nameComponents: nil, displayName: p.name,
                              image: avatar.map { INImage(imageData: $0) },
                              contactIdentifier: nil, customIdentifier: p.id.uuidString)
        let intent = INSendMessageIntent(recipients: nil, outgoingMessageType: .outgoingMessageText, content: body,
                                         speakableGroupName: nil, conversationIdentifier: "plant-\(p.id)",
                                         serviceName: nil, sender: sender, attachments: nil)
        if let avatar { intent.setImage(INImage(imageData: avatar), forParameterNamed: \.sender) }
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        try? await interaction.donate()
        return intent
    }

    static func defaultTitle(_ k: Kind, _ ps: [Plant]) -> String {
        let n = ps.first?.name ?? "Your jungle"
        switch k {
        case .water, .soil, .feed, .chat, .struggling: return n
        case .many: return "\(ps.count) plants would love a visit"
        case .weather: return "Keep \(n) cosy tonight"
        case .travel: return "Before your trip"
        }
    }

    /// The plant's own words, in its personality.
    static func voice(_ k: Kind, plants: [Plant], now: Date = Date()) -> String {
        guard let p = plants.first else { return "Your plants are thinking of you." }
        func say(_ r: PlantRequest.Kind) -> String { PlantVoice.say(.init(plantID: p.id, kind: r, priority: 1, reason: ""), plant: p) }
        switch k {
        case .water: return say(.water)
        case .soil: return say(.checkSoil)
        case .feed: return say(.feed)
        case .chat: return ProactiveVoice.voice(InsightEngine.pattern(for: p, now: now) ?? .init(id: "x-missed", plantID: p.id, tone: .pattern, icon: .heartPin, text: ""), plant: p)
        case .struggling:
            switch p.personality {
            case .dramatic: return "I'm wilting over here. Truly. One slow, deep drink would bring me back to life."
            case .independent: return "It's been a long time. Please check my soil today."
            case .calm: return "I'm feeling quite dry. Whenever you can today, a slow drink would help me so much."
            default: return "I miss you! It's been ages since my last drink. Could you feel my soil today?"
            }
        case .many:
            let names = ListFormatter.localizedString(byJoining: plants.prefix(3).map(\.name)) + (plants.count > 3 ? " and \(plants.count - 3) more" : "")
            return "\(names) are ready for a little love today."
        case .weather: return "A cold night is coming. Please bring \(p.name) inside or wrap it in fleece before bed."
        case .travel: return "Tomorrow you travel. A deep, slow drink for everyone tonight, and they'll wait happily for you."
        }
    }

    /// The plant's photo as a native thumbnail, written to a temp file.
    static func attachment(_ p: Plant) -> UNNotificationAttachment? {
        guard let data = p.photo, let img = UIImage(data: data),
              let jpg = img.preparingThumbnail(of: CGSize(width: 900, height: 900 * img.size.height / max(img.size.width, 1)))?.jpegData(compressionQuality: 0.82) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("plant-\(p.id)-\(UUID().uuidString.prefix(6)).jpg")
        guard (try? jpg.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: p.id.uuidString, url: url, options: [UNNotificationAttachmentOptionsThumbnailHiddenKey: false])
    }

    // MARK: actions

    @MainActor
    static func handle(_ response: UNNotificationResponse, ctx: ModelContext) async {
        let info = response.notification.request.content.userInfo
        let ids = Set((info["plants"] as? [String] ?? []).compactMap(UUID.init))
        let all = (try? ctx.fetch(FetchDescriptor<Plant>(predicate: #Predicate { !$0.isArchived }))) ?? []
        let plants = all.filter { ids.contains($0.id) }
        let now = Date()
        func log(_ k: CareKind, soil: SoilState? = nil) {
            for p in plants { JungleBrain.apply(.init(kind: k, plantIDs: [p.id], date: now, soil: soil), to: p, in: ctx, now: now, source: "notification") }
        }
        // A single plant's note becomes part of its chat, so a reply or "Open chat" lands in context.
        let body = response.notification.request.content.body
        if plants.count == 1, let p = plants.first, !body.isEmpty,
           [Action.reply.rawValue, Action.openChat.rawValue, UNNotificationDefaultActionIdentifier].contains(response.actionIdentifier),
           !(p.messages ?? []).contains(where: { !$0.fromUser && $0.text == body }) {
            let m = ChatMessage(text: body, fromUser: false, plant: p)
            m.date = response.notification.date
            ctx.insert(m)
            try? ctx.save()
        }
        switch response.actionIdentifier {
        case Action.watered.rawValue: log(.water)
        case Action.wet.rawValue: log(.soilCheck, soil: .wet)
        case Action.dry.rawValue: log(.soilCheck, soil: .dry)
        case Action.fed.rawValue: log(.feed)
        case Action.movedIn.rawValue:
            for p in plants { JungleBrain.apply(.init(kind: .move, plantIDs: [p.id], date: now, detail: nil), to: p, in: ctx, now: now, source: "notification") }
        case Action.snooze.rawValue:
            let tomorrow = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400)).addingTimeInterval(3600)
            for p in plants { UserDefaults.standard.set(tomorrow, forKey: "snooze.\(p.id)") }
        case Action.tonight.rawValue:
            let cal = Calendar.current
            let seven = cal.date(bySettingHour: 19, minute: 0, second: 0, of: now)!
            let fire = CarePrefs.gentle(seven > now.addingTimeInterval(1800) ? seven : now.addingTimeInterval(3 * 3600))
            let again = response.notification.request.content
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "care-tonight-\(UUID().uuidString.prefix(6))", content: again,
                                                                                     trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(60, fire.timeIntervalSince(now)), repeats: false)))
        case Action.reply.rawValue:
            if let text = (response as? UNTextInputNotificationResponse)?.userText.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                JungleBrain.handle(text, plant: plants.first, plants: all, in: ctx)
            }
        case Action.openChat.rawValue, UNNotificationDefaultActionIdentifier:
            if let p = plants.first, plants.count == 1 { UserDefaults.standard.set(p.id.uuidString, forKey: "openPlantChat") }
            else { UserDefaults.standard.set(0, forKey: "selectedTab") }
            return
        default: return
        }
        try? ctx.save()
        await CareReminders.reschedule(ctx)
    }

    // MARK: demo, for screenshots and QA (-notifyDemo)

    @MainActor
    static func demo(_ ctx: ModelContext) async {
        let plants = (try? ctx.fetch(FetchDescriptor<Plant>(predicate: #Predicate { !$0.isArchived }, sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        guard plants.count >= 4 else { return }
        func named(_ n: String) -> Plant { plants.first { $0.name == n } ?? plants[0] }
        let start = Double(ProcessInfo.processInfo.environment["NOTIFY_DELAY"] ?? "") ?? 10
        let gap = Double(ProcessInfo.processInfo.environment["NOTIFY_GAP"] ?? "") ?? 8
        let only = ProcessInfo.processInfo.environment["NOTIFY_ONLY"]
        let notes: [(Kind, [Plant], String?, String?)] = [
            (.many, Array(plants.prefix(4)), nil, nil),
            (.water, [named("Monty")], nil, nil),
            (.soil, [named("Goldie")], nil, nil),
            (.feed, [named("Pesto")], nil, nil),
            (.struggling, [named("Lily")], nil, nil),
            (.weather, [named("Rosetta")], "Frost tonight (0°C)", "Rosetta lives on the balcony. Please bring her inside or wrap her in fleece before bed. Frost hurts tender leaves."),
            (.weather, [named("Rosetta")], "A hot one tomorrow (36°C)", "Rosetta would love some afternoon shade and a deep drink in the cool of the morning."),
            (.travel, plants, nil, nil),
            (.chat, [named("Pearl")], nil, "Hey, it's me. I haven't seen you in a few days. How does my soil feel?"),
        ]
        let center = UNUserNotificationCenter.current()
        for (i, n) in notes.enumerated() where only == nil || only == "\(i)" {
            var c = await make(n.0, plants: n.1, title: n.2, body: n.3)
            // Capturing a single passive note: let it show as a banner so it can be previewed.
            if only != nil, c.interruptionLevel == .passive, let m = c.mutableCopy() as? UNMutableNotificationContent { m.interruptionLevel = .active; c = m }
            let t = only == nil ? start + Double(i) * gap : start
            do { try await center.add(UNNotificationRequest(identifier: "demo-\(i)-\(Int(Date().timeIntervalSince1970))", content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: t, repeats: false))) }
            catch { UserDefaults.standard.set("\(i): \(error)", forKey: "demoError") }
            UserDefaults.standard.set(i, forKey: "demoScheduled")
        }
    }
}
