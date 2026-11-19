import Foundation
import CryptoKit
import Observation
import UIKit
import SwiftUI

/// Server-driven content: species, plant knowledge, translations, Erty, icons and artwork come from
/// api.mytinyjungle.com/v1/content, so they change without an app update.
///
/// The manifest maps logical paths ("icons/water.png") to content hashes; blobs are immutable and kept on
/// disk by hash, so each file is downloaded once per device. Only the manifest is revalidated (ETag).
/// The app bundles a mini floor (compressed data, small images) used until the first download and offline.
/// Data files are read at launch, so new knowledge applies on the next launch; images refresh live.
@Observable @MainActor
final class ContentStore {
    static let shared = ContentStore()

    /// Bumped when new files land, so views showing remote images redraw.
    private(set) var revision = 0
    @ObservationIgnored private var refreshing = false
    @ObservationIgnored private let images = NSCache<NSString, UIImage>()

    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.urlCache = nil
        c.httpMaximumConnectionsPerHost = 4
        c.timeoutIntervalForRequest = 30
        return URLSession(configuration: c)
    }()

    /// Fetch the manifest and anything new. Cheap when nothing changed (one 304).
    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        var req = URLRequest(url: JungleAPI.base.appending(path: "/v1/content/manifest"))
        if let etag = ContentFiles.etag { req.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        guard let (data, res) = try? await session.data(for: req), let http = res as? HTTPURLResponse else { return }
        let manifest: ContentFiles.Manifest
        if http.statusCode == 304, let m = ContentFiles.manifest { manifest = m }
        else if http.statusCode == 200, let m = try? JSONDecoder().decode(ContentFiles.Manifest.self, from: data) { manifest = m }
        else { return }

        let missing = Set(manifest.files.values.map(\.h)).filter { !ContentFiles.has($0) }
        var landed = 0
        await withTaskGroup(of: Bool.self) { group in
            var queue = Array(missing)
            for _ in 0..<min(4, queue.count) { let h = queue.removeLast(); group.addTask { await Self.fetch(h, self.session) } }
            for await ok in group {
                if ok { landed += 1 }
                if let h = queue.popLast() { group.addTask { await Self.fetch(h, self.session) } }
            }
        }
        // Adopt the manifest even if a file failed: lookups check each blob is here and fall back to the
        // bundled floor, and the next refresh fetches only what is still missing.
        if http.statusCode == 200 {
            ContentFiles.save(manifest: data, etag: http.value(forHTTPHeaderField: "ETag"))
            ContentFiles.prune(keeping: Set(manifest.files.values.map(\.h)))
        }
        if landed > 0 || http.statusCode == 200 {
            images.removeAllObjects()
            revision += 1
        }
    }

    nonisolated private static func fetch(_ h: String, _ session: URLSession) async -> Bool {
        guard let (data, res) = try? await session.data(from: JungleAPI.base.appending(path: "/v1/content/b/\(h)")),
              (res as? HTTPURLResponse)?.statusCode == 200 else { return false }
        return ContentFiles.store(data, as: h)
    }

    /// Remote image for a logical path, or nil while it isn't on this device yet.
    func image(_ path: String) -> UIImage? {
        _ = revision
        if let i = images.object(forKey: path as NSString) { return i }
        guard let url = ContentFiles.url(path), let i = UIImage(contentsOfFile: url.path) else { return nil }
        images.setObject(i, forKey: path as NSString)
        return i
    }
}

/// File side of the content store. Nonisolated so data loaders (species, knowledge) can read it from anywhere.
nonisolated enum ContentFiles {
    struct Manifest: Codable { struct File: Codable { var h: String; var n: Int }; var version: String; var files: [String: File] }

    static let dir: URL = {
        var d = URL.applicationSupportDirectory.appending(path: "Content", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: d.appending(path: "b"), withIntermediateDirectories: true)
        var v = URLResourceValues(); v.isExcludedFromBackup = true
        try? d.setResourceValues(v)
        return d
    }()

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cached: Manifest??

    static var manifest: Manifest? {
        lock.withLock {
            if let cached { return cached }
            let m = (try? Data(contentsOf: dir.appending(path: "manifest.json"))).flatMap { try? JSONDecoder().decode(Manifest.self, from: $0) }
            cached = .some(m)
            return m
        }
    }

    static var etag: String? { UserDefaults.standard.string(forKey: "content.etag") }

    static func save(manifest data: Data, etag: String?) {
        try? data.write(to: dir.appending(path: "manifest.json"), options: .atomic)
        UserDefaults.standard.set(etag, forKey: "content.etag")
        lock.withLock { cached = nil }
    }

    static func has(_ h: String) -> Bool { FileManager.default.fileExists(atPath: dir.appending(path: "b/\(h)").path) }

    /// Writes a blob only if its bytes match the hash in its name.
    static func store(_ data: Data, as h: String) -> Bool {
        let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard h.hasPrefix(String(hex.prefix(32))) else { return false }
        return (try? data.write(to: dir.appending(path: "b/\(h)"), options: .atomic)) != nil
    }

    static func prune(keeping: Set<String>) {
        let b = dir.appending(path: "b")
        for name in (try? FileManager.default.contentsOfDirectory(atPath: b.path)) ?? [] where !keeping.contains(name) {
            try? FileManager.default.removeItem(at: b.appending(path: name))
        }
    }

    /// Local file for a logical path, if downloaded.
    static func url(_ path: String) -> URL? {
        guard let h = manifest?.files[path]?.h, has(h) else { return nil }
        return dir.appending(path: "b/\(h)")
    }

    /// Data file: downloaded copy, else the compressed copy bundled with the app.
    static func data(_ path: String) -> Data? {
        if let url = url(path), let d = try? Data(contentsOf: url) { return d }
        let name = path.replacingOccurrences(of: "/", with: "_")
        guard let seed = Bundle.main.url(forResource: name, withExtension: "lzfse"),
              let packed = try? Data(contentsOf: seed) else { return nil }
        return try? (packed as NSData).decompressed(using: .lzfse) as Data
    }
}

/// Image from the content store with the bundled mini asset as the floor. Redraws when the full one lands.
struct ContentImage: View {
    let path: String
    let fallback: String
    init(_ path: String, fallback: String) { self.path = path; self.fallback = fallback }
    var body: some View {
        if let ui = ContentStore.shared.image(path) { Image(uiImage: ui).resizable() }
        else { Image(fallback).resizable() }
    }
    func interpolation(_ i: Image.Interpolation) -> some View {
        Group {
            if let ui = ContentStore.shared.image(path) { Image(uiImage: ui).resizable().interpolation(i) }
            else { Image(fallback).resizable().interpolation(i) }
        }
    }
}
