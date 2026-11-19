import SwiftUI

/// Grouped card section used across Me, Settings and planners: rounded title, one card, optional footer.
struct JungleGroup<Content: View>: View {
    var title: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Text(title.uiLocalized).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text).padding(.leading, 4) }
            VStack(spacing: 0) { content }
                .padding(.horizontal, 14)
                .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5))
            if let footer { Text(footer.uiLocalized).font(.footnote).foregroundStyle(Jungle.subtle).padding(.horizontal, 4) }
        }
    }
}

/// Row with a 3D icon, title, optional subtitle and trailing content.
struct JungleRow<Trailing: View>: View {
    let icon: Icon3D
    let title: String
    var subtitle: String? = nil
    var chevron = false
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 12) {
            Icon3DView(icon, size: 30).frame(width: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uiLocalized).font(.body).foregroundStyle(Jungle.text)
                if let subtitle { Text(subtitle.uiLocalized).font(.caption).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 8)
            trailing
            if chevron { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Jungle.subtle.opacity(0.7)) }
        }
        .padding(.vertical, 11).frame(minHeight: 52).contentShape(Rectangle())
    }
}
extension JungleRow where Trailing == EmptyView {
    init(icon: Icon3D, title: String, subtitle: String? = nil, chevron: Bool = false) {
        self.init(icon: icon, title: title, subtitle: subtitle, chevron: chevron) { EmptyView() }
    }
}

struct JungleDivider: View { var body: some View { Divider().padding(.leading, 46) } }

/// One header for every tab: rounded title, a status line, glass circle actions.
struct TabHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var dot: Color? = nil
    @ViewBuilder var trailing: Trailing
    /// Top safe area at the header. Near zero in landscape and on the open Duo, where the title
    /// would otherwise sit right in the display's rounded corner.
    @State private var topInset: CGFloat = 60

    private var cornerClear: Bool { topInset < 20 }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uiLocalized).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
                if let subtitle {
                    HStack(spacing: 6) {
                        if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
                        Text(subtitle.uiLocalized).font(.subheadline).foregroundStyle(Jungle.subtle)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .padding(.leading, cornerClear ? 10 : 0)
            Spacer(minLength: 0)
            trailing
        }
        .padding(.top, cornerClear ? 26 : 8)
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { topInset = $0 }
    }
}

/// 44pt glass circle button used in tab headers.
struct HeaderButton: View {
    let symbol: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .medium)).foregroundStyle(Jungle.text).frame(width: 44, height: 44)
                .glassEffect(.regular, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
