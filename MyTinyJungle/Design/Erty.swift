import SwiftUI
import AVFoundation
import Observation

/// Erty, the app's mascot. Short transparent loops (HEVC with alpha) for greetings, loading,
/// empty states and little celebrations. Falls back to a still frame when Reduce Motion is on.
enum ErtyMood: String, CaseIterable {
    case wave, idle, happy, love, water, plant, scan, notes

    /// The mood that fits a logged care action.
    static func forCare(_ k: CareKind) -> ErtyMood {
        switch k {
        case .water, .mist: .water
        case .repot, .propagate, .prune: .plant
        case .soilCheck, .health, .treat, .measure: .scan
        case .note, .photo: .notes
        default: .love
        }
    }
}

struct ErtyView: View {
    var mood: ErtyMood
    var size: CGFloat = 96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion { Image("erty-\(mood.rawValue)").resizable().scaledToFit() }
            else { ErtyLoop(mood: mood).id(mood) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct ErtyLoop: UIViewRepresentable {
    let mood: ErtyMood
    func makeUIView(context: Context) -> LoopView { LoopView(mood: mood) }
    func updateUIView(_ v: LoopView, context: Context) {}
    static func dismantleUIView(_ v: LoopView, coordinator: ()) { v.stop() }

    final class LoopView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private let still: UIImageView

        init(mood: ErtyMood) {
            still = UIImageView(image: UIImage(named: "erty-\(mood.rawValue)"))
            super.init(frame: .zero)
            backgroundColor = .clear
            still.contentMode = .scaleAspectFit
            still.frame = bounds; still.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(still)
            guard let url = Bundle.main.url(forResource: "erty-\(mood.rawValue)", withExtension: "mov") else { return }
            let q = AVQueuePlayer(); q.isMuted = true; q.preventsDisplaySleepDuringVideoPlayback = false
            q.audiovisualBackgroundPlaybackPolicy = .pauses
            looper = AVPlayerLooper(player: q, templateItem: AVPlayerItem(url: url))
            player = q
            let l = layer as! AVPlayerLayer
            l.player = q; l.videoGravity = .resizeAspect; l.pixelBufferAttributes = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            l.addObserver(self, forKeyPath: "readyForDisplay", options: .new, context: nil)
            q.play()
        }
        required init?(coder: NSCoder) { fatalError() }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            if (layer as? AVPlayerLayer)?.isReadyForDisplay == true { DispatchQueue.main.async { self.still.isHidden = true } }
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil { player?.pause() } else { player?.play() }
        }
        func stop() {
            player?.pause(); looper?.disableLooping()
            if player != nil { layer.removeObserver(self, forKeyPath: "readyForDisplay") }
            player = nil; looper = nil
        }
        deinit { if player != nil { layer.removeObserver(self, forKeyPath: "readyForDisplay") } }
    }
}

/// Erty plus a short line, for waits that take a moment.
struct ErtyLoading: View {
    var text: String
    var mood: ErtyMood = .scan
    var size: CGFloat = 88
    var body: some View {
        VStack(spacing: 6) {
            ErtyView(mood: mood, size: size)
            if !text.isEmpty { Text(text).font(.subheadline.weight(.medium)).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center) }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A quiet empty state led by Erty.
struct ErtyEmpty: View {
    var text: String
    var mood: ErtyMood = .happy
    var body: some View {
        HStack(spacing: 12) {
            ErtyView(mood: mood, size: 64)
            Text(text).font(.subheadline).foregroundStyle(Jungle.subtle).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// Small celebration after care is logged: Erty pops up above the tab bar for a moment.
@Observable @MainActor final class ErtyCheer {
    static let shared = ErtyCheer()
    private(set) var current: (id: UUID, mood: ErtyMood, text: String)?
    func show(_ mood: ErtyMood, _ text: String) {
        let id = UUID(); current = (id, mood, text)
        Task { try? await Task.sleep(for: .seconds(2.6)); if current?.id == id { current = nil } }
    }
}

struct ErtyCheerOverlay: ViewModifier {
    @State private var cheer = ErtyCheer.shared
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let c = cheer.current {
                HStack(spacing: 8) {
                    ErtyView(mood: c.mood, size: 52)
                    Text(c.text).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text).padding(.trailing, 14)
                }
                .padding(4)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .padding(.bottom, 96)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(c.id)
                .accessibilityElement(children: .combine)
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.4), value: cheer.current?.id)
        .sensoryFeedback(.success, trigger: cheer.current?.id) { _, new in new != nil }
    }
}
