import UIKit
import Vision
import CoreML

/// On-device photo reading: what the camera sees, leaf colour health and a soil moisture estimate.
/// Everything here is an estimate and is labelled as such in the UI.
struct PhotoRead {
    var labels: [(String, Float)] = []
    var greenShare: Double = 0
    var yellowShare: Double = 0
    var brownShare: Double = 0
    var soilVisible = false
    var soilMoisture: SoilState?
    /// A whole-plant shot: leaves are a smaller share of the frame, so the bar for judging is lower.
    var wholePlant = false
    /// The server scene saw a real plant: never claim there weren't enough leaves.
    var sceneHasLeaves = false

    enum Health { case lush, good, someStress, stressed, unknown }
    var health: Health {
        let foliage = greenShare + yellowShare + brownShare
        guard foliage > (wholePlant ? 0.025 : 0.06) else { return sceneHasLeaves || foliage > 0.01 && wholePlant ? .good : .unknown }
        let bad = (yellowShare + brownShare) / foliage
        // Variegation, pots and backgrounds fool colour counts, so only a strong, leaf-bound signal counts as stress.
        switch bad {
        case ..<0.08: return greenShare > 0.35 ? .lush : .good
        case ..<0.22: return .good
        case ..<0.45: return .someStress
        default: return yellowShare + brownShare > 0.08 ? .stressed : .someStress
        }
    }

    var healthSummary: String {
        switch health {
        case .lush: Grammar.pt(String(localized: "Leaves look lush and green.", comment: "Photo read: leaf health summary, labelled as an estimate."))
        case .good: Grammar.pt(String(localized: "Leaves look healthy overall.", comment: "Photo read: leaf health summary, labelled as an estimate."))
        case .someStress: yellowShare >= brownShare ? Grammar.pt(String(localized: "Mostly healthy. There might be a little yellowing, hard to tell from one photo.", comment: "Photo read: uncertain leaf health summary, labelled as an estimate; gentle, not alarming")) : Grammar.pt(String(localized: "Mostly healthy. There might be a few brown edges, hard to tell from one photo.", comment: "Photo read: uncertain leaf health summary, labelled as an estimate; gentle, not alarming"))
        case .stressed: yellowShare >= brownShare ? Grammar.pt(String(localized: "A lot of yellowing. Check the roots and how wet the soil stays.", comment: "Photo read: leaf health summary, labelled as an estimate.")) : Grammar.pt(String(localized: "A lot of browning. Check watering, humidity and sun.", comment: "Photo read: leaf health summary, labelled as an estimate."))
        case .unknown: Grammar.pt(String(localized: "I couldn't see enough leaves to judge health.", comment: "Photo read: leaf health summary, labelled as an estimate."))
        }
    }
}

enum PlantVision {
    static func read(_ image: UIImage, wholePlant: Bool = false) async -> PhotoRead {
        var r = PhotoRead()
        r.wholePlant = wholePlant
        r.labels = await classify(image)
        colour(image, into: &r)
        return r
    }

    static func classify(_ image: UIImage) async -> [(String, Float)] {
        guard let cg = image.cgImage else { return [] }
        #if targetEnvironment(simulator)
        return [] // Vision's classifier returns the same junk labels on the simulator; the species list takes over.
        #else
        return await Task.detached(priority: .userInitiated) {
            func run(cpu: Bool) -> [(String, Float)]? {
                let req = VNClassifyImageRequest()
                if cpu, let cpuDevice = MLComputeDevice.allComputeDevices.first(where: { if case .cpu = $0 { true } else { false } }) {
                    req.setComputeDevice(cpuDevice, for: .main)
                }
                do { try VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req]) } catch { return nil }
                return (req.results ?? []).filter { $0.confidence > 0.05 }.prefix(25).map { ($0.identifier, $0.confidence) }
            }
            if let r = run(cpu: false), !r.isEmpty { return r }
            return run(cpu: true) ?? []
        }.value
        #endif
    }

    /// HSV pixel census on a 96×96 thumbnail. Bottom third is checked for soil.
    static func colour(_ image: UIImage, into r: inout PhotoRead) {
        let side = 96
        guard let cg = image.cgImage,
              let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return }
        var green = 0, yellow = 0, brown = 0
        var soilCount = 0, soilV = 0.0
        let total = side * side
        // 0 other, 1 green, 2 yellow, 3 brown
        var kind = [UInt8](repeating: 0, count: total)
        for y in 0..<side {
            for x in 0..<side {
                let i = (y * side + x) * 4
                let (h, s, v) = hsv(Double(data[i]) / 255, Double(data[i + 1]) / 255, Double(data[i + 2]) / 255)
                // Dark glossy leaves (fiddle-leaf fig, ZZ) sit low in value and toward olive, so the green band is wide.
                if s > 0.18, v > 0.1, (62...175).contains(h) { kind[y * side + x] = 1 }
                // Bright, creamy yellow is variegation, not yellowing.
                else if s > 0.45, v > 0.45, !(v > 0.75 && s < 0.7), (40..<75).contains(h) { kind[y * side + x] = 2 }
                else if s > 0.35, (0.2...0.65).contains(v), (12..<40).contains(h) { kind[y * side + x] = 3 }
                // CGContext origin is bottom-left: y < side/3 is the bottom of the photo.
                if y < side / 3, s < 0.55, v < 0.45, (h < 45 || h > 330 || s < 0.15) { soilCount += 1; soilV += v }
            }
        }
        // Leaf mask: yellow/brown only counts when it sits among green leaf pixels (not pots, floors or walls).
        let r2 = 3
        for y in 0..<side {
            for x in 0..<side {
                let k = kind[y * side + x]
                if k == 1 { green += 1; continue }
                guard k >= 2 else { continue }
                var near = 0, seen = 0
                for dy in -r2...r2 { for dx in -r2...r2 {
                    let yy = y + dy, xx = x + dx
                    guard yy >= 0, yy < side, xx >= 0, xx < side else { continue }
                    seen += 1; if kind[yy * side + xx] == 1 { near += 1 }
                } }
                guard Double(near) / Double(seen) >= 0.25 else { continue }
                if k == 2 { yellow += 1 } else { brown += 1 }
            }
        }
        r.greenShare = Double(green) / Double(total)
        r.yellowShare = Double(yellow) / Double(total)
        r.brownShare = Double(brown) / Double(total)
        let bottom = Double(total) / 3
        if Double(soilCount) > bottom * 0.18 {
            r.soilVisible = true
            let mean = soilV / Double(soilCount)
            r.soilMoisture = mean < 0.17 ? .wet : mean < 0.27 ? .slightlyMoist : .dry
        }
    }

    static func hsv(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        var h = 0.0
        if d > 0 {
            if mx == r { h = 60 * ((g - b) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == g { h = 60 * ((b - r) / d + 2) }
            else { h = 60 * ((r - g) / d + 4) }
        }
        if h < 0 { h += 360 }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }
}

/// Species candidates: remote identifier (Pl@ntNet through our API) when configured, else on-device labels.
enum PlantIdentifier {
    struct Candidate: Identifiable, Hashable {
        let species: Species
        let confidence: Double
        let source: String
        var id: String { species.id }
    }

    /// Vision taxonomy words → our species (or families of species).
    static let labelMap: [(String, [String])] = [
        ("monstera", ["monstera-deliciosa"]), ("philodendron", ["philodendron-hederaceum", "monstera-deliciosa"]),
        ("pothos", ["epipremnum-aureum"]), ("ivy", ["hedera-helix", "epipremnum-aureum"]),
        ("cactus", ["cactus-generic"]), ("succulent", ["echeveria", "crassula-ovata", "aloe-vera"]),
        ("aloe", ["aloe-vera"]), ("jade", ["crassula-ovata"]), ("orchid", ["phalaenopsis"]),
        ("fern", ["nephrolepis"]), ("palm", ["dypsis-lutescens", "chamaedorea", "beaucarnea"]),
        ("fig", ["ficus-lyrata", "ficus-elastica"]), ("ficus", ["ficus-lyrata", "ficus-elastica"]), ("rubber", ["ficus-elastica"]),
        ("snake_plant", ["sansevieria"]), ("sansevieria", ["sansevieria"]), ("lily", ["spathiphyllum"]),
        ("basil", ["ocimum-basilicum"]), ("mint", ["mentha"]), ("rosemary", ["rosmarinus"]), ("lavender", ["lavandula"]),
        ("herb", ["ocimum-basilicum", "mentha", "rosmarinus"]), ("tomato", ["solanum-lycopersicum"]),
        ("lemon", ["citrus-limon"]), ("citrus", ["citrus-limon"]), ("olive", ["olea-europaea"]),
        ("azalea", ["rhododendron-azalea"]), ("rhododendron", ["rhododendron-azalea"]), ("hydrangea", ["hydrangea"]),
        ("begonia", ["begonia-maculata"]), ("anthurium", ["anthurium"]), ("bird_of_paradise", ["strelitzia"]),
        ("spider_plant", ["chlorophytum"]),
        // No generic words ("houseplant", "foliage", "flower"): they used to put the same fixed guesses on every photo.
    ]

    /// Vision label words that point at a whole plant group in the knowledge base.
    static let groupWords: [(String, String)] = [
        ("cactus", "cactus"), ("succulent", "succulent"), ("fern", "fern"), ("orchid", "orchid"), ("palm", "palm"),
        ("herb", "herb-soft"), ("vegetable", "vegetable"), ("bromeliad", "bromeliad"), ("shrub", "shrub"), ("bulb", "bulb"),
        ("carnivorous", "carnivorous"), ("venus", "carnivorous"), ("flower", "flowering"), ("bonsai", "ficus"),
    ]

    static func candidates(from read: PhotoRead) -> [Candidate] {
        var score: [String: Double] = [:]
        let lib = SpeciesLibrary.shared.all
        for (label, conf) in read.labels {
            let l = label.lowercased().replacingOccurrences(of: "_", with: " ")
            for (key, ids) in labelMap where l.contains(key.replacingOccurrences(of: "_", with: " ")) {
                for (i, id) in ids.enumerated() { score[id, default: 0] += Double(conf) / Double(i + 1) }
            }
            // Every species' own names and aliases (including Wikidata common names).
            for s in lib {
                let names = [s.en, s.scientific, s.scientific.components(separatedBy: " ").first ?? ""] + (s.aliases ?? [])
                if names.contains(where: { $0.count >= 4 && $0.folded == l.folded || ($0.count >= 5 && l.folded.contains($0.folded)) }) {
                    score[s.id, default: 0] += Double(conf) * 1.2
                }
            }
            // A group word only nudges species something more specific already named.
            for (word, group) in groupWords where l.contains(word) {
                for s in lib where s.group == group && score[s.id] != nil { score[s.id, default: 0] += Double(conf) * 0.15 }
            }
        }
        // Local climate: species hardy here are more likely in garden and balcony photos.
        let outdoorish = read.labels.contains { l in ["garden", "outdoor", "sky", "yard", "patio", "tree", "grass", "balcony"].contains { l.0.lowercased().contains($0) } }
        if outdoorish, let cold = Climate.shared.profile?.coldestNight {
            for (id, v) in score { if let s = SpeciesLibrary.shared.species(id: id), s.outdoor == true, s.tempMin <= cold + 3 { score[id] = v * 1.2 } }
        }
        if Climate.shared.isTropical {
            for (id, v) in score { if let s = SpeciesLibrary.shared.species(id: id), ["aroid", "tropical", "palm", "bromeliad", "orchid"].contains(s.group ?? "") { score[id] = v * 1.1 } }
        }
        // Leaf colour as a tie-breaker: lots of red/yellow with little green favours colourful foliage and flowers.
        if read.yellowShare + read.brownShare > read.greenShare {
            for (id, v) in score { if let s = SpeciesLibrary.shared.species(id: id), ["flowering", "bulb", "shrub"].contains(s.group ?? "") { score[id] = v * 1.15 } }
        }
        return score.sorted { $0.value > $1.value }.prefix(5).compactMap { id, s in
            SpeciesLibrary.shared.species(id: id).map { Candidate(species: $0, confidence: min(0.6, s), source: "On-device") }
        }
    }

    /// Optional remote identification. Configure `MTJIdentifyURL` in Info.plist (our API proxies Pl@ntNet; keys never ship).
    static func remote(_ jpeg: Data) async -> [Candidate] {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "MTJIdentifyURL") as? String, !s.isEmpty, let url = URL(string: s) else { return [] }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.upload(for: req, from: jpeg),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let list = try? JSONDecoder().decode([Remote].self, from: data) else { return [] }
        return list.compactMap { r in
            let match = SpeciesLibrary.shared.all.first { $0.scientific.folded == r.scientific.folded }
                ?? SpeciesLibrary.shared.mentioned(in: r.scientific)
            return match.map { Candidate(species: $0, confidence: r.score, source: "Pl@ntNet") }
        }
    }
    private struct Remote: Decodable { let scientific: String; let score: Double }
}
