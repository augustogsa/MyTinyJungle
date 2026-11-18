import SwiftUI

/// Story-ready share of a plant: photo, stats and My Tiny Jungle branding, rendered to an image
/// and sent through the native share sheet (Instagram, WhatsApp, Messages, Photos…).
struct ShareStudio: View {
    let plant: Plant
    @Environment(\.dismiss) private var dismiss
    @State private var style: Style = .card

    enum Style: String, CaseIterable, Identifiable {
        case card, photo, stats
        var id: String { rawValue }
        var label: String {
            switch self {
            case .card: Grammar.pt(String(localized: "Card", comment: "Share style name; max 10 chars"))
            case .photo: Grammar.pt(String(localized: "Photo", comment: "Share style name; max 10 chars"))
            case .stats: Grammar.pt(String(localized: "Stats", comment: "Share style name; max 10 chars"))
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ShareStory(plant: plant, style: style)
                    .frame(width: 360, height: 640)
                    .scaleEffect(0.75)
                    .frame(width: 270, height: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
                    .animation(.snappy, value: style)
                    .frame(maxHeight: .infinity)

                Picker("", selection: $style) {
                    ForEach(Style.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 32)

                if let img = render() {
                    ShareLink(item: Image(uiImage: img), preview: SharePreview(plant.name, image: Image(uiImage: img))) {
                        Label(Grammar.pt(String(localized: "Share", comment: "Share button")), systemImage: "square.and.arrow.up")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(Jungle.forest)
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 16)
            .jungleBackdrop()
            .navigationTitle(Grammar.pt(String(localized: "Share \(plant.name)", comment: "Share screen title; %@ plant name")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } } }
        }
    }

    /// 1080×1920 story image.
    @MainActor private func render() -> UIImage? {
        let r = ImageRenderer(content: ShareStory(plant: plant, style: style).frame(width: 360, height: 640))
        r.scale = 3
        return r.uiImage
    }
}

/// The story canvas (9:16).
struct ShareStory: View {
    let plant: Plant
    let style: ShareStudio.Style

    private var photo: Image {
        if let d = plant.photo, let ui = UIImage(data: d) { return Image(uiImage: ui) }
        return Image("AppMark")
    }
    /// Photo that fills the canvas without growing it.
    private var fill: some View { Color.clear.overlay { photo.resizable().scaledToFill() }.clipped() }
    private var days: Int { max(1, Int(CareEngine.days(from: plant.createdAt))) }
    private var cares: Int { (plant.events ?? []).filter { $0.kind != .note }.count }
    private var waters: Int { (plant.events ?? []).filter { $0.kind == .water }.count }
    private var species: String { plant.species?.commonName ?? "" }

    var body: some View {
        ZStack {
            switch style {
            case .card: card
            case .photo: full
            case .stats: stats
            }
        }
        .environment(\.colorScheme, style == .card ? .light : .dark)
    }

    // Apple Music–style sticker card on a blurred photo.
    private var card: some View {
        ZStack {
            fill.blur(radius: 40).overlay(Color.black.opacity(0.15))
            VStack(alignment: .leading, spacing: 10) {
                photo.resizable().scaledToFill()
                    .frame(width: 216, height: 216).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(plant.name).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(.black)
                    if !species.isEmpty { Text(species).font(.system(size: 15)).foregroundStyle(.black.opacity(0.75)) }
                }
                HStack(spacing: 14) {
                    mini("\(days)", Grammar.pt(String(localized: "days", comment: "Share card stat unit: days together; short")))
                    mini("\(cares)", Grammar.pt(String(localized: "cares", comment: "Share card stat unit: care moments; short")))
                }
                brand(dark: false)
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
        }
    }

    // Full-bleed photo with stats overlaid, like a ride share.
    private var full: some View {
        ZStack(alignment: .bottomLeading) {
            fill
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 12) {
                Text(plant.name).font(.system(size: 34, weight: .bold, design: .rounded))
                if !species.isEmpty { Text(species).font(.system(size: 16, weight: .medium)).opacity(0.85) }
                HStack(alignment: .top, spacing: 22) {
                    big("\(days)", Grammar.pt(String(localized: "Days together", comment: "Share stat label; short")), .green)
                    big("\(waters)", Grammar.pt(String(localized: "Waterings", comment: "Share stat label; short")), .cyan)
                    big("\(cares)", Grammar.pt(String(localized: "Care moments", comment: "Share stat label; short")), .yellow)
                }
                brand(dark: true)
            }
            .foregroundStyle(.white)
            .padding(24)
        }
    }

    // Bold numbers on deep green, with a photo badge.
    private var stats: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.22, blue: 0.15), Color(red: 0.03, green: 0.1, blue: 0.07)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 18) {
                photo.resizable().scaledToFill().frame(width: 84, height: 84).clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 2))
                Text(plant.name).font(.system(size: 30, weight: .bold, design: .rounded))
                VStack(alignment: .leading, spacing: 14) {
                    big("\(days)", Grammar.pt(String(localized: "Days together", comment: "Share stat label; short")), .green)
                    big("\(waters)", Grammar.pt(String(localized: "Waterings", comment: "Share stat label; short")), .cyan)
                    big("\(cares)", Grammar.pt(String(localized: "Care moments", comment: "Share stat label; short")), .yellow)
                }
                Spacer()
                brand(dark: true)
            }
            .foregroundStyle(.white)
            .padding(28).padding(.top, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func mini(_ n: String, _ l: String) -> some View {
        HStack(spacing: 4) {
            Text(n).font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(l).font(.system(size: 13))
        }.foregroundStyle(.black.opacity(0.7))
    }

    private func big(_ n: String, _ l: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(l.uppercased()).font(.system(size: 11, weight: .semibold)).opacity(0.8)
            Text(n).font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(c)
        }
    }

    private func brand(dark: Bool) -> some View {
        HStack(spacing: 6) {
            Image("AppMark").resizable().scaledToFit().frame(width: 18, height: 18).clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
            Text("My Tiny Jungle").font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(dark ? .white.opacity(0.85) : .black.opacity(0.45))
    }
}
