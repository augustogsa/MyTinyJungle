import SwiftUI
import AVFoundation
import Observation

/// Erty, the app's mascot. Short transparent loops (HEVC with alpha) for greetings, loading,
/// empty states and little celebrations. Falls back to a still frame when Reduce Motion is on.
enum ErtyMood: String, CaseIterable {
    case wave, idle, happy, love, water, plant, scan, notes, rain, sleep, soil, learn, award, celebrate, soilbag, mist

    /// The mood that fits a logged care action.
    static func forCare(_ k: CareKind) -> ErtyMood {
        switch k {
        case .water: .water
        case .mist: .mist
        case .feed: .soilbag
        case .repot: .soil
        case .newLeaf, .flower: .celebrate
        case .propagate, .prune: .plant
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
    @State private var visible = false

    var body: some View {
        Group {
            if reduceMotion { ContentImage("erty/\(mood.rawValue).png", fallback: "erty-\(mood.rawValue)").scaledToFit() }
            else { ErtyLoop(mood: mood, playing: visible).id(mood) }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct ErtyLoop: UIViewRepresentable {
    let mood: ErtyMood
    var playing: Bool
    func makeUIView(context: Context) -> LoopView { LoopView(mood: mood) }
    func updateUIView(_ v: LoopView, context: Context) { v.setPlaying(playing) }
    static func dismantleUIView(_ v: LoopView, coordinator: ()) { v.stop() }

    final class LoopView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private let still: UIImageView

        init(mood: ErtyMood) {
            still = UIImageView(image: MainActor.assumeIsolated { ContentStore.shared.image("erty/\(mood.rawValue).png") } ?? UIImage(named: "erty-\(mood.rawValue)"))
            super.init(frame: .zero)
            backgroundColor = .clear
            still.contentMode = .scaleAspectFit
            still.frame = bounds; still.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(still)
            // Loops come from the server; the copies bundled with the app cover the first launch and offline.
            guard let url = ContentFiles.url("erty/\(mood.rawValue).mov") ?? Bundle.main.url(forResource: mood.rawValue, withExtension: "mov") else { return }
            let q = AVQueuePlayer(); q.isMuted = true; q.preventsDisplaySleepDuringVideoPlayback = false
            q.audiovisualBackgroundPlaybackPolicy = .pauses
            looper = AVPlayerLooper(player: q, templateItem: AVPlayerItem(url: url))
            player = q
            let l = layer as! AVPlayerLayer
            l.player = q; l.videoGravity = .resizeAspect
            l.addObserver(self, forKeyPath: "readyForDisplay", options: .new, context: nil)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            if (layer as? AVPlayerLayer)?.isReadyForDisplay == true { DispatchQueue.main.async { self.still.isHidden = true } }
        }
        private var wanted = false
        private var rest: DispatchWorkItem?
        /// Plays only while on screen, and settles on a frame after a few loops so an idle screen uses no power.
        func setPlaying(_ on: Bool) {
            wanted = on
            update()
        }
        private func update() {
            rest?.cancel()
            guard let player else { return }
            if wanted && window != nil {
                player.play()
                let w = DispatchWorkItem { [weak self] in self?.player?.pause() }
                rest = w
                DispatchQueue.main.asyncAfter(deadline: .now() + 9, execute: w)
            } else {
                player.pause()
            }
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            update()
        }
        func stop() {
            rest?.cancel()
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

/// First thing on screen at launch: the launch mark, then Erty waving while the jungle opens.
struct LaunchSplash: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            ErtyView(mood: .wave, size: 168)
            Text("Waking up your jungle…", comment: "Launch splash under Erty; max 30 chars")
                .font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.subtle)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("LaunchBackground").ignoresSafeArea())
    }
}
