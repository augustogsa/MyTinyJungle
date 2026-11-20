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
            if reduceMotion { ContentImage("erty/\(mood.rawValue).png", fallback: "erty-\(mood.rawValue)", side: size).scaledToFit() }
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

    /// The player exists only while Erty is on screen in a foreground app; hidden or backgrounded, it is released
    /// and the still frame shows. After a few loops it settles on a frame so an idle screen uses no power.
    final class LoopView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private(set) var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private let still: UIImageView
        private let url: URL?
        private var observing = false
        private var wanted = false
        private var rest: DispatchWorkItem?
        private var inBackground = UIApplication.shared.applicationState == .background

        init(mood: ErtyMood) {
            still = UIImageView(image: MainActor.assumeIsolated { ContentStore.shared.image("erty/\(mood.rawValue).png") } ?? UIImage(named: "erty-\(mood.rawValue)"))
            // Loops come from the server; the copies bundled with the app cover the first launch and offline.
            url = ContentFiles.url("erty/\(mood.rawValue).mov") ?? Bundle.main.url(forResource: mood.rawValue, withExtension: "mov")
            super.init(frame: .zero)
            backgroundColor = .clear
            still.contentMode = .scaleAspectFit
            still.frame = bounds; still.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(still)
            (layer as! AVPlayerLayer).videoGravity = .resizeAspect
            let nc = NotificationCenter.default
            nc.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
            nc.addObserver(self, selector: #selector(foreground), name: UIApplication.willEnterForegroundNotification, object: nil)
        }
        required init?(coder: NSCoder) { fatalError() }

        @objc private func background() { inBackground = true; update() }
        @objc private func foreground() { inBackground = false; update() }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            if (layer as? AVPlayerLayer)?.isReadyForDisplay == true { DispatchQueue.main.async { self.still.isHidden = self.player == nil } }
        }

        func setPlaying(_ on: Bool) {
            wanted = on
            update()
        }

        private var onScreen: Bool { wanted && window != nil && !inBackground }

        private func update() {
            rest?.cancel()
            guard onScreen else { release(); return }
            if player == nil { build() }
            guard let player else { return }
            player.play()
            revealWhenReady()
            let w = DispatchWorkItem { [weak self] in self?.player?.pause() }
            rest = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 9, execute: w)
        }

        private func build() {
            guard let url else { return }
            let q = AVQueuePlayer(); q.isMuted = true; q.preventsDisplaySleepDuringVideoPlayback = false
            q.audiovisualBackgroundPlaybackPolicy = .pauses
            looper = AVPlayerLooper(player: q, templateItem: AVPlayerItem(url: url))
            player = q
            let l = layer as! AVPlayerLayer
            l.player = q
            if !observing { l.addObserver(self, forKeyPath: "readyForDisplay", options: .new, context: nil); observing = true }
        }

        /// Hides the still as soon as the video has a frame on screen. KVO on readyForDisplay alone misses the change
        /// when it flips before the observer is attached or while the view is off-window, so this also polls briefly.
        private var revealTask: Task<Void, Never>?
        private func revealWhenReady() {
            revealTask?.cancel()
            revealTask = Task { @MainActor [weak self] in
                for _ in 0..<60 {
                    guard let self, !Task.isCancelled, self.player != nil else { return }
                    if (self.layer as? AVPlayerLayer)?.isReadyForDisplay == true, (self.player?.currentTime().seconds ?? 0) > 0 {
                        self.still.isHidden = true; return
                    }
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
        }

        /// Drops the player and its decoder; the still frame covers the gap.
        private func release() {
            rest?.cancel()
            guard player != nil else { return }
            revealTask?.cancel()
            player?.pause(); looper?.disableLooping()
            (layer as? AVPlayerLayer)?.player = nil
            player = nil; looper = nil
            still.isHidden = false
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            update()
        }

        func stop() {
            wanted = false
            release()
            NotificationCenter.default.removeObserver(self)
            if observing { layer.removeObserver(self, forKeyPath: "readyForDisplay"); observing = false }
        }
        deinit { if observing { layer.removeObserver(self, forKeyPath: "readyForDisplay") } }
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
        VStack(spacing: 8) {
            ErtyView(mood: mood, size: 88)
            Text(text).font(.subheadline).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .accessibilityElement(children: .combine)
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

/// First thing on screen at launch. Same art, size and position as the launch screen's LaunchMark
/// (erty-wave, 168 pt, screen centre), so the system launch image hands over without a jump.
struct LaunchSplash: View {
    @State private var showText = false
    var body: some View {
        ZStack {
            Color("LaunchBackground")
            Image("erty-wave").resizable().interpolation(.high).frame(width: 168, height: 168)
                .accessibilityHidden(true)
            Text("Waking up your jungle…", comment: "Launch splash under Erty; max 30 chars")
                .font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.subtle)
                .offset(y: 84 + 28)
                .opacity(showText ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear { LaunchClock.mark("firstFrame") }
        .task { try? await Task.sleep(for: .milliseconds(350)); withAnimation(.easeIn(duration: 0.3)) { showText = true } }
    }
}
