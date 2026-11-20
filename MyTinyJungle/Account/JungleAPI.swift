import Foundation
import Security
import UIKit

/// Client for api.mytinyjungle.com (contract: Server/openapi.yaml). One account across iPhone, iPad and Android.
/// Access tokens live in memory; the rotating refresh token lives in the Keychain (this device only).
actor JungleAPI {
    static let shared = JungleAPI()
    static let base = URL(string: "https://api.mytinyjungle.com")!

    enum APIError: Error, Equatable { case signedOut, http(Int, String), offline }

    struct Tokens: Codable { var userId: String; var accessToken: String; var refreshToken: String; var expiresIn: Int }

    private var access: (token: String, expires: Date)?
    private var refreshing: Task<String, Error>?
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        c.waitsForConnectivity = false
        c.httpAdditionalHeaders = ["User-Agent": "MyTinyJungle-iOS/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")"]
        return URLSession(configuration: c)
    }()

    nonisolated var hasSession: Bool { SessionStore.refreshToken != nil }
    nonisolated var userID: String? { SessionStore.userID }

    /// Stable per install; survives sign-out so the server sees one device.
    nonisolated static var deviceID: String {
        if let id = SessionStore.read("device") { return id }
        let id = UUID().uuidString.lowercased()
        SessionStore.write("device", id)
        return id
    }

    // MARK: Auth

    func signIn(provider: String, idToken: String, name: String?) async throws {
        struct Body: Encodable { let provider, idToken: String; let name: String?; let deviceId, platform: String; let model, appVersion: String }
        let model = await UIDevice.current.model
        let body = Body(provider: provider, idToken: idToken, name: name, deviceId: Self.deviceID, platform: "ios", model: model,
                        appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
        let t: Tokens = try await send("POST", "/v1/auth/signin", body: body, auth: false)
        adopt(t)
    }

    func link(provider: String, idToken: String) async throws {
        struct Body: Encodable { let provider, idToken: String }
        let _: OK = try await send("POST", "/v1/auth/link", body: Body(provider: provider, idToken: idToken))
    }

    func signOut() async {
        let _: OK? = try? await send("POST", "/v1/auth/signout", body: Empty())
        clear()
    }

    func deleteAccount() async throws {
        let _: OK = try await send("DELETE", "/v1/me", body: Optional<Empty>.none)
        clear()
    }

    func clear() {
        access = nil
        SessionStore.clear()
    }

    private func adopt(_ t: Tokens) {
        access = (t.accessToken, Date().addingTimeInterval(TimeInterval(t.expiresIn - 60)))
        SessionStore.save(userID: t.userId, refresh: t.refreshToken)
    }

    /// Concurrent callers share one refresh: the task is claimed before any suspension point.
    private func accessToken() async throws -> String {
        if let a = access, a.expires > Date() { return a.token }
        if let r = refreshing { return try await r.value }
        let task = Task<String, Error> {
            guard let refresh = SessionStore.refreshToken else { throw APIError.signedOut }
            struct Body: Encodable { let refreshToken: String }
            do {
                let t: Tokens = try await self.send("POST", "/v1/auth/refresh", body: Body(refreshToken: refresh), auth: false)
                self.adopt(t)
                return t.accessToken
            } catch APIError.http(401, _) {
                self.clear()
                throw APIError.signedOut
            }
        }
        refreshing = task
        defer { refreshing = nil }
        return try await task.value
    }

    // MARK: Transport

    struct Empty: Codable {}
    struct OK: Decodable { var ok: Bool? }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { d, enc in
            var c = enc.singleValueContainer()
            try c.encode(JungleAPI.iso.string(from: d))
        }
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let date = JungleAPI.iso.date(from: s) ?? JungleAPI.isoPlain.date(from: s) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: dec.codingPath, debugDescription: "date \(s)"))
        }
        return d
    }()

    nonisolated(unsafe) static let iso: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
    nonisolated(unsafe) static let isoPlain = ISO8601DateFormatter()

    func send<B: Encodable, R: Decodable>(_ method: String, _ path: String, query: [URLQueryItem] = [], body: B?, auth: Bool = true) async throws -> R {
        var data: Data?
        if let body { data = try Self.encoder.encode(body) }
        return try await raw(method, path, query: query, body: data, contentType: "application/json", auth: auth, decode: R.self)
    }

    func get<R: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> R {
        try await raw("GET", path, query: query, body: nil, contentType: nil, auth: true, decode: R.self)
    }

    /// Posts a JSON body built elsewhere (diagnostics).
    func postRaw(_ path: String, _ json: Data) async throws {
        let _: OK = try await raw("POST", path, query: [], body: json, contentType: "application/json", auth: true, decode: OK.self)
    }

    func upload(_ path: String, data: Data, contentType: String) async throws {
        let _: OK = try await raw("PUT", path, query: [], body: data, contentType: contentType, auth: true, decode: OK.self)
    }

    func download(_ path: String) async throws -> Data? {
        var req = URLRequest(url: Self.base.appending(path: path))
        req.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        let (d, res) = try await session.data(for: req)
        let code = (res as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { return nil }
        guard code == 200 else { throw APIError.http(code, "download") }
        return d
    }

    private func raw<R: Decodable>(_ method: String, _ path: String, query: [URLQueryItem], body: Data?, contentType: String?, auth: Bool, decode: R.Type) async throws -> R {
        try Self.decoder.decode(R.self, from: try await rawData(method, path, query: query, body: body, contentType: contentType, auth: auth))
    }

    /// Same as `send`, but hands back the response bytes (for the brain result cache).
    func sendData<B: Encodable>(_ method: String, _ path: String, body: B) async throws -> Data {
        try await rawData(method, path, query: [], body: try Self.encoder.encode(body), contentType: "application/json", auth: true)
    }

    private func request(_ method: String, _ path: String, query: [URLQueryItem], body: Data?, contentType: String?, auth: Bool, accept: String? = nil) async throws -> URLRequest {
        var comps = URLComponents(url: Self.base.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.httpBody = body
        if let contentType { req.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if let accept { req.setValue(accept, forHTTPHeaderField: "Accept") }
        if auth { req.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization") }
        // Install id (no account data): the server picks brain experiment variants by it.
        req.setValue(Self.deviceHeader, forHTTPHeaderField: "X-MTJ-Device")
        return req
    }

    nonisolated static let deviceHeader = deviceID

    /// GET with If-None-Match. Returns the status (200 or 304), body and ETag.
    func getConditional(_ path: String, query: [URLQueryItem] = [], etag: String?, auth: Bool = false) async throws -> (Int, Data, String?) {
        var req = try await request("GET", path, query: query, body: nil, contentType: nil, auth: auth)
        if let etag { req.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let data: Data, res: URLResponse
        do { (data, res) = try await session.data(for: req) } catch { throw APIError.offline }
        let http = res as? HTTPURLResponse, code = http?.statusCode ?? 0
        guard code == 200 || code == 304 else { throw APIError.http(code, "http_\(code)") }
        return (code, data, http?.value(forHTTPHeaderField: "ETag"))
    }

    private func rawData(_ method: String, _ path: String, query: [URLQueryItem], body: Data?, contentType: String?, auth: Bool, retried: Bool = false, busyRetried: Bool = false) async throws -> Data {
        let req = try await request(method, path, query: query, body: body, contentType: contentType, auth: auth)
        let data: Data, res: URLResponse
        do { (data, res) = try await session.data(for: req) } catch { throw APIError.offline }
        let code = (res as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 && auth && !retried {
            access = nil
            return try await rawData(method, path, query: query, body: body, contentType: contentType, auth: auth, retried: true, busyRetried: busyRetried)
        }
        // The server is busy: wait 3 s and try once more.
        if code == 503 && !busyRetried {
            try? await Task.sleep(for: .seconds(3))
            return try await rawData(method, path, query: query, body: body, contentType: contentType, auth: auth, retried: retried, busyRetried: true)
        }
        guard (200..<300).contains(code) else {
            let reason = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "http_\(code)"
            throw APIError.http(code, reason)
        }
        return data
    }

    /// One server-sent event: `event:` name (default "message") and its joined `data:` lines.
    struct Event: Sendable { var name: String; var data: Data }
    enum Streamed: Sendable { case json(Data), events([Event]) }

    /// POST that prefers `text/event-stream` and falls back to plain JSON when the server answers that way.
    /// `onEvent` sees each event as it lands, so answers can show before the stream ends.
    func stream<B: Encodable>(_ path: String, body: B, retried: Bool = false, onEvent: @Sendable (Event) async -> Void = { _ in }) async throws -> Streamed {
        let req = try await request("POST", path, query: [], body: try Self.encoder.encode(body), contentType: "application/json", auth: true,
                                    accept: "text/event-stream, application/json;q=0.9")
        let bytes: URLSession.AsyncBytes, res: URLResponse
        do { (bytes, res) = try await session.bytes(for: req) } catch { throw APIError.offline }
        let http = res as? HTTPURLResponse, code = http?.statusCode ?? 0
        if code == 401 && !retried { access = nil; return try await stream(path, body: body, retried: true, onEvent: onEvent) }
        let isSSE = (http?.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased().hasPrefix("text/event-stream")
        guard (200..<300).contains(code), isSSE else {
            var data = Data()
            do { for try await b in bytes { data.append(b) } } catch { throw APIError.offline }
            guard (200..<300).contains(code) else {
                throw APIError.http(code, (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "http_\(code)")
            }
            return .json(data)
        }
        var out: [Event] = [], name = "message", lines: [String] = []
        func flush() async {
            defer { name = "message"; lines = [] }
            guard !lines.isEmpty else { return }
            let e = Event(name: name, data: Data(lines.joined(separator: "\n").utf8))
            out.append(e); await onEvent(e)
        }
        do {
            for try await line in bytes.lines {
                if line.isEmpty { await flush(); continue }
                if line.hasPrefix(":") { continue }
                let (field, value) = Self.sseField(line)
                if field == "event" { name = value } else if field == "data" { lines.append(value) }
                if name == "done" { break }
            }
        } catch { if out.isEmpty { throw APIError.offline } }
        await flush()
        return .events(out)
    }

    /// `field: value` with the single leading space after the colon dropped (SSE spec).
    nonisolated static func sseField(_ line: String) -> (String, String) {
        guard let i = line.firstIndex(of: ":") else { return (line, "") }
        var v = line[line.index(after: i)...]
        if v.first == " " { v = v.dropFirst() }
        return (String(line[..<i]), String(v))
    }
}

// MARK: - API models

extension JungleAPI {
    struct Entitlement: Codable, Hashable { var store: String; var productId: String; var expiresAt: Date?; var status: String }
    struct Device: Codable, Identifiable, Hashable { var id: String; var platform: String; var model: String?; var appVersion: String?; var lastSeenAt: Date; var thisDevice: Bool }
    struct Me: Codable { var id: String; var email: String?; var displayName: String?; var providers: [String]; var devices: [Device]; var plus: Bool; var entitlements: [Entitlement] }
    struct Member: Codable, Hashable { var userId: String; var displayName: String?; var role: String; var until: Date? }
    struct Jungle: Codable, Identifiable { var id: String; var name: String; var isPersonal: Bool; var ownerId: String; var role: String; var until: Date?; var members: [Member] }
    struct Invite: Codable { var code: String; var url: String; var expiresAt: Date }
    struct EntitlementsResponse: Codable { var plus: Bool; var entitlements: [Entitlement] }

    func me() async throws -> Me { try await get("/v1/me") }
    func jungles() async throws -> [Jungle] {
        struct R: Decodable { var jungles: [Jungle] }
        let r: R = try await get("/v1/jungles")
        return r.jungles
    }
    func setPushToken(_ token: String) async {
        struct B: Encodable { let token: String }
        let _: OK? = try? await send("PUT", "/v1/me/push-token", body: B(token: token))
    }
    func updateName(_ name: String) async {
        struct B: Encodable { let displayName: String }
        let _: OK? = try? await send("PATCH", "/v1/me", body: B(displayName: String(name.prefix(60))))
    }
    func postAppleTransaction(_ jws: String) async throws -> EntitlementsResponse {
        struct B: Encodable { let signedTransaction: String }
        return try await send("POST", "/v1/store/apple/transactions", body: B(signedTransaction: jws))
    }
}

// MARK: - Keychain

nonisolated enum SessionStore {
    private static let service = "com.simpleappscompany.mytinyjungle.session"

    static var refreshToken: String? { read("refresh") }
    static var userID: String? { read("user") }

    static func save(userID: String, refresh: String) {
        write("user", userID)
        write("refresh", refresh)
    }

    static func clear() {
        delete("refresh")
        delete("user")
    }

    static func read(_ account: String) -> String? {
        var out: AnyObject?
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account,
                                  kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func write(_ account: String, _ value: String) {
        delete(account)
        // ThisDeviceOnly: a restored backup on another phone must sign in again instead of reusing this session.
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account,
                                  kSecValueData: Data(value.utf8), kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        SecItemAdd(q as CFDictionary, nil)
    }

    private static func delete(_ account: String) {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account] as CFDictionary)
    }
}
