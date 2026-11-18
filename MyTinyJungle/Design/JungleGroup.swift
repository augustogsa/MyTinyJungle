import SwiftUI

/// Grouped card section used across Me, Settings and planners: rounded title, one card, optional footer.
struct JungleGroup<Content: View>: View {
    var title: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text).padding(.leading, 4) }
            VStack(spacing: 0) { content }
                .padding(.horizontal, 14)
                .background(Jungle.surface, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5))
            if let footer { Text(footer).font(.footnote).foregroundStyle(Jungle.subtle).padding(.horizontal, 4) }
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
                Text(title).font(.body).foregroundStyle(Jungle.text)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true) }
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
