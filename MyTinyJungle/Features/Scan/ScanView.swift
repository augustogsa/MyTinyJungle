import SwiftUI
import SwiftData
import PhotosUI
import Vision
import VisionKit

/// Scan: one warm place to point the camera at anything plant-related.
struct ScanView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Plant> { !$0.isArchived }) private var plants: [Plant]
    @Query(sort: \OwnedProduct.addedAt, order: .reverse) private var owned: [OwnedProduct]
    @State private var liveScanning = false
    @State private var pick: PhotosPickerItem?
    @State private var collectedText = ""
    @State private var barcode: String?
    @State private var product: AnalyzedProduct?
    @State private var working = false
    @State private var typing = false
    @State private var paywall: PlusFeature?
    @State private var addingPlant = false
    @State private var checking: Plant?

    private var shelf: [OwnedProduct] { owned.filter { !$0.onShoppingList } }
    private var shopping: [OwnedProduct] { owned.filter(\.onShoppingList) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TabHeader(title: Grammar.pt(String(localized: "Scan", comment: "Scan tab title")), subtitle: Grammar.pt(String(localized: "Labels, new plants and sick leaves", comment: "Scan tab subtitle"))) { EmptyView() }
                    hero
                    modes
                    if !shopping.isEmpty { shoppingList }
                    if shelf.count + shopping.count >= 2 { NativeAdCard(slot: "scan") }
                    shelfSection
                }
                .padding(.horizontal, 16).padding(.bottom, 32)
            }
            .jungleBackdrop()
            .toolbar(.hidden, for: .navigationBar)
            .task { if DemoSeeder.wantsScan, product == nil { try? await Task.sleep(for: .seconds(1)); product = ProductAnalyzer.analyze(text: DemoSeeder.sampleLabel) } }
            .sheet(item: $paywall) { PaywallView(reason: $0) }
            .sheet(isPresented: $addingPlant) { AddPlantFlow() }
            .sheet(item: $checking) { p in NavigationStack { HealthCheckView(plant: p) } }
            .sheet(isPresented: $typing) { TypeLabelSheet { analyze($0) } }
            .sheet(item: Binding(get: { product.map(IdentifiedProduct.init) }, set: { if $0 == nil { product = nil } })) { wrap in
                ProductResultView(product: wrap.product, plants: plants, onLocked: { p in product = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { paywall = p } }) { save(wrap.product, list: $0) }
                    .presentationDetents([.large]).presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $liveScanning) {
                LiveLabelScanner { text, code in
                    if let code { barcode = code }
                    if let text { collectedText += "\n" + text }
                } onDone: {
                    liveScanning = false
                    analyze(collectedText)
                }
                .ignoresSafeArea()
            }
            .onChange(of: pick) { _, item in
                guard let item else { return }
                reset(); working = true
                Task {
                    let data = try? await item.loadTransferable(type: Data.self)
                    var text = ""
                    if let data, let img = UIImage(data: data) { text = await OCR.recognize(img) }
                    await MainActor.run { working = false; pick = nil; analyze(text) }
                }
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Jungle.mint, Jungle.sun.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Viewfinder().stroke(Jungle.leaf.opacity(0.7), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .padding(28)
                VStack(spacing: 8) {
                    if working {
                        ErtyView(mood: .scan, size: 110)
                        Text("Reading the label…").font(.subheadline.weight(.medium)).foregroundStyle(Jungle.text)
                    } else {
                        Icon3DView(.leafTag, size: 64)
                        Text("Soil, food or treatment").font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                        Text("Point at the back label. I'll check it\nagainst every plant you have.")
                            .font(.footnote).multilineTextAlignment(.center).foregroundStyle(Jungle.subtle)
                    }
                }
            }
            .frame(height: 210)
            .accessibilityElement(children: .combine)

            Button {
                reset()
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable { liveScanning = true } else { typing = true }
            } label: {
                Text("Scan a label").font(.system(.headline, design: .rounded)).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent).fontDesign(.rounded).buttonBorderShape(.capsule).controlSize(.large).tint(Jungle.forest)

            HStack(spacing: 10) {
                PhotosPicker(selection: $pick, matching: .images) {
                    Text("From photos").frame(maxWidth: .infinity)
                }
                Button { typing = true } label: { Text("Type it").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.bordered).fontDesign(.rounded).buttonBorderShape(.capsule).tint(Jungle.leaf).font(.subheadline.weight(.medium))
        }
        .padding(16)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 24 + 16, style: .continuous))
    }

    // MARK: Modes

    private var modes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Also scan").font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(Jungle.text)
            HStack(spacing: 10) {
                Button { Store.shared.canAddPlant(current: plants.count) ? (addingPlant = true) : (paywall = .morePlants) } label: {
                    modeTile(Grammar.pt(String(localized: "A new plant", comment: "Scan mode tile title")), Grammar.pt(String(localized: "Identify it and get its care plan", comment: "Scan mode tile subtitle")), .pottedPlant, Jungle.mint)
                }
                Menu {
                    ForEach(plants) { p in Button(p.name) { checking = p } }
                } label: {
                    modeTile(Grammar.pt(String(localized: "A sick leaf", comment: "Scan mode tile title")), Grammar.pt(String(localized: "Spots, yellowing or pests", comment: "Scan mode tile subtitle")), .wilted, Jungle.peach.opacity(0.45))
                }
                .disabled(plants.isEmpty)
            }
            .buttonStyle(.plain)
        }
    }

    private func modeTile(_ t: String, _ sub: String, _ s: Icon3D, _ bg: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Icon3DView(s, size: 32)
                .frame(width: 44, height: 44).background(.white.opacity(0.7), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(.system(.headline, design: .rounded)).foregroundStyle(Jungle.text)
                Text(sub).font(.caption).foregroundStyle(Jungle.subtle).multilineTextAlignment(.leading).lineLimit(2, reservesSpace: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(bg, in: RoundedRectangle(cornerRadius: Jungle.radius, style: .continuous))
    }

    // MARK: Shopping + shelf

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
            if shelf.isEmpty {
                HStack(spacing: 14) {
                    Icon3DView(.box, size: 40)
                    Text("Scan the soils and foods you have, and I'll remember which plant loves which.")
                        .font(.subheadline).foregroundStyle(Jungle.subtle)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).jungleCard()
            } else {
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
                .scrollClipDisabled()
            }
        }
    }

    // MARK: Logic

    private func reset() { collectedText = ""; barcode = nil; product = nil }

    private func analyze(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || barcode != nil else { return }
        product = ProductAnalyzer.analyze(text: text, barcode: barcode)
    }

    private func save(_ p: AnalyzedProduct, list: Bool) {
        let o = OwnedProduct(name: p.name, category: p.category.rawValue)
        o.barcode = p.barcode
        o.npkN = p.npk?.n; o.npkP = p.npk?.p; o.npkK = p.npk?.k
        o.ingredients = p.ingredients
        o.onShoppingList = list
        ctx.insert(o)
        try? ctx.save()
        product = nil
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
                        .buttonStyle(.borderedProminent).fontDesign(.rounded).tint(Jungle.forest)
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
            Text(l).font(.caption.weight(.bold)).foregroundStyle(.white).frame(width: 22, height: 22).background(c, in: Circle())
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
                        Text("With My Tiny Jungle Plus").font(.caption).foregroundStyle(Jungle.subtle)
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

/// Live VisionKit scanner: collects text and barcodes until Done.
struct LiveLabelScanner: UIViewControllerRepresentable {
    var onItem: (String?, String?) -> Void
    var onDone: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = DataScannerViewController(recognizedDataTypes: [.text(), .barcode()], qualityLevel: .accurate,
                                           recognizesMultipleItems: true, isHighFrameRateTrackingEnabled: false, isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        vc.navigationItem.title = Grammar.pt(String(localized: "Point at the label", comment: "Live label scanner title"))
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { _ in onDone() })
        try? vc.startScanning()
        return UINavigationController(rootViewController: vc)
    }
    func updateUIViewController(_ vc: UINavigationController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onItem: onItem) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onItem: (String?, String?) -> Void
        var seen = Set<String>()
        init(onItem: @escaping (String?, String?) -> Void) { self.onItem = onItem }
        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in items {
                switch item {
                case .text(let t) where !seen.contains(t.transcript): seen.insert(t.transcript); onItem(t.transcript, nil)
                case .barcode(let b): if let v = b.payloadStringValue, !seen.contains(v) { seen.insert(v); onItem(nil, v) }
                default: break
                }
            }
        }
    }
}
