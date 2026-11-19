import Foundation
import ImageIO
import UniformTypeIdentifiers
import CryptoKit
import UIKit

/// The one upload for every /v1/brain photo call: 768 px long side, JPEG q 0.7 (HEIC and PNG come out as JPEG).
/// Made once per photo and reused by identify, scene, diagnose, identify-batch and the Pl@ntNet fallback.
nonisolated struct BrainPhoto: Sendable {
    static let maxSide = 768
    static let quality = 0.7

    let jpeg: Data
    /// sha256 of the upload, the key for the result cache.
    let sha: String
    var base64: String { jpeg.base64EncodedString() }
    var image: UIImage? { UIImage(data: jpeg) }

    private static let memo = NSCache<NSString, Box>()
    private final class Box { let p: BrainPhoto; init(_ p: BrainPhoto) { self.p = p } }

    /// Same input bytes give the same prepared photo without encoding twice.
    static func make(_ raw: Data) -> BrainPhoto {
        let rawKey = sha256(raw) as NSString
        if let hit = memo.object(forKey: rawKey) { return hit.p }
        let jpeg = encode(raw) ?? raw
        let p = BrainPhoto(jpeg: jpeg, sha: sha256(jpeg))
        memo.setObject(Box(p), forKey: rawKey)
        return p
    }

    static func encode(_ raw: Data, maxSide: Int = maxSide, quality: Double = quality) -> Data? {
        guard let src = CGImageSourceCreateWithData(raw as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceShouldCacheImmediately: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxSide,
              ] as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dst = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dst, cg, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(dst) ? out as Data : nil
    }

    static func sha256(_ d: Data) -> String { SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined() }
}

/// Server answers for photos, keyed by endpoint + photo sha256 (+ whatever else changes the answer).
/// Memory first, then Caches/brain on disk; entries live 30 days. Only successful answers are kept.
nonisolated enum BrainCache {
    static let ttl: TimeInterval = 30 * 86_400
    private static let mem = NSCache<NSString, NSData>()
    static let dir: URL = {
        let d = URL.cachesDirectory.appending(path: "brain", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    static func key(_ endpoint: String, _ parts: String...) -> String {
        BrainPhoto.sha256(Data(([endpoint] + parts).joined(separator: "|").utf8))
    }

    static func get<R: Decodable>(_ key: String, as: R.Type = R.self) -> R? {
        let data: Data
        if let m = mem.object(forKey: key as NSString) { data = m as Data }
        else {
            let url = dir.appending(path: key)
            guard let at = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                  Date().timeIntervalSince(at) < ttl, let d = try? Data(contentsOf: url) else { return nil }
            mem.setObject(d as NSData, forKey: key as NSString)
            data = d
        }
        return try? JungleAPI.decoder.decode(R.self, from: data)
    }

    static func put(_ key: String, _ data: Data) {
        mem.setObject(data as NSData, forKey: key as NSString)
        try? data.write(to: dir.appending(path: key), options: .atomic)
    }

    static func clear() {
        mem.removeAllObjects()
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}

/// Photos and art decoded at the size they're shown (ImageIO downsampling), never the full original.
nonisolated enum Thumbs {
    private static let cache: NSCache<NSString, UIImage> = { let c = NSCache<NSString, UIImage>(); c.totalCostLimit = 48 << 20; return c }()

    /// `side` in points (the shorter edge it fills); decoded at 3x. Cheap key: length plus three byte windows.
    static func image(_ data: Data, side: CGFloat) -> UIImage? {
        let px = Int((side * 3).rounded(.up))
        let key = "\(fingerprint(data))@\(px)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let src = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let img = downsample(src, px) else { return nil }
        cache.setObject(img, forKey: key, cost: img.cgImage.map { $0.bytesPerRow * $0.height } ?? 0)
        return img
    }

    static func image(contentsOf url: URL, side: CGFloat) -> UIImage? {
        let px = Int((side * 3).rounded(.up))
        let key = "\(url.path)@\(px)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let img = downsample(src, px) else { return nil }
        cache.setObject(img, forKey: key, cost: img.cgImage.map { $0.bytesPerRow * $0.height } ?? 0)
        return img
    }

    static func clear() { cache.removeAllObjects() }

    /// `px` is the shorter edge (photos are shown scaled to fill), capped at the original size.
    private static func downsample(_ src: CGImageSource, _ px: Int) -> UIImage? {
        var px = px
        if let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
           let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int, min(w, h) > 0 {
            px = min(max(w, h), Int((Double(px) * Double(max(w, h)) / Double(min(w, h))).rounded(.up)))
        }
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(px, 1),
        ] as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func fingerprint(_ d: Data) -> String {
        let n = d.count, w = 32
        var h = Hasher()
        h.combine(n)
        for start in [min(512, max(n - w, 0)), max(n / 2 - w / 2, 0), max(n - w, 0)] {
            h.combine(d.subdata(in: start..<min(start + w, n)))
        }
        return String(h.finalize(), radix: 36)
    }
}
