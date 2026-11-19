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
        let watered = a(.watered, Grammar.pt(String(localized: "Watered", comment: "Notification action button: I watered it; max 20 chars")), "drop.fill")
        let wet = a(.wet, Grammar.pt(String(localized: "Still wet", comment: "Notification action: soil is still wet; max 20 chars")), "hand.point.down.fill")
        let dry = a(.dry, Grammar.pt(String(localized: "Feels dry", comment: "Notification action: soil feels dry; max 20 chars")), "sun.max.fill")
        let fed = a(.fed, Grammar.pt(String(localized: "Fed", comment: "Notification action: I fertilized it; max 20 chars")), "leaf.fill")
        let moved = a(.movedIn, Grammar.pt(String(localized: "Tucked in safe", comment: "Notification action: plant moved inside from cold; max 22 chars")), "house.fill")
        let tonight = a(.tonight, Grammar.pt(String(localized: "Remind me tonight", comment: "Notification action; max 24 chars")), "moon.stars.fill")
        let snooze = a(.snooze, Grammar.pt(String(localized: "Snooze to tomorrow", comment: "Notification action; max 24 chars")), "moon.zzz.fill")
        let chat = a(.openChat, Grammar.pt(String(localized: "Open chat", comment: "Notification action: opens chat with plant; max 20 chars")), "bubble.left.and.bubble.right.fill", [.foreground])
        let reply = UNTextInputNotificationAction(identifier: Action.reply.rawValue, title: Grammar.pt(String(localized: "Reply", comment: "Notification text reply action; max 15 chars")), options: [],
                                                  icon: .init(systemImageName: "arrowshape.turn.up.left.fill"),
                                                  textInputButtonTitle: Grammar.pt(String(localized: "Send", comment: "Send button for notification reply; max 10 chars")), textInputPlaceholder: Grammar.pt(String(localized: "Say something sweet…", comment: "Placeholder for reply to a plant; playful")))
        func cat(_ k: Kind, _ actions: [UNNotificationAction]) -> UNNotificationCategory {
            UNNotificationCategory(identifier: k.category, actions: actions, intentIdentifiers: ["INSendMessageIntent"],
                                   hiddenPreviewsBodyPlaceholder: Grammar.pt(String(localized: "A plant is thinking of you", comment: "Notification body when previews hidden")),
                                   categorySummaryFormat: Grammar.pt(String(localized: "%u notes from %@", comment: "Grouped notification summary; %u count, %@ plant names. Keep %u and %@")), options: [.customDismissAction])
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
                case .water: Grammar.pt(String(localized: "Thirsty", comment: "Status pill on notification; max 16 chars"))
                case .soil: Grammar.pt(String(localized: "Check my soil", comment: "Status pill, plant speaking; max 16 chars"))
                case .feed: Grammar.pt(String(localized: "Hungry", comment: "Status pill: needs fertilizer; max 16 chars"))
                case .struggling: Grammar.pt(String(localized: "Needs a drink", comment: "Status pill: very dry; max 16 chars"))
                case .weather: title?.lowercased().contains("hot") == true ? Grammar.pt(String(localized: "Heat ahead", comment: "Status pill: hot weather coming; max 16 chars")) : Grammar.pt(String(localized: "Cold ahead", comment: "Status pill: cold weather coming; max 16 chars"))
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
        let avatar = p.photo.flatMap { BrainPhoto.encode($0, maxSide: 240, quality: 0.85) }
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
        let n = ps.first?.name ?? Grammar.pt(String(localized: "Your jungle", comment: "Notification title fallback when no plant; brand Jungle stays"))
        switch k {
        case .water, .soil, .feed, .chat, .struggling: return n
        case .many: return Grammar.pt(String(localized: "\(ps.count) plants would love a visit", comment: "Notification title; %lld plant count (plural)"))
        case .weather: return Grammar.pt(String(localized: "Keep \(n) cosy tonight", comment: "Notification title; %@ plant name; cold night"))
        case .travel: return Grammar.pt(String(localized: "Before your trip", comment: "Notification title before user travels"))
        }
    }

    /// The plant's own words, in its personality.
    static func voice(_ k: Kind, plants: [Plant], now: Date = Date()) -> String {
        guard let p = plants.first else { return Grammar.pt(String(localized: "Your plants are thinking of you.", comment: "Notification body fallback")) }
        func say(_ r: PlantRequest.Kind) -> String { PlantVoice.say(.init(plantID: p.id, kind: r, priority: 1, reason: ""), plant: p) }
        switch k {
        case .water, .soil:
            if let mk = CareEngine.mediumKind(p) { return say(mk) }
            return say(k == .water ? .water : .checkSoil)
        case .feed: return say(.feed)
        case .chat: return ProactiveVoice.voice(InsightEngine.pattern(for: p, now: now) ?? .init(id: "x-missed", plantID: p.id, tone: .pattern, icon: .heartPin, text: ""), plant: p)
        case .struggling:
            switch p.personality {
            case .dramatic: return Grammar.pt(String(localized: "I'm wilting over here. Truly. One slow, deep drink would bring me back to life.", comment: "Plant speaking, dramatic personality, very dry; theatrical"))
            case .independent: return Grammar.pt(String(localized: "It's been a long time. Please check my soil today.", comment: "Plant speaking, independent personality, very dry; terse"))
            case .calm: return Grammar.pt(String(localized: "I'm feeling quite dry. Whenever you can today, a slow drink would help me so much.", comment: "Plant speaking, calm personality, very dry; gentle"))
            default: return Grammar.pt(String(localized: "I miss you! It's been ages since my last drink. Could you feel my soil today?", comment: "Plant speaking, default personality, very dry; affectionate"))
            }
        case .many:
            if plants.count > 3 {
                let shown = plants.prefix(3).map(\.name).joined(separator: ", ")
                return Grammar.pt(String(localized: "\(shown) and \(plants.count - 3) more are ready for a little love today.", comment: "Notification body; %@ three plant names, %lld how many more (plural)"))
            }
            let names = plants.map(\.name).formatted(.list(type: .and))
            return Grammar.pt(String(localized: "\(names) are ready for a little love today.", comment: "Notification body; %@ list of 2-3 plant names"))
        case .weather: return Grammar.pt(String(localized: "A cold night is coming. Please bring \(p.name) inside or wrap it in fleece before bed.", comment: "Notification body; %@ plant name; frost warning"))
        case .travel: return Grammar.pt(String(localized: "Tomorrow you travel. A deep, slow drink for everyone tonight, and they'll wait happily for you.", comment: "Notification body before trip"))
        }
    }

    /// The plant's photo as a native thumbnail, written to a temp file.
    static func attachment(_ p: Plant) -> UNNotificationAttachment? {
        guard let data = p.photo, let jpg = BrainPhoto.encode(data, maxSide: 900, quality: 0.82) else { return nil }
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
        func named(_ n: String) -> Plant { let local = Grammar.pt(String(localized: String.LocalizationValue(n))); return plants.first { $0.name == local || $0.name == n } ?? plants[0] }
        let start = Double(ProcessInfo.processInfo.environment["NOTIFY_DELAY"] ?? "") ?? 10
        let gap = Double(ProcessInfo.processInfo.environment["NOTIFY_GAP"] ?? "") ?? 8
        let only = ProcessInfo.processInfo.environment["NOTIFY_ONLY"]
        let notes: [(Kind, [Plant], String?, String?)] = [
            (.many, Array(plants.prefix(4)), nil, nil),
            (.water, [named("Monty")], nil, nil),
            (.soil, [named("Goldie")], nil, nil),
            (.feed, [named("Pesto")], nil, nil),
            (.struggling, [named("Lily")], nil, nil),
            (.weather, [named("Rosetta")], Grammar.pt(String(localized: "Frost tonight (0°C)", comment: "Demo notification title")), Grammar.pt(String(localized: "Rosetta lives on the balcony. Please bring her inside or wrap her in fleece before bed. Frost hurts tender leaves.", comment: "Demo frost notification body in the plant's voice"))),
            (.weather, [named("Rosetta")], Grammar.pt(String(localized: "A hot one tomorrow (36°C)", comment: "Demo notification title")), Grammar.pt(String(localized: "Rosetta would love some afternoon shade and a deep drink in the cool of the morning.", comment: "Demo heat notification body"))),
            (.travel, plants, nil, nil),
            (.chat, [named("Pearl")], nil, Grammar.pt(String(localized: "Hey, it's me. I haven't seen you in a few days. How does my soil feel?", comment: "Demo chat notification body, plant missing its owner"))),
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
