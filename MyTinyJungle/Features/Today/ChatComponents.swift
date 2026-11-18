import SwiftUI
import PhotosUI

struct MessageBubble: View {
    let message: ChatMessage
    var showAvatar = true
    /// Plant speaking in the jungle thread.
    var speaker: Plant? = nil
    var onSuggestion: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: message.fromUser ? .trailing : .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                if message.fromUser { Spacer(minLength: 48) }
                if !message.fromUser, showAvatar {
                    if let plant = speaker ?? message.plant { PlantAvatar(data: plant.photo, size: 28) }
                    else { Image(systemName: "leaf.circle.fill").font(.system(.title2, design: .rounded)).foregroundStyle(Jungle.leaf).accessibilityHidden(true) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    if let speaker, !message.fromUser {
                        Text(speaker.name).font(.caption.weight(.semibold)).foregroundStyle(Jungle.accentText)
                    }
                    if let data = message.photo, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(maxWidth: 220, maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: Jungle.innerRadius, style: .continuous))
                    }
                    if !message.text.isEmpty {
                        Text(message.text)
                            .font(.body)
                            .foregroundStyle(Jungle.text)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(message.fromUser ? Jungle.userBubble : Jungle.surface,
                            in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
                .overlay { if !message.fromUser { RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous).strokeBorder(Jungle.border, lineWidth: 0.5) } }
                if !message.fromUser { Spacer(minLength: 48) }
            }
            if !message.fromUser, !message.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(message.suggestions, id: \.self) { s in
                            Button(s) { onSuggestion(s) }
                                .buttonStyle(.bordered).fontDesign(.rounded).buttonBorderShape(.capsule).controlSize(.small)
                        }
                    }
                    .padding(.leading, showAvatar ? 36 : 0)
                }
            }
        }
        .accessibilityElement(children: .combine)
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
                        Label { Text(kind == .soilCheck ? "Soil" : kind == .water ? "Water" : kind == .feed ? "Feed" : kind == .mist ? "Mist" : kind == .rotate ? "Rotate" : "New leaf") }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                if !expanded { photoButton }
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .padding(.vertical, 6)
                if !expanded { sendButton }
            }
            if expanded {
                HStack(spacing: 8) {
                    photoButton
                    if showChips {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(QuickChips.kinds, id: \.self) { kind in
                                    Button { onChip(kind); focused = false } label: {
                                        Label { Text(kind.chipTitle) } icon: { Icon3DView(Icon3D.care(kind), size: 18) }
                                            .font(.subheadline.weight(.medium)).foregroundStyle(Jungle.text)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .glassEffect(.regular.interactive(), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .clipShape(Capsule())
                        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.88), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing))
                    } else { Spacer() }
                    sendButton
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, expanded ? 12 : 8)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture { focused = true }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: expanded ? 26 : 28, style: .continuous))
        .padding(.horizontal, 12).padding(.bottom, 6)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: expanded)
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

    private var photoButton: some View {
        PhotosPicker(selection: $pick, matching: .images) {
            Image(systemName: "camera").font(.system(size: 17, weight: .medium)).foregroundStyle(Jungle.text)
                .frame(width: 36, height: 36).glassEffect(.regular.interactive(), in: Circle())
        }
        .accessibilityLabel("Add photo")
    }
    private var sendButton: some View {
        Button(action: send) {
            Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                .frame(width: 36, height: 36)
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
        switch self { case .soilCheck: "Soil"; case .water: "Water"; case .feed: "Feed"; case .mist: "Mist"; case .rotate: "Rotate"; default: "New leaf" }
    }
}
