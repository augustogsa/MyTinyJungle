import UIKit
import SwiftUI
import UserNotifications
import UserNotificationsUI

/// The expanded note: the plant's big photo (or a collage of several), its name, how it feels, and its words.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private var host: UIHostingController<NoteCard>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    func didReceive(_ notification: UNNotification) {
        let c = notification.request.content
        let images: [UIImage] = c.attachments.prefix(4).compactMap { a in
            guard a.url.startAccessingSecurityScopedResource() else { return nil }
            defer { a.url.stopAccessingSecurityScopedResource() }
            return (try? Data(contentsOf: a.url)).flatMap(UIImage.init(data:))
        }
        let card = NoteCard(kind: c.userInfo["kind"] as? String ?? "",
                            names: c.userInfo["names"] as? [String] ?? [],
                            status: c.userInfo["status"] as? [String] ?? [],
                            title: c.title, message: c.body, images: images)
        host?.view.removeFromSuperview()
        let h = UIHostingController(rootView: card)
        h.view.backgroundColor = .clear
        h.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(h)
        view.addSubview(h.view)
        NSLayoutConstraint.activate([
            h.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            h.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            h.view.topAnchor.constraint(equalTo: view.topAnchor),
            h.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        h.didMove(toParent: self)
        host = h
        preferredContentSize = CGSize(width: view.bounds.width, height: view.bounds.width * 1.15)
    }
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { t in
            let v = t.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        })
    }
    static let ink = Color(light: 0x3E4E3D, dark: 0xE4EBE2)
    static let subtle = Color(light: 0x5C6B5B, dark: 0xA3B0A1)
    static let cream = Color(light: 0xFCFAF6, dark: 0x141A15)
    static let mint = Color(light: 0xEEF7E8, dark: 0x223024)
    static let forest = Color(light: 0x2F5D3A, dark: 0x8DBE8F)
    static let terracotta = Color(light: 0xB8664A, dark: 0xE3A68B)
    static let sky = Color(light: 0x3F6F99, dark: 0x9CC3E6)
}

struct NoteCard: View {
    let kind: String
    let names: [String]
    let status: [String]
    let title: String
    let message: String
    let images: [UIImage]

    private var tint: Color {
        switch kind {
        case "struggling", "weather": .terracotta
        case "water", "soil", "travel": .sky
        default: .forest
        }
    }
    private var symbol: String {
        switch kind {
        case "water": "drop.fill"
        case "soil": "hand.point.down.fill"
        case "feed": "leaf.fill"
        case "struggling": "heart.fill"
        case "weather": title.contains("hot") ? "sun.max.fill" : "snowflake"
        case "travel": "airplane"
        case "chat": "bubble.left.fill"
        default: "sparkles"
        }
    }
    private var heading: String { names.count == 1 ? names[0] : title }
    private var pill: String? {
        if names.count == 1 { return status.first }
        return names.isEmpty ? nil : "\(names.count) plants"
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                photos.frame(width: geo.size.width, height: geo.size.height).clipped()
                LinearGradient(stops: [.init(color: .clear, location: 0.35), .init(color: .black.opacity(0.35), location: 0.6), .init(color: .black.opacity(0.7), location: 1)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if let pill {
                            Label(pill, systemImage: symbol)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(tint)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.regularMaterial, in: Capsule())
                        }
                        Spacer()
                    }
                    Text(heading)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                        .lineLimit(2)
                    if names.count > 1 {
                        Text(names.count > 4 ? names.prefix(3).joined(separator: ", ") + " and \(names.count - 3) more" : ListFormatter.localizedString(byJoining: names))
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    }
                    Text(message)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.cream.opacity(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(16)
            }
        }
        .background(Color.mint)
    }

    @ViewBuilder private var photos: some View {
        switch images.count {
        case 0:
            ZStack {
                LinearGradient(colors: [Color.mint, Color.cream], startPoint: .top, endPoint: .bottom)
                Image(systemName: symbol).font(.system(size: 72, weight: .semibold)).foregroundStyle(tint.opacity(0.75)).offset(y: -50)
            }
        case 1:
            Image(uiImage: images[0]).resizable().scaledToFill()
        case 2:
            HStack(spacing: 2) { ForEach(0..<2, id: \.self) { tile(images[$0]) } }
        case 3:
            HStack(spacing: 2) {
                tile(images[0])
                VStack(spacing: 2) { tile(images[1]); tile(images[2]) }
            }
        default:
            VStack(spacing: 2) {
                HStack(spacing: 2) { tile(images[0]); tile(images[1]) }
                HStack(spacing: 2) { tile(images[2]); tile(images[3]) }
            }
        }
    }

    private func tile(_ i: UIImage) -> some View {
        Color.clear.overlay(Image(uiImage: i).resizable().scaledToFill()).clipped()
    }
}
