import SwiftUI

/// The one empty state: Erty centred and animated, a short title, one line, a primary action, and an optional preview.
struct JungleEmptyState<Preview: View>: View {
    var mood: ErtyMood = .wave
    var title: String
    var message: String
    var actionTitle: String?
    var actionSymbol = "plus"
    var action: (() -> Void)?
    @ViewBuilder var preview: Preview

    var body: some View {
        VStack(spacing: 14) {
            ErtyView(mood: mood, size: 132)
            VStack(spacing: 6) {
                Text(title).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
                    .accessibilityAddTraits(.isHeader)
                Text(message).font(.subheadline).foregroundStyle(Jungle.subtle)
            }
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSymbol).font(.system(.headline, design: .rounded)).frame(maxWidth: 280).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large).tint(Jungle.forest)
                .padding(.top, 4)
            }
            preview
        }
        .padding(.vertical, 26).padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .jungleCard()
    }
}

extension JungleEmptyState where Preview == EmptyView {
    init(mood: ErtyMood = .wave, title: String, message: String, actionTitle: String? = nil, actionSymbol: String = "plus", action: (() -> Void)? = nil) {
        self.init(mood: mood, title: title, message: message, actionTitle: actionTitle, actionSymbol: actionSymbol, action: action) { EmptyView() }
    }
}

/// A faded sample week, so an empty Care tab shows what is coming.
struct SampleWeekPreview: View {
    private var rows: [(CareKind, Int)] { [(.water, 0), (.mist, 2), (.feed, 5)] }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Grammar.pt(String(localized: "Your week will look like this", comment: "Care empty state: caption above a faded sample agenda")))
                .font(.caption.weight(.semibold)).foregroundStyle(Jungle.subtle)
            ForEach(rows, id: \.1) { kind, offset in
                let day = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                HStack(spacing: 12) {
                    Image(systemName: kind.symbol).font(.body.weight(.semibold)).foregroundStyle(Jungle.leaf)
                        .frame(width: 36, height: 36).background(Jungle.fill, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sampleTitle(kind)).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                        Text(day.formatted(.dateTime.weekday(.wide))).font(.caption).foregroundStyle(Jungle.subtle)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "circle").foregroundStyle(Jungle.subtle)
                }
                .padding(10)
                .background(Jungle.fill.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .opacity(0.55)
        .padding(.top, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Grammar.pt(String(localized: "Sample week: water, mist and feed reminders", comment: "VoiceOver: faded sample agenda in Care empty state")))
    }

    private func sampleTitle(_ k: CareKind) -> String {
        switch k {
        case .mist: Grammar.pt(String(localized: "Mist the leaves", comment: "Care empty state sample row; short"))
        case .feed: Grammar.pt(String(localized: "Feed", comment: "Care empty state sample row; short"))
        default: Grammar.pt(String(localized: "Water", comment: "Care empty state sample row; short"))
        }
    }
}
