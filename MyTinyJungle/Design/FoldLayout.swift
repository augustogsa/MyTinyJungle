import SwiftUI

/// How a tab page lays out in the space it really has: one phone column, two columns on a wide
/// window, or two pages either side of the iPhone Duo's fold (the book pose). Decided from the
/// measured width and the system's reserved division region, never from a device model.
struct PageSpread: Equatable {
    /// Width of the page's content column (gutters excluded).
    var width: CGFloat = 0
    /// Book pose: the leading page width, the gap across the fold, the trailing page width.
    var book: (leading: CGFloat, gap: CGFloat, trailing: CGFloat)?

    static let wideThreshold: CGFloat = 700
    static let gutter: CGFloat = 16
    static let wideGap: CGFloat = 24

    var isWide: Bool { book != nil || width >= Self.wideThreshold }

    /// Column widths for the two pages (nil on a phone column).
    var pages: (leading: CGFloat, gap: CGFloat, trailing: CGFloat)? {
        if let book { return book }
        guard width >= Self.wideThreshold else { return nil }
        let half = (width - Self.wideGap) / 2
        return (half, Self.wideGap, half)
    }

    /// Grid columns: two on a phone, more when wide, and in the book pose an even split with the
    /// fold in the gap between the two halves, so no tile ever sits on the hinge.
    func gridColumns(minimum: CGFloat = 160, spacing: CGFloat = 12) -> [GridItem] {
        if let p = pages {
            let perPage = max(1, Int((min(p.leading, p.trailing) + spacing) / (minimum + spacing)))
            let lw = (p.leading - spacing * CGFloat(perPage - 1)) / CGFloat(perPage)
            let tw = (p.trailing - spacing * CGFloat(perPage - 1)) / CGFloat(perPage)
            return (0..<perPage).map { GridItem(.flexible(minimum: 0, maximum: lw), spacing: $0 == perPage - 1 ? p.gap : spacing, alignment: .top) }
                + (0..<perPage).map { _ in GridItem(.flexible(minimum: 0, maximum: tw), spacing: spacing, alignment: .top) }
        }
        return [GridItem(.flexible(), spacing: spacing, alignment: .top), GridItem(.flexible(), spacing: spacing, alignment: .top)]
    }

    static func == (a: PageSpread, b: PageSpread) -> Bool {
        a.width == b.width && a.book?.leading == b.book?.leading && a.book?.gap == b.book?.gap && a.book?.trailing == b.book?.trailing
    }
}

extension EnvironmentValues {
    @Entry var pageSpread = PageSpread()
}

/// The active fold division in a view's own coordinates (nil when flat, closed or not foldable).
enum FoldDivision {
    static func active(in proxy: GeometryProxy) -> CGRect? {
        if #available(iOS 27.1, *) {
            return proxy.reservedRegions(kind: .division, options: [], layoutDirectionBehavior: .fixed)
                .first { $0.isActive && $0.frame.width > 0 && $0.frame.height > 0 }?.frame
        }
        return nil
    }
}

private struct PageSpreadReader: ViewModifier {
    /// The page's horizontal padding between this view's edges and its content column.
    let inset: CGFloat
    @State private var spread = PageSpread()
    @State private var width: CGFloat = 0
    @State private var fold: CGRect?

    func body(content: Content) -> some View {
        content
            .environment(\.pageSpread, spread)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0; publish() }
            .onFoldDivisionChange { fold = $0; publish() }
    }

    private func publish() {
        guard width > 0 else { return }
        let next = Self.spread(width: width - inset * 2, fold: fold?.offsetBy(dx: -inset, dy: 0))
        if next != spread { spread = next }
    }

    static func spread(width: CGFloat, fold: CGRect?) -> PageSpread {
        var s = PageSpread(width: width)
        // A vertical division running down the page with room for a page either side.
        if let fold, fold.height > fold.width, fold.minX > 200, width - fold.maxX > 200 {
            let g = PageSpread.gutter
            s.book = (fold.minX - g, fold.width + g * 2, width - fold.maxX - g)
        }
        return s
    }
}

extension View {
    /// Measures a tab page and publishes its `PageSpread` to everything inside. Attach to the
    /// page's scroll view; `inset` is the horizontal padding of its content column.
    func measuresPageSpread(inset: CGFloat = PageSpread.gutter) -> some View { modifier(PageSpreadReader(inset: inset)) }

    /// Bottom bars (the chat composer): in the book pose they sit on the trailing page only.
    func trailingPageInBook() -> some View { modifier(TrailingPageInBook()) }

    /// A horizontal rail inside a page: cards spill past the content column only by the page
    /// gutter, so they never run under the Duo's vertical bar or across the fold.
    func pageRail() -> some View {
        contentMargins(.horizontal, PageSpread.gutter, for: .scrollContent)
            .contentMargins(.vertical, 10, for: .scrollContent)
            .clipShape(Rectangle())
            .padding(.horizontal, -PageSpread.gutter)
            .padding(.vertical, -10)
    }
}

/// One column on a phone; two pages on a wide window, split exactly at the fold in the book pose.
struct TwoPage<Leading: View, Trailing: View>: View {
    var spacing: CGFloat = 22
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing
    @Environment(\.pageSpread) private var spread

    var body: some View {
        if let p = spread.pages {
            // Caps, never fixed widths: fixed pages would hold the scroll view open while the window
            // shrinks (rotation, folding) and the page would never learn its new width.
            HStack(alignment: .top, spacing: p.gap) {
                VStack(alignment: .leading, spacing: spacing) { leading }
                    .frame(maxWidth: p.leading, alignment: .leading)
                    .environment(\.pageSpread, PageSpread(width: p.leading))
                VStack(alignment: .leading, spacing: spacing) { trailing }
                    .frame(maxWidth: p.trailing, alignment: .leading)
                    .environment(\.pageSpread, PageSpread(width: p.trailing))
            }
        } else {
            VStack(alignment: .leading, spacing: spacing) {
                leading
                trailing
            }
        }
    }
}

private struct TrailingPageInBook: ViewModifier {
    @Environment(\.pageSpread) private var spread
    func body(content: Content) -> some View {
        content.padding(.leading, spread.book.map { $0.leading + $0.gap } ?? 0)
    }
}

/// Reads the page spread inside the view that publishes it.
struct WithPageSpread<Content: View>: View {
    @Environment(\.pageSpread) private var spread
    @ViewBuilder let content: (PageSpread) -> Content
    var body: some View { content(spread) }
}

private struct FoldDivisionReader: ViewModifier {
    let action: (CGRect?) -> Void
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                let fold = FoldDivision.active(in: proxy)
                Color.clear
                    .onAppear { action(fold) }
                    .onChange(of: fold) { _, new in action(new) }
            }
        }
    }
}

extension View {
    /// Reports the active fold division in this view's coordinates (nil when flat or closed).
    func onFoldDivisionChange(_ action: @escaping (CGRect?) -> Void) -> some View {
        modifier(FoldDivisionReader(action: action))
    }
}

extension CGRect {
    /// This fold as a book-pose spine (a vertical division with a real page either side of it).
    func bookSpine(in width: CGFloat) -> CGRect? {
        height > self.width && minX > 200 && width - maxX > 200 ? self : nil
    }
}

extension PageSpread {
    /// A full-screen two-page split for screens with one primary column (sign-in, chats): across
    /// the fold in the book pose, or halves on a landscape window wide enough for two pages.
    static func split(size: CGSize, fold: CGRect?) -> (lead: CGFloat, gap: CGFloat)? {
        if let spine = fold?.bookSpine(in: size.width) { return (spine.minX, spine.width) }
        // Form sheets (about 650 pt on the open Duo) stay one column: splitting them squeezes both halves.
        if size.width >= 760 && size.width > size.height { return (size.width / 2, 0) }
        return nil
    }
}

/// A screen with one main column and a companion panel (a chat and who you're talking to). On a
/// phone only `main` shows, told to draw the companion inline; when there's room for two pages
/// the companion takes the leading page and `main` the trailing one, never crossing the fold.
struct SideBySide<Side: View, Main: View>: View {
    @ViewBuilder var side: Side
    /// Receives true when the side panel is shown on its own page.
    @ViewBuilder var main: (Bool) -> Main
    @State private var size: CGSize = .zero
    @State private var fold: CGRect?

    var body: some View {
        Group {
            if let s = PageSpread.split(size: size, fold: fold) {
                HStack(spacing: s.gap) {
                    side.frame(width: s.lead).frame(maxHeight: .infinity)
                    main(true).frame(maxWidth: .infinity)
                }
            } else {
                main(false)
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onFoldDivisionChange { fold = $0 }
    }
}

extension EnvironmentValues {
    /// True when a `DuoCompanion` shows its companion page, so the screen can drop its own mascot.
    @Entry var duoPaged = false
}

/// Sheets and secondary screens with one column: on a phone just the screen; when there's room for
/// two pages, Erty and what the screen is for on the leading page, the screen itself on the
/// trailing page, so nothing stretches across the fold or turns into a full-width banner.
struct DuoCompanion<Content: View>: View {
    let mood: ErtyMood
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        SideBySide {
            VStack(spacing: 12) {
                ErtyView(mood: mood, size: 150)
                Text(title).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    .padding(.top, 6)
                Text(detail).font(.body).foregroundStyle(Jungle.subtle)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 340).padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } main: { paged in
            content.environment(\.duoPaged, paged)
        }
    }
}

/// A screen's own mascot, hidden when a `DuoCompanion` already shows Erty on the leading page.
struct InlineErty: View {
    let mood: ErtyMood
    var size: CGFloat = 104
    @Environment(\.duoPaged) private var paged
    var body: some View {
        if !paged { ErtyView(mood: mood, size: size).frame(maxWidth: .infinity) }
    }
}
