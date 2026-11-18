import SwiftUI
import PhotosUI

struct MessageBubble: View {
    let message: ChatMessage
    var showAvatar = true
    /// Plant speaking in the jungle thread.
    var speaker: Plant? = nil
    var onSuggestion: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: message.fromUser ? .trailing : .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                if !message.fromUser, showAvatar {
                    if let plant = speaker ?? message.plant { PlantAvatar(data: plant.photo, size: 28) }
                    else { Image(systemName: "leaf.circle.fill").font(.system(.title2, design: .rounded)).foregroundStyle(Jungle.leaf).accessibilityHidden(true) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    if let speaker, !message.fromUser {
                        Text(speaker.name).font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText)
                    }
                    if let data = message.photo, let img = UIImage(data: data) {
                        Color.clear.frame(width: 220, height: 220)
                            .overlay { Image(uiImage: img).resizable().scaledToFill() }
                            .clipShape(RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
                    }
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.body)
                            .foregroundStyle(Jungle.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                .messageBubble(fromMe: message.fromUser)
            }
            .containerRelativeFrame(.horizontal, alignment: message.fromUser ? .trailing : .leading) { w, _ in w * 0.8 }
            .frame(maxWidth: .infinity, alignment: message.fromUser ? .trailing : .leading)
            if !message.fromUser, !message.suggestions.isEmpty {
                SuggestionFlow(items: message.suggestions, onTap: onSuggestion)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Reply suggestions: centered, wrapping, thumb-reachable.
struct SuggestionFlow: View {
    let items: [String]
    var onTap: (String) -> Void
    @State private var shown = false
    var body: some View {
        CenteredFlow(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element) { i, s in
                Button(s) { onTap(s) }
                    .buttonStyle(.bordered).fontDesign(.rounded).buttonBorderShape(.capsule).controlSize(.regular)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 6)
                    .animation(.easeOut(duration: 0.3).delay(0.15 + Double(i) * 0.05), value: shown)
            }
        }
        .onAppear { shown = true }
    }
}

/// Wrapping layout that centers each line.
struct CenteredFlow: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: proposal.width ?? .infinity, subviews)
        let h = rows.map(\.h).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.w).max() ?? 0, height: h)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for r in rows(for: bounds.width, subviews) {
            var x = bounds.midX - r.w / 2
            for i in r.idx {
                let sz = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
                x += sz.width + spacing
            }
            y += r.h + spacing
        }
    }
    private func rows(for width: CGFloat, _ subviews: Subviews) -> [(idx: [Int], w: CGFloat, h: CGFloat)] {
        var out: [(idx: [Int], w: CGFloat, h: CGFloat)] = []
        var cur: [Int] = []; var w: CGFloat = 0; var h: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let sz = v.sizeThatFits(.unspecified)
            let add = cur.isEmpty ? sz.width : w + spacing + sz.width
            if add > width, !cur.isEmpty { out.append((cur, w, h)); cur = [i]; w = sz.width; h = sz.height }
            else { cur.append(i); w = add; h = max(h, sz.height) }
        }
        if !cur.isEmpty { out.append((cur, w, h)) }
        return out
    }
}

/// Text field + photo + send. Chat first: people say what they did.
struct Composer: View {
    let placeholder: String
    var onSend: (String, Data?) -> Void
    @State private var text = ""
    @State private var pick: PhotosPickerItem?
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            PhotosPicker(selection: $pick, matching: .images) {
                Image(systemName: "camera").font(.system(.title3, design: .rounded)).frame(width: 36, height: 36)
            }
            .accessibilityLabel("Add photo")
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Jungle.surface, in: Capsule()).overlay(Capsule().strokeBorder(Jungle.border, lineWidth: 0.5))
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let small = ImageShrinker.jpeg(data)
                    await MainActor.run { onSend(text, small); text = "" ; pick = nil }
                }
            }
        }
    }

    private func send() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onSend(t, nil)
        text = ""
        focused = true
    }
}

enum ImageShrinker {
    static func jpeg(_ data: Data, maxSide: CGFloat = 1600) -> Data {
        guard let img = UIImage(data: data) else { return data }
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let out = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        return out.jpegData(compressionQuality: 0.82) ?? data
    }
}

/// One-tap care shortcuts.
struct QuickChips: View {
    var onTap: (CareKind) -> Void
    static let kinds: [CareKind] = [.water, .soilCheck, .feed, .mist, .rotate, .newLeaf]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.kinds, id: \.self) { kind in
                    Button { onTap(kind) } label: {
                        Label { Text(kind.chipTitle) }
                              icon: { Icon3DView(Icon3D.care(kind), size: 20) }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Jungle.text)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Jungle.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Jungle.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
    }
}

/// Claude-style floating Liquid Glass composer. Minimal pill at rest,
/// expands on focus to show care shortcuts, photo and send.
struct GlassComposer: View {
    let placeholder: String
    var showChips = true
    var onChip: (CareKind) -> Void = { _ in }
    var onSend: (String, Data?) -> Void
    @State private var text = ""
    @State private var pick: PhotosPickerItem?
    @FocusState private var focused: Bool
    private var expanded: Bool { focused || !text.isEmpty }
    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 6) {
            if expanded && showChips {
                ViewThatFits(in: .horizontal) {
                    chipRow.frame(maxWidth: .infinity)
                    ScrollView(.horizontal, showsIndicators: false) { chipRow.padding(.horizontal, 4) }
                }
                .transition(.opacity)
            }
            HStack(alignment: .bottom, spacing: 8) {
                photoButton
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.horizontal, 4).padding(.vertical, 10)
                    .frame(minHeight: 40)
                sendButton
            }
        }
        .padding(6)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture { focused = true }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 21).padding(.bottom, 6) // same inset as the floating tab bar
        .animation(.easeOut(duration: 0.2), value: expanded)
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let small = ImageShrinker.jpeg(data)
                    await MainActor.run { onSend(text, small); text = ""; pick = nil }
                }
            }
        }
    }

    private var chipRow: some View {
        HStack(spacing: 6) {
            ForEach(QuickChips.kinds, id: \.self) { kind in
                Button { onChip(kind); focused = false } label: {
                    Label { Text(kind.chipTitle) } icon: { Icon3DView(Icon3D.care(kind), size: 18) }
                        .font(.subheadline.weight(.medium)).foregroundStyle(Jungle.text)
                        .fixedSize()
                        .padding(.horizontal, 12).frame(height: 36)
                        .background(Jungle.text.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
    private var photoButton: some View {
        PhotosPicker(selection: $pick, matching: .images) {
            Image(systemName: "camera").font(.system(size: 17, weight: .medium)).foregroundStyle(Jungle.text)
                .frame(width: 40, height: 40).background(Jungle.text.opacity(0.06), in: Circle())
        }
        .accessibilityLabel("Add photo")
    }
    private var sendButton: some View {
        Button(action: send) {
            Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(Jungle.surface)
                .frame(width: 40, height: 40)
                .background(canSend ? Jungle.forest : Jungle.subtle.opacity(0.4), in: Circle())
        }
        .disabled(!canSend)
        .accessibilityLabel("Send")
    }
    private func send() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onSend(t, nil); text = ""
    }
}

extension CareKind {
    var chipTitle: String {
        switch self { case .soilCheck: String(localized: "Soil", comment: "Chat quick chip: log soil check; max 12 chars"); case .water: String(localized: "Water", comment: "Chat quick chip: log watering; max 12 chars"); case .feed: String(localized: "Feed", comment: "Chat quick chip: log fertilizing; max 12 chars"); case .mist: String(localized: "Mist", comment: "Chat quick chip: log misting; max 12 chars"); case .rotate: String(localized: "Rotate", comment: "Chat quick chip: log rotating pot; max 12 chars"); default: String(localized: "New leaf", comment: "Chat quick chip: log new leaf; max 12 chars") }
    }
}
