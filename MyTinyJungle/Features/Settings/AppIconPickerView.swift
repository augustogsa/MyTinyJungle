import SwiftUI
import UIKit

/// One home-screen icon. `id` matches `Assets/Brand/AppIconSources/<id>` and the
/// `AppIcon-<id>` alternate built by `Tools/appicons/build_app_icons.py`.
struct JungleAppIcon: Identifiable, Hashable {
    let id: String
    let title: LocalizedStringResource

    static let mainID = "monstera"

    static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    static let all: [JungleAppIcon] = [
        .init(id: "monstera", title: LocalizedStringResource("Monstera", comment: "App icon name")),
        .init(id: "sprout", title: LocalizedStringResource("Sprout", comment: "App icon name")),
        .init(id: "hug", title: LocalizedStringResource("Big hug", comment: "App icon name")),
        .init(id: "potted", title: LocalizedStringResource("Potted", comment: "App icon name")),
        .init(id: "cherish", title: LocalizedStringResource("Cherish", comment: "App icon name")),
        .init(id: "cactus", title: LocalizedStringResource("Cactus", comment: "App icon name")),
        .init(id: "trailing", title: LocalizedStringResource("Trailing", comment: "App icon name")),
        .init(id: "terrarium", title: LocalizedStringResource("Terrarium", comment: "App icon name")),
        .init(id: "watering", title: LocalizedStringResource("Watering", comment: "App icon name")),
        .init(id: "seedling", title: LocalizedStringResource("Seedling", comment: "App icon name")),
        .init(id: "explorer", title: LocalizedStringResource("Explorer", comment: "App icon name")),
        .init(id: "pruner", title: LocalizedStringResource("Pruning", comment: "App icon name")),
        .init(id: "basket", title: LocalizedStringResource("Basket", comment: "App icon name")),
        .init(id: "journal", title: LocalizedStringResource("Journal", comment: "App icon name")),
    ]

    var alternateName: String? { id == Self.mainID ? nil : "AppIcon-\(id)" }
    var preview: String { "AppIconPreview-\(id)" }

    @MainActor static var current: JungleAppIcon {
        let name = UIApplication.shared.alternateIconName
        return all.first { $0.alternateName == name } ?? all[0]
    }
}

/// App icon sheet: the icons stand on a wooden plant shelf. Swipe along the shelf; the one
/// in the middle grows and shows its name. Tap it to use it; a dot marks the one in use.
struct AppIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inUse = JungleAppIcon.current
    @State private var focused: String? = JungleAppIcon.current.id
    @State private var failed = false

    private let size: CGFloat = 112
    private let spacing: CGFloat = 4

    private var focusedIcon: JungleAppIcon { JungleAppIcon.all.first { $0.id == focused } ?? inUse }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("App icon").font(.title3.weight(.semibold)).fontDesign(.serif).foregroundStyle(Jungle.text)
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(Jungle.text)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel(Text("Close"))
                }
            }
            .padding(.horizontal, 20).padding(.top, 20)

            shelf.padding(.top, 18)

            VStack(spacing: 4) {
                Text(focusedIcon.title).font(.headline).foregroundStyle(Jungle.text)
                    .contentTransition(.opacity)
                Group {
                    if focusedIcon == inUse {
                        Label { Text("In use") } icon: { Image(systemName: "checkmark") }
                            .foregroundStyle(Jungle.accentText)
                    } else {
                        Text("Tap to use").foregroundStyle(Jungle.subtle)
                    }
                }
                .font(.subheadline.weight(.medium))
                .transition(.opacity)
            }
            .padding(.top, 22)
            .animation(.snappy, value: focused)
            .animation(.snappy, value: inUse)

            Spacer(minLength: 0)
        }
        .presentationDetents([.height(400)])
        .presentationCornerRadius(38)
        .presentationBackground(Jungle.cream)
        .sensoryFeedback(.selection, trigger: focused)
        .sensoryFeedback(.success, trigger: inUse)
        .alert("Couldn’t change the icon", isPresented: $failed) { Button("OK", role: .cancel) {} }
    }

    // MARK: The shelf

    private var shelf: some View {
        GeometryReader { geo in
            let side = (geo.size.width - size) / 2
            ZStack(alignment: .bottom) {
                plank.frame(height: 28).offset(y: -20)
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .bottom, spacing: spacing) {
                        ForEach(JungleAppIcon.all) { icon in pot(icon).id(icon.id) }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, side, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $focused, anchor: .center)
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
        .frame(height: 210)
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                     .init(color: .black, location: 0.88), .init(color: .clear, location: 1)],
                             startPoint: .leading, endPoint: .trailing))
    }

    /// Light oak plank seen from the front: a glossy top edge the icons stand on, a front
    /// face and a soft shadow on the wall below.
    private var plank: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(red: 0.93, green: 0.84, blue: 0.70), Color(red: 0.86, green: 0.74, blue: 0.58)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 12)
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.55)).frame(height: 1) }
            LinearGradient(colors: [Color(red: 0.76, green: 0.61, blue: 0.44), Color(red: 0.68, green: 0.53, blue: 0.37)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 10)
            Rectangle().fill(.black.opacity(0.10)).frame(height: 6).blur(radius: 5)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private func pot(_ icon: JungleAppIcon) -> some View {
        Button { tap(icon) } label: {
            VStack(spacing: 0) {
                Image(icon.preview).resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 8, y: 6)
                // Reflection on the glossy top of the plank.
                Image(icon.preview).resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
                    .scaleEffect(y: -1)
                    .frame(height: 30, alignment: .top).clipped()
                    .opacity(0.22)
                    .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                    .accessibilityHidden(true)
                Circle().fill(Jungle.accentText).frame(width: 6, height: 6)
                    .opacity(icon == inUse ? 1 : 0)
                    .padding(.top, 10)
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 2)
        }
        .buttonStyle(.plain)
        .frame(width: size)
        .scrollTransition(.interactive, axis: .horizontal) { [reduceMotion] content, phase in
            content
                .scaleEffect(reduceMotion ? 1 : 1 - 0.32 * min(abs(phase.value), 1), anchor: .bottom)
                .opacity(1 - 0.25 * min(abs(phase.value), 1))
        }
        .accessibilityLabel(Text(icon.title))
        .accessibilityValue(icon == inUse ? Text("In use") : Text(""))
        .accessibilityAddTraits(icon == inUse ? .isSelected : [])
    }

    private func tap(_ icon: JungleAppIcon) {
        guard focused == icon.id else {
            withAnimation(.snappy) { focused = icon.id }
            return
        }
        guard icon != inUse, UIApplication.shared.supportsAlternateIcons else { return }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(icon.alternateName)
                withAnimation(.snappy) { inUse = icon }
            } catch { failed = true }
        }
    }
}
