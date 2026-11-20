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
            case .stats: Grammar.pt(String(localized: "Diary", comment: "Share style name: cozy stats page; max 10 chars"))
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
                    ShareLink(item: Image(uiImage: img), message: Text(Grammar.pt(String(localized: "Meet \(plant.name)! Cared for with My Tiny Jungle 🌿 https://mytinyjungle.com", comment: "Text sent with a shared plant image; %@ plant name; keep the link"))), preview: SharePreview(plant.name, image: Image(uiImage: img))) {
                        Label(Grammar.pt(String(localized: "Share", comment: "Share button")), systemImage: "square.and.arrow.up")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).junglePrimary()
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

/// The story canvas (9:16). Warm, cozy, sticker-like: cream paper, a polaroid, the plant's own words.
struct ShareStory: View {
    let plant: Plant
    let style: ShareStudio.Style

    // Warm palette, fixed so the image looks the same in light and dark mode.
    private let cream = Color(red: 0.98, green: 0.95, blue: 0.90)
    private let paper = Color(red: 0.95, green: 0.91, blue: 0.84)
    private let ink = Color(red: 0.24, green: 0.20, blue: 0.16)
    private let soft = Color(red: 0.52, green: 0.45, blue: 0.38)
    private let leafy = Color(red: 0.30, green: 0.52, blue: 0.32)
    private let blush = Color(red: 0.96, green: 0.84, blue: 0.80)
    private let butter = Color(red: 0.99, green: 0.92, blue: 0.72)
    private let mint = Color(red: 0.86, green: 0.93, blue: 0.84)
    private let sky = Color(red: 0.84, green: 0.91, blue: 0.96)

    private var photo: Image {
        if let d = plant.photo, let ui = Thumbs.image(d, side: 440) { return Image(uiImage: ui) }
        return Image("AppMark")
    }
    private func fill(_ w: CGFloat? = nil, _ h: CGFloat? = nil) -> some View {
        Color.clear.frame(width: w, height: h).overlay { photo.resizable().scaledToFill() }.clipped()
    }
    private var days: Int { max(1, Int(CareEngine.days(from: plant.createdAt))) }
    private var cares: Int { (plant.events ?? []).filter { $0.kind != .note }.count }
    private var waters: Int { (plant.events ?? []).filter { $0.kind == .water }.count }
    private var leaves: Int { (plant.events ?? []).filter { $0.kind == .newLeaf }.count }
    private var leavesLabel: String { leaves == 1 ? Grammar.pt(String(localized: "new leaf", comment: "Share card stat unit: one new leaf; short, lowercase")) : Grammar.pt(String(localized: "new leaves", comment: "Share card stat unit: new leaves; short, lowercase")) }
    private var species: String { plant.species?.commonName ?? "" }
    private var since: String { plant.createdAt.formatted(.dateTime.month(.wide).year()) }
    private var quote: String { PlantVoice.happy(plant) }

    var body: some View {
        ZStack {
            switch style {
            case .card: polaroid
            case .photo: full
            case .stats: diary
            }
        }
        .environment(\.colorScheme, .light)
    }

    // MARK: Cartão — a frosted-glass polaroid, taped onto a dreamy blur of the plant.
    private var polaroid: some View {
        ZStack {
            dreamy
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                glassQuote.padding(.horizontal, 30).rotationEffect(.degrees(2))
                VStack(spacing: 12) {
                    fill(220, 236).clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: 0.8))
                    VStack(spacing: 1) {
                        Text(plant.name).font(.system(size: 26, weight: .heavy, design: .rounded))
                        if !species.isEmpty { Text(species).font(.system(size: 14, weight: .semibold, design: .rounded)).opacity(0.85) }
                    }
                    .foregroundStyle(.white).shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                    .padding(.bottom, 14)
                }
                .padding(.horizontal, 13).padding(.top, 13)
                .glassSkin(RoundedRectangle(cornerRadius: 8, style: .continuous), mask: false, tint: 0.32)
                .overlay(alignment: .top) { glassTape.offset(y: -11) }
                .rotationEffect(.degrees(-3))
                .padding(.top, 14).padding(.bottom, 12)
                HStack(spacing: 8) {
                    glassStat(.calendarHeart, "\(days)", Grammar.pt(String(localized: "days", comment: "Share card stat unit: days together; short")), false)
                    glassStat(.waterDrops, "\(waters)", Grammar.pt(String(localized: "waterings", comment: "Share card stat unit: waterings; short, lowercase")), false)
                    glassStat(.careHands, "\(cares)", Grammar.pt(String(localized: "cares", comment: "Share card stat unit: care moments; short")), false)
                }
                .padding(.horizontal, 22)
                Spacer(minLength: 0)
                glassBrand
            }
            .padding(.vertical, 22)
        }
    }

    // MARK: Diário — a journal page in glass: portrait, title, and our life together in rows.
    private var diary: some View {
        ZStack {
            dreamy
            VStack(spacing: 14) {
                fill(124, 124).clipShape(Circle())
                    .padding(6).glassSkin(Circle(), mask: false, tint: 0.3)
                    .padding(.top, 30)
                VStack(spacing: 3) {
                    Text(Grammar.pt(String(localized: "Me and \(plant.name)", comment: "Share diary title; %@ plant name"))).font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text(Grammar.pt(String(localized: "Together since \(since)", comment: "Share image line; %@ month and year"))).font(.system(size: 14, weight: .semibold, design: .rounded)).opacity(0.9)
                }
                .foregroundStyle(.white).shadow(color: .black.opacity(0.25), radius: 5, y: 1)
                VStack(spacing: 0) {
                    glassRow(.calendarHeart, "\(days)", Grammar.pt(String(localized: "days of friendship", comment: "Share diary row; short, lowercase")))
                    divider
                    glassRow(.waterDrops, "\(waters)", Grammar.pt(String(localized: "waterings with love", comment: "Share diary row; short, lowercase")))
                    divider
                    glassRow(.sprout, "\(leaves)", leavesLabel)
                    divider
                    glassRow(.careHands, "\(cares)", Grammar.pt(String(localized: "little cares", comment: "Share diary row: care moments; short, lowercase")))
                }
                .padding(.vertical, 6)
                .glassSkin(RoundedRectangle(cornerRadius: 30, style: .continuous), mask: false)
                .padding(.horizontal, 24)
                Spacer(minLength: 0)
                glassBrand
            }
            .padding(.bottom, 22)
        }
    }

    // MARK: glass pieces

    /// The plant, blurred into a soft warm wash: the "wallpaper" the glass sits on.
    private var dreamy: some View {
        ZStack {
            fill().blur(radius: 34).saturation(1.25).scaleEffect(1.15)
            LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.65).opacity(0.18), .clear, .black.opacity(0.25)], startPoint: .top, endPoint: .bottom)
        }
        .clipped()
    }

    private var glassQuote: some View {
        HStack(alignment: .top, spacing: 10) {
            fill(32, 32).clipShape(Circle()).overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
            Text("“\(quote)”").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                .lineLimit(4).fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .glassSkin(RoundedRectangle(cornerRadius: 24, style: .continuous), mask: false)
    }

    private var glassTape: some View {
        Rectangle().fill(.white.opacity(0.45)).frame(width: 78, height: 24)
            .overlay(Rectangle().strokeBorder(.white.opacity(0.6), lineWidth: 0.6))
            .rotationEffect(.degrees(5))
            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }

    private func glassRow(_ icon: Icon3D, _ n: String, _ l: String) -> some View {
        HStack(spacing: 12) {
            Icon3DView(icon, size: 32).frame(width: 46, height: 46).glassSkin(Circle(), mask: false, tint: 0.25)
            Text(n).font(.system(size: 26, weight: .heavy, design: .rounded)).monospacedDigit()
            Text(l).font(.system(size: 15, weight: .semibold, design: .rounded)).opacity(0.9)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white).shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        .padding(.horizontal, 12).padding(.vertical, 7)
    }

    private var divider: some View { Rectangle().fill(.white.opacity(0.25)).frame(height: 0.8).padding(.leading, 70).padding(.trailing, 16) }

    private var glassBrand: some View {
        HStack(spacing: 6) {
            Image("AppMark").resizable().scaledToFit().frame(width: 18, height: 18).clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
            Text("My Tiny Jungle").font(.system(size: 12, weight: .bold, design: .rounded))
            Text("· mytinyjungle.com").font(.system(size: 12, weight: .medium, design: .rounded)).opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .glassSkin(Capsule(), mask: false)
    }

    /// Liquid Glass look, rendered by hand so it survives ImageRenderer (system materials don't):
    /// a blurred copy of the photo shows through each glass shape, with a soft tint and a specular rim.
    private var full: some View {
        ZStack {
            fill()
            LinearGradient(colors: [.clear, .clear, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
            fill().blur(radius: 18).saturation(1.3).brightness(0.06).mask(glassLayout(mask: true))
            glassLayout(mask: false)
        }
    }

    private func glassLayout(mask: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                fill(34, 34).clipShape(Circle()).overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5))
                Text("“\(quote)”").font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    .lineLimit(4).fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
            }
            .opacity(mask ? 0 : 1)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .glassSkin(RoundedRectangle(cornerRadius: 26, style: .continuous), mask: mask)
            .padding(.trailing, 40).padding(.top, 34)
            Spacer()
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name).font(.system(size: 34, weight: .heavy, design: .rounded))
                Text(Grammar.pt(String(localized: "Together since \(since)", comment: "Share image line; %@ month and year"))).font(.system(size: 14, weight: .semibold, design: .rounded)).opacity(0.9)
            }
            .foregroundStyle(.white).shadow(color: .black.opacity(0.3), radius: 6, y: 1)
            .opacity(mask ? 0 : 1)
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSkin(RoundedRectangle(cornerRadius: 28, style: .continuous), mask: mask)
            HStack(spacing: 8) {
                glassStat(.calendarHeart, "\(days)", Grammar.pt(String(localized: "days", comment: "Share card stat unit: days together; short")), mask)
                glassStat(.waterDrops, "\(waters)", Grammar.pt(String(localized: "waterings", comment: "Share card stat unit: waterings; short, lowercase")), mask)
                glassStat(.sprout, "\(leaves)", leavesLabel, mask)
            }
            HStack(spacing: 6) {
                Image("AppMark").resizable().scaledToFit().frame(width: 18, height: 18).clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                Text("My Tiny Jungle").font(.system(size: 12, weight: .bold, design: .rounded))
                Text("· mytinyjungle.com").font(.system(size: 12, weight: .medium, design: .rounded)).opacity(0.8)
            }
            .foregroundStyle(.white)
            .opacity(mask ? 0 : 1)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .glassSkin(Capsule(), mask: mask)
            .frame(maxWidth: .infinity)
        }
        .padding(18)
    }

    private func glassStat(_ icon: Icon3D, _ n: String, _ l: String, _ mask: Bool) -> some View {
        VStack(spacing: 2) {
            Icon3DView(icon, size: 30)
            Text(n).font(.system(size: 22, weight: .heavy, design: .rounded)).monospacedDigit()
            Text(l).font(.system(size: 11, weight: .semibold, design: .rounded)).opacity(0.85).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white).shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        .opacity(mask ? 0 : 1)
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .glassSkin(RoundedRectangle(cornerRadius: 24, style: .continuous), mask: mask)
    }

    // MARK: pieces

    private func bubble(_ text: String, tailLeft: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            fill(30, 30).clipShape(Circle()).overlay(Circle().strokeBorder(.white, lineWidth: 2))
            Text("“\(text)”").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(ink)
                .lineLimit(4).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .messageBubble(fromMe: false, fill: .white)
        .shadow(color: ink.opacity(0.14), radius: 10, y: 4)
    }

    private func chip(_ icon: Icon3D, _ n: String, _ l: String, _ bg: Color) -> some View {
        VStack(spacing: 2) {
            Icon3DView(icon, size: 30)
            Text(n).font(.system(size: 20, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(ink)
            Text(l).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(soft).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(width: 92).padding(.vertical, 10)
        .background(bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white, lineWidth: 2.5))
        .shadow(color: ink.opacity(0.1), radius: 6, y: 3)
    }

    private func row(_ icon: Icon3D, _ n: String, _ l: String, _ bg: Color) -> some View {
        HStack(spacing: 12) {
            Icon3DView(icon, size: 34).frame(width: 50, height: 50).background(bg, in: Circle())
            Text(n).font(.system(size: 26, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(ink)
            Text(l).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(soft)
            Spacer(minLength: 0)
        }
        .padding(8).padding(.trailing, 8)
        .background(.white.opacity(0.8), in: Capsule())
    }

    private var tape: some View {
        Rectangle().fill(butter.opacity(0.85)).frame(width: 74, height: 22).rotationEffect(.degrees(4))
            .shadow(color: ink.opacity(0.08), radius: 2, y: 1)
    }

    /// A few hand-placed leaves and hearts, like stickers on a scrapbook page.
    private var confetti: some View {
        ZStack {
            Icon3DView(.leaf, size: 40).rotationEffect(.degrees(-20)).position(x: 46, y: 70).opacity(0.9)
            Icon3DView(.sunflower, size: 34).rotationEffect(.degrees(12)).position(x: 318, y: 96).opacity(0.9)
            Icon3DView(.sprout, size: 30).rotationEffect(.degrees(8)).position(x: 326, y: 560).opacity(0.85)
            Image(systemName: "heart.fill").font(.system(size: 14)).foregroundStyle(blush).position(x: 300, y: 180)
            Image(systemName: "heart.fill").font(.system(size: 10)).foregroundStyle(blush).position(x: 60, y: 520)
            Image(systemName: "sparkle").font(.system(size: 12)).foregroundStyle(butter).position(x: 34, y: 300)
        }
    }

    private var brand: some View {
        HStack(spacing: 6) {
            Image("AppMark").resizable().scaledToFit().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text("My Tiny Jungle").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(soft)
            Text("· mytinyjungle.com").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(soft.opacity(0.8))
        }
    }
    private var brandLight: some View {
        HStack(spacing: 6) {
            Image("AppMark").resizable().scaledToFit().frame(width: 20, height: 20).clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text("My Tiny Jungle").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
            Text("· mytinyjungle.com").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.75))
        }
    }
}

private extension View {
    /// Hand-made Liquid Glass: tint, top sheen, specular rim and a soft lift. In mask mode, a solid shape.
    @ViewBuilder func glassSkin<S: InsettableShape>(_ shape: S, mask: Bool, tint: Double = 0.16) -> some View {
        if mask {
            background(shape.fill(.black))
        } else {
            background {
                ZStack {
                    shape.fill(.white.opacity(tint))
                    shape.fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center))
                    shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.15), .white.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                }
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            }
        }
    }
}
