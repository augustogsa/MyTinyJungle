import CryptoKit
import DeviceCheck
import Foundation

/// App Attest: proves to api.mytinyjungle.com that this is the genuine app on a real iPhone.
/// Once per install and account: server challenge → Secure Enclave key → Apple attestation → server verifies.
nonisolated enum AppAttest {
    private static var doneKey: String { "attest.done.\(JungleAPI.shared.userID ?? "")" }

    static func ensure() async {
        let service = DCAppAttestService.shared
        guard service.isSupported, JungleAPI.shared.hasSession, !UserDefaults.standard.bool(forKey: doneKey) else { return }
        struct Challenge: Decodable { let challenge: String }
        struct Body: Encodable { let keyId: String; let attestation: String }
        do {
            let c: Challenge = try await JungleAPI.shared.send("POST", "/v1/attest/challenge", body: JungleAPI.Empty())
            guard let challenge = Data(base64Encoded: c.challenge) else { return }
            let keyID = try await service.generateKey()
            let attestation = try await service.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: challenge)))
            let _: JungleAPI.OK = try await JungleAPI.shared.send("POST", "/v1/attest", body: Body(keyId: keyID, attestation: attestation.base64EncodedString()))
            UserDefaults.standard.set(true, forKey: doneKey)
        } catch {
            // Not fatal: retried on the next launch.
        }
    }
}
