import SwiftUI
import SwiftData
import PhotosUI
import Vision
import VisionKit
import AVFoundation

/// Scan: a full-bleed live camera. Pick a mode, frame it, tap the shutter, and the answer slides up.
struct ScanView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case identify, doctor, label, shelf
        var id: String { rawValue }
        var title: String {
            switch self {
            case .identify: Grammar.pt(String(localized: "Identify", comment: "Scan mode chip: identify a plant; max 12 chars"))
            case .doctor: Grammar.pt(String(localized: "Doctor", comment: "Scan mode chip: diagnose a sick plant; max 12 chars"))
            case .label: Grammar.pt(String(localized: "Label", comment: "Scan mode chip: read a soil or fertiliser label; max 12 chars"))
            case .shelf: Grammar.pt(String(localized: "Shelf", comment: "Scan mode chip: add many plants from one photo; max 12 chars"))
            }
        }
        var symbol: String {
            switch self { case .identify: "leaf.fill"; case .doctor: "stethoscope"; case .label: "text.viewfinder"; case .shelf: "square.grid.3x2.fill" }
        }
        var icon: Icon3D {
            switch self { case .identify: .pottedPlant; case .doctor: .wilted; case .label: .leafTag; case .shelf: .shelf }
        }
        var hint: String {
            switch self {
            case .identify: Grammar.pt(String(localized: "Point me at a leaf!", comment: "Erty speech bubble in Scan, identify mode; playful; max 32 chars"))
            case .doctor: Grammar.pt(String(localized: "Show me the poorly leaves", comment: "Erty speech bubble in Scan, plant doctor mode; playful; max 32 chars"))
            case .label: Grammar.pt(String(localized: "Flip the bag, I'll read it!", comment: "Erty speech bubble in Scan, label mode; playful; max 32 chars"))
            case .shelf: Grammar.pt(String(localized: "Step back, get everyone in!", comment: "Erty speech bubble in Scan, shelf mode; playful; max 32 chars"))
            }
        }
        var shutterLabel: String {
            switch self {
            case .identify: Grammar.pt(String(localized: "Identify this plant", comment: "VoiceOver: scan shutter in identify mode"))
            case .doctor: Grammar.pt(String(localized: "Check this plant's health", comment: "VoiceOver: scan shutter in plant doctor mode"))
            case .label: Grammar.pt(String(localized: "Read this label", comment: "VoiceOver: scan shutter in label mode"))
            case .shelf: Grammar.pt(String(localized: "Find every plant in this photo", comment: "VoiceOver: scan shutter in shelf mode"))
            }
        }
        /// Reticle size as a share of the screen width, and its aspect.
        var frame: (width: CGFloat, aspect: CGFloat) {
            switch self { case .identify, .doctor: (0.74, 1.25); case .label: (0.84, 0.7); case .shelf: (0.9, 0.85) }
        }
        /// Identify and Doctor take several photos; Label and Shelf answer from one.
        var purpose: ScanPurpose? {
            switch self { case .identify: .identify; case .doctor: .doctor; default: nil }
        }
    }

    enum Result: Identifiable {
        case identify([ScanShot]), doctor(Plant, [ScanShot]), shelf(Data), product(AnalyzedProduct), typing, products
        var id: String {
            switch self {
            case .identify: "identify"; case .doctor(let p, _): "doctor-\(p.id)"; case .shelf: "shelf"
            case .product(let p): "product-\(p.name)\(p.barcode ?? "")"; case .typing: "typing"; case .products: "products"
            }
        }
    }

    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var phase
    @Query(filter: #Predicate<Plant> { !$0.isArchived }, sort: \Plant.name) private var plants: [Plant]
    @AppStorage("selectedTab") private var selectedTab = 3
    @AppStorage("scanMode") private var modeRaw = Mode.identify.rawValue
    @State private var camera = ScanCamera()
    @State private var visible = false
    @State private var result: Result?
    @State private var paywall: PlusFeature?
    @State private var doctorPlantID: UUID?
    @State private var picks: [PhotosPickerItem] = []
    @State private var tray = ScanTray()
    /// A kind a result tip asked for: the sheet closes and the camera comes back on it.
    @State private var pendingKind: ShotKind?
    @State private var howTo = false
    @AppStorage("scanHowToSeen") private var howToSeen = false
    @State private var working = false
    @State private var toast: String?
    @State private var cheer = false
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var ertyMood: ErtyMood { working ? .scan : cheer ? .happy : .wave }

    private var mode: Mode { Mode(rawValue: modeRaw) ?? .identify }
    private var doctorPlant: Plant? { plants.first { $0.id == doctorPlantID } ?? plants.first }
    private var multi: Bool { mode.purpose != nil }
    private var canShoot: Bool { !working && !(mode == .doctor && plants.isEmpty) && !(multi && tray.isFull) }
    private var showTray: Bool { multi && !tray.isEmpty }

    var body: some View {
        ZStack {
            Color.clear.jungleBackdrop()
            cameraLayer
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 12)
                ertyPeek
                modeExtras
                if showTray {
                    ScanTrayView(tray: tray) { Task { await check() } }
                        .padding(.top, 10)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                } else {
                    chips.padding(.top, 14)
                }
                bottomBar.padding(.top, 14).padding(.bottom, 10)
            }
            .padding(.horizontal, 16)
            if working {
                ErtyLoading(text: mode == .label ? Grammar.pt(String(localized: "Reading the label…", comment: "Scan: reading a label photo")) : Grammar.pt(String(localized: "Getting the photo ready…", comment: "Scan: preparing a captured photo")), mood: .scan, size: 110)
                    .padding(24).background(Jungle.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
                    .transition(.opacity)
            }
            if let toast {
                VStack {
                    Text(toast).font(.subheadline.weight(.medium)).foregroundStyle(Jungle.text).multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.vertical, 10).background(Jungle.surface, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                        .padding(.top, 70)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.snappy, value: mode)
        .animation(reduceMotion ? nil : .snappy, value: showTray)
        .animation(.easeInOut(duration: 0.2), value: working)
        .animation(.snappy, value: toast)
        .task { await camera.prepare() }
        .task { await camera.watchLight() }
        .onChange(of: camera.lowLight) { _, on in
            if on { show(Grammar.pt(String(localized: "Low light, so I turned the flash on", comment: "Scan: torch switched on automatically in the dark; max 40 chars"))) }
        }
        .onAppear { visible = true; if !reduceMotion { withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { breathe = true } } }
        .onDisappear { visible = false; camera.setTorch(false) }
        .onChange(of: mode, initial: true) { _, m in
            camera.labelMode = m == .label; camera.resetText()
            if let p = m.purpose { tray.purpose = p; if !howToSeen && !DemoSeeder.wantsScan { howToSeen = true; howTo = true } }
        }
        .onChange(of: phase) { _, p in if p != .active { camera.setTorch(false) } }
        .onChange(of: picks) { _, items in
            guard !items.isEmpty else { return }
            working = true
            Task {
                var got: [Data] = []
                for item in items { if let d = try? await item.loadTransferable(type: Data.self) { got.append(d) } }
                picks = []
                guard let first = got.first else { working = false; return }
                if multi {
                    for d in got { tray.add(d) }
                    working = false
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } else { await route(first, liveText: "") }
            }
        }
        #if DEBUG
        // QA: `-scanTrayDemo /path/to/folder` fills the tray from that folder's JPEGs (simulators have no camera).
        .task {
            guard let dir = UserDefaults.standard.string(forKey: "scanTrayDemo"), tray.isEmpty,
                  let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
            for f in files.sorted() where f.hasSuffix(".jpg") { if let d = FileManager.default.contents(atPath: dir + "/" + f) { tray.add(d) } }
        }
        #endif
        .task { if DemoSeeder.wantsScan, result == nil { try? await Task.sleep(for: .seconds(1)); modeRaw = Mode.label.rawValue; result = .product(ProductAnalyzer.analyze(text: DemoSeeder.sampleLabel)) } }
        .sheet(item: $result, onDismiss: {
            if let k = pendingKind { tray.wanted = k; pendingKind = nil; announce(k.hint) } else { tray.clear() }
        }) { r in sheet(r) }
        .sheet(isPresented: $howTo) { HowToScanSheet() }
        .sheet(item: $paywall) { PaywallView(reason: $0) }
    }

    // MARK: Camera

    @ViewBuilder private var cameraLayer: some View {
        switch camera.state {
        case .checking: ProgressView().tint(Jungle.leaf)
        case .ready:
            ScanCameraView(camera: camera, running: visible && result == nil && paywall == nil && phase == .active)
                .ignoresSafeArea()
                .accessibilityLabel(Grammar.pt(String(localized: "Camera preview", comment: "VoiceOver: live camera in Scan")))
        case .denied where showTray, .unavailable where showTray: Color.clear
        case .denied:
            noCamera(title: Grammar.pt(String(localized: "Camera access is off", comment: "Scan: camera permission denied title; max 30 chars")),
                     message: Grammar.pt(String(localized: "Turn it on in Settings to scan live, or pick a photo.", comment: "Scan: camera permission denied line")), settings: true)
        case .unavailable:
            noCamera(title: Grammar.pt(String(localized: "No camera here", comment: "Scan: camera unavailable (simulator, restricted) title; max 30 chars")),
                     message: Grammar.pt(String(localized: "Pick a photo and I'll read it just the same.", comment: "Scan: camera unavailable line")), settings: false)
        }
    }

    private func noCamera(title: String, message: String, settings: Bool) -> some View {
        VStack(spacing: 14) {
            Icon3DView(.leafTag, size: 72)
            VStack(spacing: 6) {
                Text(title).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text).accessibilityAddTraits(.isHeader)
                Text(message).font(.subheadline).foregroundStyle(Jungle.subtle)
            }
            .multilineTextAlignment(.center)
            PhotosPicker(selection: $picks, maxSelectionCount: multi ? max(1, tray.room) : 1, selectionBehavior: .ordered, matching: .images) {
                Label(Grammar.pt(String(localized: "Choose a photo", comment: "Scan: button to pick a photo instead of the camera; max 22 chars")), systemImage: "photo.on.rectangle")
                    .font(.system(.headline, design: .rounded)).frame(maxWidth: 260).padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large).junglePrimary()
            if settings, let url = URL(string: UIApplication.openSettingsURLString) {
                Button(Grammar.pt(String(localized: "Open Settings", comment: "Button: open iOS Settings to allow the camera; max 20 chars"))) { UIApplication.shared.open(url) }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.accentText)
            }
        }
        .padding(.vertical, 26).padding(.horizontal, 20).jungleCard()
        .padding(.horizontal, 28)
        .padding(.bottom, 120)
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack(spacing: 10) {
            circleButton("xmark", Grammar.pt(String(localized: "Close scanner", comment: "VoiceOver: close the Scan camera"))) { selectedTab = 0 }
            Spacer()
            if multi {
                circleButton("questionmark", Grammar.pt(String(localized: "How to scan", comment: "How to scan card title; max 24 chars"))) { howTo = true }
            }
            if camera.state == .ready && camera.hasTorch {
                circleButton(camera.torch ? "bolt.fill" : "bolt.slash.fill", camera.torch ? Grammar.pt(String(localized: "Turn flash off", comment: "VoiceOver: scan torch toggle when on")) : Grammar.pt(String(localized: "Turn flash on", comment: "VoiceOver: scan torch toggle when off")), tint: camera.torch ? Jungle.terracotta : Jungle.forest) { camera.userSetTorch = true; camera.lowLight = false; camera.setTorch(!camera.torch) }
            } else {
                circleButton("tray.full.fill", Grammar.pt(String(localized: "My products", comment: "Scan: soils and foods you own and your shopping list; max 20 chars"))) { result = .products }
            }
        }
        .padding(.top, 8)
    }

    private func circleButton(_ symbol: String, _ label: String, tint: Color = Jungle.forest, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 44, height: 44).warmGlass(Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(label)
    }

    @ViewBuilder private var modeExtras: some View {
        switch mode {
        case .label:
            VStack(spacing: 8) {
                if camera.state == .ready && !camera.lines.isEmpty {
                    Label(Grammar.pt(String(localized: "Reading: \(camera.lines.count) lines", comment: "Scan label mode: how many text lines the live camera has read")), systemImage: "text.viewfinder")
                        .font(.caption.weight(.semibold)).foregroundStyle(Jungle.onForest)
                        .padding(.horizontal, 12).padding(.vertical, 6).background(Jungle.forest, in: Capsule())
                        .contentTransition(.numericText())
                }
                Button { result = .typing } label: {
                    Text(Grammar.pt(String(localized: "Type it instead", comment: "Scan label mode: small link to type the label by hand; max 24 chars")))
                        .font(.footnote.weight(.semibold)).underline().foregroundStyle(Jungle.accentText)
                        .padding(.vertical, 6).padding(.horizontal, 12).warmGlass(Capsule())
                }
            }
        case .doctor:
            if plants.isEmpty {
                Button { modeRaw = Mode.identify.rawValue } label: {
                    Label(Grammar.pt(String(localized: "Add a plant first, then I can check it", comment: "Scan doctor mode with no plants; max 40 chars")), systemImage: "plus.circle.fill")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Jungle.accentText)
                        .padding(.horizontal, 14).padding(.vertical, 9).warmGlass(Capsule())
                }
            } else {
                Menu {
                    Picker(Grammar.pt(String(localized: "Which plant?", comment: "Scan doctor mode: pick the plant being checked")), selection: Binding(get: { doctorPlant?.id }, set: { doctorPlantID = $0 })) {
                        ForEach(plants) { Text($0.name).tag(Optional($0.id)) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        PlantAvatar(data: doctorPlant?.photo, size: 26)
                        Text(Grammar.pt(String(localized: "Checking \(doctorPlant?.name ?? "")", comment: "Scan doctor mode chip; arg plant name; max 28 chars"))).font(.footnote.weight(.semibold)).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(Jungle.text)
                    .padding(.leading, 5).padding(.trailing, 12).padding(.vertical, 5).warmGlass(Capsule())
                }
                .accessibilityHint(Grammar.pt(String(localized: "Choose which plant to check", comment: "VoiceOver hint on Scan doctor plant chip")))
            }
        default: EmptyView()
        }
    }

    private var chips: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases) { m in
                Button { modeRaw = m.rawValue; UISelectionFeedbackGenerator().selectionChanged() } label: {
                    VStack(spacing: 3) {
                        Icon3DView(m.icon, size: 28)
                        Text(m.title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                            .foregroundStyle(m == mode ? Jungle.onChipSelected : Jungle.text)
                    }
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background { if m == mode { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Jungle.chipSelected) } }
                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(m.title)
                .accessibilityAddTraits(m == mode ? .isSelected : [])
            }
        }
        .padding(5)
        .warmGlass(RoundedRectangle(cornerRadius: 23, style: .continuous))
    }

    /// Erty peeks in from the corner with a hint, thinks while a photo is read, and cheers at the answer.
    private var ertyPeek: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ErtyView(mood: ertyMood, size: 76).id(ertyMood)
                .offset(x: -6)
            Text(working ? Grammar.pt(String(localized: "Hmm, let me think…", comment: "Erty speech bubble in Scan while a photo is analysed; max 32 chars")) : cheer ? Grammar.pt(String(localized: "Got it!", comment: "Erty speech bubble in Scan when a result is ready; max 20 chars")) : bubble)
                .font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Jungle.surface, in: BubbleShape(fromMe: false))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                .padding(.bottom, 30)
                .id(mode.rawValue + "\(working)\(cheer)" + bubble)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
            Spacer(minLength: 0)
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: mode)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: working)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: cheer)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: bubble)
        .accessibilityElement(children: .combine)
    }

    /// Mode hint before the first shot; then Erty asks for the next useful angle.
    private var bubble: String {
        guard showTray else { return mode.hint }
        if tray.isFull { return Grammar.pt(String(localized: "That's plenty! Tap Check", comment: "Erty bubble in Scan when 8 photos are in; max 32 chars")) }
        return tray.next.hint
    }

    private var bottomBar: some View {
        HStack {
            PhotosPicker(selection: $picks, maxSelectionCount: multi ? max(1, tray.room) : 1, selectionBehavior: .ordered, matching: .images) {
                Image(systemName: "photo.on.rectangle").font(.system(size: 20, weight: .semibold)).foregroundStyle(Jungle.forest)
                    .frame(width: 52, height: 52).warmGlass(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(multi && tray.isFull)
            .accessibilityLabel(Grammar.pt(String(localized: "Choose from Photos", comment: "VoiceOver: Scan photo library button")))
            Spacer()
            Button { Task { await shoot() } } label: {
                ZStack {
                    Circle().fill(Jungle.cream).frame(width: 82, height: 82).shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                    Circle().strokeBorder(Jungle.leaf, lineWidth: 4).frame(width: 82, height: 82)
                    Circle().fill(Jungle.forest).frame(width: 64, height: 64)
                    Image(systemName: "leaf.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(Jungle.onForest)
                        .rotationEffect(.degrees(-20))
                }
            }
            .buttonStyle(ShutterStyle())
            .disabled(!canShoot || camera.state != .ready)
            .opacity(canShoot && camera.state == .ready ? 1 : 0.4)
            .accessibilityLabel(showTray ? Grammar.pt(String(localized: "Take a photo: \(tray.next.title)", comment: "VoiceOver: scan result tip opening the camera; arg kind")) : mode.shutterLabel)
            Spacer()
            if camera.state == .ready && camera.hasTorch {
                Button { result = .products } label: {
                    Image(systemName: "tray.full.fill").font(.system(size: 20, weight: .semibold)).foregroundStyle(Jungle.forest)
                        .frame(width: 52, height: 52).warmGlass(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel(Grammar.pt(String(localized: "My products", comment: "Scan: soils and foods you own and your shopping list; max 20 chars")))
            } else {
                Color.clear.frame(width: 52, height: 52)
            }
        }
    }

    // MARK: Logic

    private func shoot() async {
        working = true
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        guard let data = await camera.capture() else {
            working = false
            show(Grammar.pt(String(localized: "Couldn't take the photo. Try again.", comment: "Scan: camera capture failed")))
            return
        }
        if multi {
            working = false
            if let s = tray.add(data) {
                announce(Grammar.pt(String(localized: "Added: \(s.kind.title). \(tray.isFull ? "" : tray.next.hint)", comment: "VoiceOver after a scan photo is added; args kind and Erty's next hint")))
            }
            return
        }
        await route(data, liveText: mode == .label ? camera.lines.joined(separator: "\n") : "")
    }

    /// Sends every tray photo to Identify or Doctor.
    private func check() async {
        guard !tray.isEmpty else { return }
        let shots = tray.shots
        celebrate {
            switch mode {
            case .identify:
                guard Store.shared.canAddPlant(current: plants.count) else { paywall = .morePlants; return }
                result = .identify(shots)
            case .doctor:
                guard let p = doctorPlant else { modeRaw = Mode.identify.rawValue; return }
                result = .doctor(p, shots)
            default: break
            }
        }
    }

    private func celebrate(_ open: () -> Void) {
        open()
        guard result != nil else { return }
        cheer = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task { try? await Task.sleep(for: .seconds(2.5)); cheer = false }
    }

    private func announce(_ t: String) { UIAccessibility.post(notification: .announcement, argument: t) }

    private func morePhoto(_ k: ShotKind) { pendingKind = k; result = nil }

    /// Sends a photo to the right brain call for the current mode; the answer opens as a sheet.
    private func route(_ data: Data, liveText: String) async {
        defer {
            working = false
            if result != nil {
                cheer = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                Task { try? await Task.sleep(for: .seconds(2.5)); cheer = false }
            }
        }
        switch mode {
        case .identify, .doctor:
            tray.add(data)
        case .shelf:
            result = .shelf(data)
        case .label:
            let ocr = await Task.detached(priority: .userInitiated) { () -> String in
                guard let img = UIImage(data: data) else { return "" }
                return await OCR.recognize(img)
            }.value
            let text = [liveText, ocr].filter { !$0.isEmpty }.joined(separator: "\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || camera.barcode != nil else {
                show(Grammar.pt(String(localized: "I couldn't read any words. Get closer, or type it instead.", comment: "Scan label mode: no text found")))
                return
            }
            result = .product(ProductAnalyzer.analyze(text: text, barcode: camera.barcode))
            camera.resetText()
        }
    }

    private func show(_ t: String) {
        toast = t
        UIAccessibility.post(notification: .announcement, argument: t)
        Task { try? await Task.sleep(for: .seconds(2.8)); if toast == t { toast = nil } }
    }

    @ViewBuilder private func sheet(_ r: Result) -> some View {
        Group {
            switch r {
            case .identify(let s): AddPlantFlow(initialShots: s, onMorePhoto: morePhoto)
            case .doctor(let p, let s): HealthCheckView(plant: p, initialShots: s, onMorePhoto: morePhoto)
            case .shelf(let d): ShelfImportView(initialPhoto: d) { result = nil }
            case .typing: TypeLabelSheet { text in
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { result = .product(ProductAnalyzer.analyze(text: t)) }
            }
            case .products: ProductShelfSheet(plants: plants)
            case .product(let p):
                ProductResultView(product: p, plants: plants, onLocked: { f in result = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { paywall = f } }) { save(p, list: $0) }
                    .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
        }
    }

    private func save(_ p: AnalyzedProduct, list: Bool) {
        let o = OwnedProduct(name: p.name, category: p.category.rawValue)
        o.barcode = p.barcode
        o.npkN = p.npk?.n; o.npkP = p.npk?.p; o.npkK = p.npk?.k
        o.ingredients = p.ingredients
        o.onShoppingList = list
        ctx.insert(o)
        try? ctx.save()
        result = nil
        show(list ? Grammar.pt(String(localized: "Added to your shopping list", comment: "Scan toast after saving a product to the list")) : Grammar.pt(String(localized: "Saved to your products", comment: "Scan toast after saving an owned product")))
    }
}

private struct ShutterStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.9 : 1).animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Live camera state for Scan: permission, torch, and the text the label mode has read so far.
@MainActor @Observable final class ScanCamera {
    enum State { case checking, ready, denied, unavailable }
    var state: State = .checking
    var torch = false
    /// The camera sees too little light; the torch turned itself on.
    var lowLight = false
    /// The owner flipped the torch by hand: auto-light leaves it alone from then on.
    @ObservationIgnored var userSetTorch = false
    var labelMode = false
    private(set) var lines: [String] = []
    private(set) var barcode: String?
    @ObservationIgnored private var seen = Set<String>()
    @ObservationIgnored weak var scanner: DataScannerViewController?

    var hasTorch: Bool { AVCaptureDevice.default(for: .video)?.hasTorch ?? false }

    func prepare() async {
        guard state == .checking || state == .denied else { return }
        guard DataScannerViewController.isSupported else { state = .unavailable; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { state = .denied; return }
        default: state = .denied; return
        }
        state = DataScannerViewController.isAvailable ? .ready : .unavailable
    }

    func setTorch(_ on: Bool) {
        guard let d = AVCaptureDevice.default(for: .video), d.hasTorch, (try? d.lockForConfiguration()) != nil else { torch = false; return }
        d.torchMode = on ? .on : .off
        d.unlockForConfiguration()
        torch = on
    }

    /// Dark when the sensor is pushing high ISO or still underexposed at its limit.
    var isDark: Bool {
        guard let d = AVCaptureDevice.default(for: .video) else { return false }
        let maxISO = max(d.activeFormat.maxISO, 1)
        return d.iso / maxISO > 0.5 || d.exposureTargetOffset < -1.5
    }
    private var isBright: Bool {
        guard let d = AVCaptureDevice.default(for: .video) else { return false }
        return d.iso / max(d.activeFormat.maxISO, 1) < 0.2 && d.exposureTargetOffset > -0.5
    }

    /// While the camera runs: low light turns the torch on, plenty of light turns an auto torch back off.
    func watchLight() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(700))
            guard state == .ready, hasTorch, !userSetTorch else { continue }
            if !torch && isDark { setTorch(true); lowLight = true }
            else if torch && lowLight && !isDarkWithTorch { setTorch(false); lowLight = false }
        }
    }
    /// With the torch on the sensor reads bright, so only switch back off once ambient light is clearly fine.
    private var isDarkWithTorch: Bool { !isBright }

    /// The whole photo, uncropped. In the dark the torch fires for the shot even if it was off.
    func capture() async -> Data? {
        guard let s = scanner else { return nil }
        var flashed = false
        if hasTorch, !torch, isDark { setTorch(true); flashed = true; try? await Task.sleep(for: .milliseconds(450)) }
        let img = try? await s.capturePhoto()
        if flashed { setTorch(false) }
        return img?.jpegData(compressionQuality: 0.9)
    }

    func resetText() { lines = []; barcode = nil; seen = [] }

    func add(_ items: [RecognizedItem]) {
        guard labelMode else { return }
        for item in items {
            switch item {
            case .text(let t) where seen.insert(t.transcript).inserted: lines.append(t.transcript)
            case .barcode(let b): if let v = b.payloadStringValue, seen.insert(v).inserted { barcode = v }
            default: break
            }
        }
    }
}

/// VisionKit's live scanner as a plain camera layer: text and barcodes are read while it runs.
private struct ScanCameraView: UIViewControllerRepresentable {
    let camera: ScanCamera
    var running: Bool

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.text(), .barcode()], qualityLevel: .accurate, recognizesMultipleItems: true,
                                           isHighFrameRateTrackingEnabled: false, isPinchToZoomEnabled: true, isGuidanceEnabled: false, isHighlightingEnabled: false)
        vc.delegate = context.coordinator
        camera.scanner = vc
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        if running, !vc.isScanning { try? vc.startScanning() }
        else if !running, vc.isScanning { vc.stopScanning() }
    }

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) { vc.stopScanning() }

    func makeCoordinator() -> Coordinator { Coordinator(camera: camera) }

    @MainActor final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let camera: ScanCamera
        init(camera: ScanCamera) { self.camera = camera }
        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) { camera.add(items) }
    }
}

/// Soils, foods and treatments you own, plus the shopping list.
private struct ProductShelfSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \OwnedProduct.addedAt, order: .reverse) private var owned: [OwnedProduct]
    let plants: [Plant]
    private var shelf: [OwnedProduct] { owned.filter { !$0.onShoppingList } }
    private var shopping: [OwnedProduct] { owned.filter(\.onShoppingList) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if owned.isEmpty {
                        JungleEmptyState(mood: .soilbag, title: Grammar.pt(String(localized: "No products yet", comment: "Scan products sheet empty title; max 30 chars")),
                                         message: Grammar.pt(String(localized: "Scan the soils and foods you have, and I'll remember which plant loves which.", comment: "Scan products sheet empty line")))
                    }
                    if !shopping.isEmpty { shoppingList }
                    if !shelf.isEmpty { shelfSection }
                    if !plants.isEmpty { JungleDietCard(plants: plants) }
                }
                .padding(16)
            }
            .jungleBackdrop()
            .navigationTitle(Grammar.pt(String(localized: "My products", comment: "Scan: soils and foods you own and your shopping list; max 20 chars")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } } }
        }
        .presentationDragIndicator(.visible)
    }

    private var shoppingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Shopping list").font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
                Spacer()
                ShareLink(item: shopping.map { "• \($0.name)" }.joined(separator: "\n"), subject: Text("Plant shopping list", comment: "Share subject for shopping list")) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("Share shopping list", comment: "Accessibility label for share button"))
            }
            VStack(spacing: 0) {
                ForEach(shopping) { o in
                    Button {
                        withAnimation(.snappy) { o.onShoppingList = false; o.addedAt = Date(); try? ctx.save() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "circle").font(.system(.title3, design: .rounded)).foregroundStyle(Jungle.leaf)
                            Text(o.name).foregroundStyle(Jungle.text)
                            Spacer()
                            Text("Bought").font(.caption).foregroundStyle(Jungle.subtle)
                        }
                        .padding(14).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu { Button("Remove", systemImage: "trash", role: .destructive) { ctx.delete(o); try? ctx.save() } }
                    if o.id != shopping.last?.id { Divider().padding(.leading, 46) }
                }
            }
            .jungleCard()
        }
    }

    private var shelfSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("On my shelf").font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(shelf) { o in ShelfCard(product: o)
                        .contextMenu {
                            Button("Add to shopping list", systemImage: "cart") { o.onShoppingList = true; try? ctx.save() }
                            Button("Remove", systemImage: "trash", role: .destructive) { ctx.delete(o); try? ctx.save() }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

extension Compatibility.Verdict {
    var scanLabel: String {
        switch self {
        case .suitable: Grammar.pt(String(localized: "Suitable", comment: "Product verdict for a plant"))
        case .conditions: Grammar.pt(String(localized: "With conditions", comment: "Product verdict for a plant"))
        case .notRecommended: Grammar.pt(String(localized: "Not recommended", comment: "Product verdict for a plant"))
        case .unknown: Grammar.pt(String(localized: "Not enough info", comment: "Product verdict for a plant"))
        }
    }
}

private struct IdentifiedProduct: Identifiable { let product: AnalyzedProduct; var id: String { product.name + (product.barcode ?? "") } }

extension AnalyzedProduct.Category {
    var symbol: String {
        switch self { case .substrate: "square.stack.3d.down.forward.fill"; case .fertilizer: "drop.triangle.fill"; case .pesticide: "ant.fill"; case .pot: "cylinder.fill"; case .unknown: "questionmark" }
    }
    var icon: Icon3D {
        switch self { case .substrate: .soil; case .fertilizer: .fertilizer; case .pesticide: .bug; case .pot: .pot; case .unknown: .box }
    }
    var tint: Color {
        switch self { case .substrate: Jungle.terracotta; case .fertilizer: Jungle.leaf; case .pesticide: Jungle.peach; case .pot: Jungle.sun; case .unknown: Jungle.sage }
    }
}

private struct ShelfCard: View {
    let product: OwnedProduct
    var body: some View {
        let cat = AnalyzedProduct.Category(rawValue: product.categoryRaw) ?? .unknown
        VStack(alignment: .leading, spacing: 10) {
            Icon3DView(cat.icon, size: 30)
                .frame(width: 44, height: 44).background(cat.tint.opacity(0.3), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(product.name).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text).lineLimit(2, reservesSpace: true)
            Text(product.npkN != nil ? Grammar.pt(String(localized: "NPK \(Int(product.npkN!))-\(Int(product.npkP ?? 0))-\(Int(product.npkK ?? 0))", comment: "Fertilizer NPK ratio, e.g. NPK 3-1-1")) : cat.label)
                .font(.caption).foregroundStyle(Jungle.subtle).lineLimit(1)
        }
        .padding(12).frame(width: 150, alignment: .leading).jungleCard()
    }
}

/// Typed label fallback, for when the camera can't read it.
private struct TypeLabelSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCheck: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Copy the name, NPK numbers or ingredients. For example: Orchid mix, pine bark, perlite, NPK 3-1-1.")
                    .font(.subheadline).foregroundStyle(Jungle.subtle)
                TextField("What's on the label", text: $text, axis: .vertical)
                    .lineLimit(4...8).focused($focused)
                    .padding(14).background(Jungle.mist, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer()
            }
            .padding(16)
            .jungleBackdrop()
            .navigationTitle("Type the label").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Check") { let t = text; dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onCheck(t) } }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

/// Result: what it is, how it behaves, and a verdict per plant.
private struct ProductResultView: View {
    @Environment(\.dismiss) private var dismiss
    let product: AnalyzedProduct
    let plants: [Plant]
    var onLocked: (PlusFeature) -> Void
    var onSave: (Bool) -> Void
    private var isPlus: Bool { Store.shared.isPlus }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if product.npk != nil || product.retention != nil { traits }
                    if !product.ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Inside").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                            FlowChips(items: product.ingredients.map(\.capitalized), selected: nil) { _ in }
                        }
                    }
                    verdicts
                }
                .padding(16)
            }
            .jungleBackdrop()
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button { isPlus ? onSave(true) : onLocked(.inventory) } label: { Label("Shopping list", systemImage: "cart").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).fontDesign(.rounded).tint(Jungle.leaf)
                    Button { isPlus ? onSave(false) : onLocked(.inventory) } label: { Label("I own this", systemImage: "tray.and.arrow.down.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).fontDesign(.rounded).junglePrimary()
                }
                .buttonBorderShape(.capsule).controlSize(.large)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.bar)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark") { dismiss() } } }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Icon3DView(product.category.icon, size: 46)
                .frame(width: 64, height: 64).background(product.category.tint.opacity(0.3), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name).font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text).lineLimit(2)
                Text(product.category.label).font(.subheadline).foregroundStyle(Jungle.subtle)
                if let code = product.barcode { Text(code).font(.caption.monospacedDigit()).foregroundStyle(Jungle.subtle) }
            }
        }
    }

    private var traits: some View {
        VStack(spacing: 14) {
            if let npk = product.npk {
                HStack(spacing: 10) {
                    nutrient("N", Grammar.pt(String(localized: "Leaves", comment: "Nitrogen benefit label under N; short")), npk.n, Jungle.leaf)
                    nutrient("P", Grammar.pt(String(localized: "Roots and flowers", comment: "Phosphorus benefit label under P; short")), npk.p, Jungle.terracotta)
                    nutrient("K", Grammar.pt(String(localized: "Strength", comment: "Potassium benefit label under K; short")), npk.k, Jungle.sun)
                }
            }
            if let r = product.retention, let a = product.aeration {
                meter(Grammar.pt(String(localized: "Holds water", comment: "Substrate trait meter: water retention")), r, "drop.fill")
                meter(Grammar.pt(String(localized: "Lets roots breathe", comment: "Substrate trait meter: aeration")), a, "wind")
            }
        }
        .padding(16).jungleCard()
    }

    private func nutrient(_ l: String, _ sub: String, _ v: Double, _ c: Color) -> some View {
        VStack(spacing: 4) {
            Text(v.formatted(.number.precision(.fractionLength(0...1)))).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Jungle.text)
            Text(l).font(.caption.weight(.bold)).foregroundStyle(Jungle.text).frame(width: 24, height: 24).background(c.opacity(0.3), in: Circle())
            Text(sub).font(.caption2).foregroundStyle(Jungle.subtle).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func meter(_ t: String, _ v: Double, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(t, systemImage: s).font(.subheadline).foregroundStyle(Jungle.text)
                Spacer()
                Text(v > 0.66 ? Grammar.pt(String(localized: "High", comment: "Substrate meter level")) : v > 0.4 ? Grammar.pt(String(localized: "Medium", comment: "Substrate meter level")) : Grammar.pt(String(localized: "Low", comment: "Substrate meter level"))).font(.subheadline.weight(.medium)).foregroundStyle(Jungle.subtle)
            }
            GeometryReader { g in
                Capsule().fill(Jungle.mint).overlay(alignment: .leading) { Capsule().fill(Jungle.leaf).frame(width: g.size.width * min(1, max(0.06, v))) }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var verdicts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("For your plants").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
            if plants.isEmpty {
                Text("Add plants and I'll tell you which ones this suits.").foregroundStyle(Jungle.subtle)
            } else if !isPlus {
                Button { onLocked(.scanCompatibility) } label: {
                    HStack(spacing: -10) {
                        ForEach(plants.prefix(4)) { PlantAvatar(data: $0.photo, size: 36).overlay(Circle().stroke(Jungle.cream, lineWidth: 2)) }
                    }
                    .blur(radius: 1.5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Grammar.pt(String(localized: "See which of your \(plants.count) plants this suits", comment: "Scan result Plus upsell; plural"))).font(.subheadline.weight(.semibold)).foregroundStyle(Jungle.text)
                        Text("With Greenhouse or Jungle").font(.caption).foregroundStyle(Jungle.subtle)
                    }
                    .padding(.leading, 14)
                    Spacer()
                    Image(systemName: "lock.fill").foregroundStyle(Jungle.leaf)
                }
                .buttonStyle(.plain).padding(14)
                .background(Jungle.mist, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
            } else {
                ForEach(ProductAnalyzer.compatibility(product, plants: plants)) { c in
                    let p = plants.first { $0.id == c.plantID }
                    HStack(alignment: .top, spacing: 12) {
                        PlantAvatar(data: p?.photo, size: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(c.plantName).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                                Spacer()
                                Label(c.verdict.scanLabel, systemImage: icon(c.verdict)).font(.caption.weight(.semibold))
                                    .foregroundStyle(Jungle.text)
                                    .padding(.horizontal, 9).padding(.vertical, 4)
                                    .background(color(c.verdict).opacity(0.3), in: Capsule())
                            }
                            ForEach(c.reasons, id: \.self) { Text($0).font(.subheadline).foregroundStyle(Jungle.subtle) }
                        }
                    }
                    .padding(14).jungleCard()
                }
            }
        }
    }

    private func icon(_ v: Compatibility.Verdict) -> String {
        switch v { case .suitable: "checkmark.circle.fill"; case .conditions: "exclamationmark.circle.fill"; case .notRecommended: "xmark.circle.fill"; case .unknown: "questionmark.circle.fill" }
    }
    private func color(_ v: Compatibility.Verdict) -> Color {
        switch v { case .suitable: Jungle.leaf; case .conditions: Jungle.sun; case .notRecommended: Jungle.terracotta; case .unknown: Jungle.sage }
    }
}

enum OCR {
    static func recognize(_ image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { cont in
            let req = VNRecognizeTextRequest { r, _ in
                let lines = (r.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string } ?? []
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            req.recognitionLevel = .accurate
            req.recognitionLanguages = Locale.current.language.languageCode == .portuguese ? ["pt-BR", "en-US", "pt-PT", "es-ES", "fr-FR", "de-DE"] : ["en-US", "pt-BR", "pt-PT", "es-ES", "fr-FR", "de-DE"]
            req.usesLanguageCorrection = true
            do { try VNImageRequestHandler(cgImage: cg).perform([req]) } catch { cont.resume(returning: "") }
        }
    }
}


/// Soil and food each plant wants, for a page with room beside the scanner.
private struct JungleDietCard: View {
    let plants: [Plant]
    var body: some View {
        let known = plants.filter { $0.species != nil }
        VStack(alignment: .leading, spacing: 10) {
            Text(Grammar.pt(String(localized: "What your jungle eats", comment: "Scan section title: soil and feed each plant wants"))).font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
            VStack(spacing: 0) {
                ForEach(Array(known.enumerated()), id: \.element.id) { i, p in
                    if i > 0 { Divider().padding(.leading, 60) }
                    HStack(spacing: 12) {
                        PlantAvatar(data: p.photo, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.name).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
                            if let s = p.species {
                                let line = [s.soil?.short, s.feed == "none" ? Grammar.pt(String(localized: "no feed", comment: "Scan diet row: plant must never be fertilized")) : s.fertilizer?.name].compactMap { $0 }.joined(separator: " · ")
                                Text(line.prefix(1).uppercased() + line.dropFirst())
                                    .font(.footnote).foregroundStyle(Jungle.subtle).lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 14).jungleCard()
        }
    }
}


extension View {
    /// Frosted warm chrome over the camera: cream glass with a soft leaf rim.
    func warmGlass<S: InsettableShape>(_ shape: S) -> some View {
        self.background(.ultraThinMaterial, in: shape)
            .background(Jungle.cream.opacity(0.55), in: shape)
            .overlay(shape.strokeBorder(Jungle.separator, lineWidth: 1))
    }
}
