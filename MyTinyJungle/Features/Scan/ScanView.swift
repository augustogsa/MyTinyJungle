import SwiftUI
import SwiftData
import PhotosUI
import Vision
import VisionKit

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
    @State private var pasted = ""
    @State private var paywall: PlusFeature?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scan soil, fertilizer or plant food").font(.headline).foregroundStyle(Jungle.text)
                        Text("Point at the back label with the ingredients or NPK. I'll check it against every plant you have.")
                            .font(.subheadline).foregroundStyle(Jungle.subtle)
                    }
                    if DataScannerViewController.isSupported {
                        Button { reset(); liveScanning = true } label: { Label("Scan label", systemImage: "text.viewfinder") }
                    }
                    PhotosPicker(selection: $pick, matching: .images) { Label("Choose a label photo", systemImage: "photo") }
                    HStack {
                        TextField("…or type what's on the label", text: $pasted, axis: .vertical).lineLimit(1...4)
                        Button("Check") { analyze(pasted) }.disabled(pasted.isEmpty)
                    }
                }
                if working { Section { ProgressView("Reading label…") } }
                if let product { ResultSections(product: product, plants: plants, isPlus: Store.shared.isPlus, onLocked: { paywall = $0 }) { save(product, list: $0) } }
                if !owned.isEmpty {
                    Section("My growing inventory") {
                        ForEach(owned) { p in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(p.name).foregroundStyle(Jungle.text)
                                    if p.onShoppingList { Text("Shopping list").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Jungle.sun.opacity(0.5), in: Capsule()) }
                                }
                                Text(p.categoryRaw.capitalized + (p.npkN != nil ? " · NPK \(Int(p.npkN!))-\(Int(p.npkP ?? 0))-\(Int(p.npkK ?? 0))" : "")).font(.caption).foregroundStyle(Jungle.subtle)
                            }
                        }
                        .onDelete { idx in idx.forEach { ctx.delete(owned[$0]) }; try? ctx.save() }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Jungle.cream)
            .navigationTitle("Scan")
            .sheet(item: $paywall) { PaywallView(reason: $0) }
            .sheet(isPresented: $liveScanning) {
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
                    await MainActor.run { working = false; analyze(text); pick = nil }
                }
            }
        }
    }

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

private struct ResultSections: View {
    let product: AnalyzedProduct
    let plants: [Plant]
    let isPlus: Bool
    var onLocked: (PlusFeature) -> Void
    var onSave: (Bool) -> Void

    var body: some View {
        Section("What I found") {
            LabeledContent("Product", value: product.name)
            LabeledContent("Type", value: product.category.label)
            if let npk = product.npk { LabeledContent("NPK", value: "\(fmt(npk.n))-\(fmt(npk.p))-\(fmt(npk.k))") }
            if !product.ingredients.isEmpty { LabeledContent("Contains", value: product.ingredients.joined(separator: ", ")) }
            if let r = product.retention, let a = product.aeration {
                LabeledContent("Holds water", value: level(r))
                LabeledContent("Airy", value: level(a))
            }
            if let code = product.barcode { LabeledContent("Barcode", value: code) }
        }
        if !isPlus && !plants.isEmpty {
            Section("For your plants") {
                Button { onLocked(.scanCompatibility) } label: {
                    Label("See which of your \(plants.count) plants this suits, and why. Tiny Jungle Plus.", systemImage: "lock")
                }
            }
        } else if plants.isEmpty {
            Section { Text("Add plants to see which ones this suits.").foregroundStyle(Jungle.subtle) }
        } else {
            Section("For your plants") {
                ForEach(ProductAnalyzer.compatibility(product, plants: plants)) { c in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(c.plantName).font(.headline).foregroundStyle(Jungle.text)
                            Spacer()
                            Text(c.verdict.rawValue).font(.caption.weight(.semibold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(color(c.verdict).opacity(0.25), in: Capsule())
                        }
                        ForEach(c.reasons, id: \.self) { Text("• " + $0).font(.subheadline).foregroundStyle(Jungle.subtle) }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        Section {
            Button("I own this. Add to inventory", systemImage: "tray.and.arrow.down") { isPlus ? onSave(false) : onLocked(.inventory) }
            Button("Add to shopping list", systemImage: "cart") { isPlus ? onSave(true) : onLocked(.inventory) }
        }
    }

    private func color(_ v: Compatibility.Verdict) -> Color {
        switch v { case .suitable: Jungle.leaf; case .conditions: Jungle.sun; case .notRecommended: Jungle.terracotta; case .unknown: Jungle.sage }
    }
    private func level(_ v: Double) -> String { v > 0.66 ? "High" : v > 0.4 ? "Medium" : "Low" }
    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
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
            req.recognitionLanguages = ["en-US", "pt-PT", "es-ES", "fr-FR", "de-DE"]
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
        vc.navigationItem.title = "Point at the label"
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
