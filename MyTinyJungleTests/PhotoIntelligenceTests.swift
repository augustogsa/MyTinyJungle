import Testing
import UIKit
@testable import MyTinyJungle

/// Runs the on-device vision on real plant photos (fixtures folder passed via MTJ_PHOTOS) and prints what it sees.
struct PhotoIntelligenceTests {
    @Test func realPhotos() async throws {
        let dir = ProcessInfo.processInfo.environment["MTJ_PHOTOS"] ?? "/private/tmp/claude-501/-Users-augusto-Documents-SimpleAppsComapny-MyDigitalMagnets/82fbff5b-b8f5-468e-a2b4-5011e8c4821f/scratchpad/plants"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return }
        for f in files.sorted() where f.hasSuffix(".jpg") {
            guard let img = UIImage(contentsOfFile: dir + "/" + f) else { print("MTJ \(f): unreadable"); continue }
            let r = await PlantVision.read(img)
            let c = PlantIdentifier.candidates(from: r).prefix(3).map { "\($0.species.id)" }
            let labels = r.labels.prefix(5).map { "\($0.0):\(String(format: "%.2f", $0.1))" }
            print("MTJ \(f) | ids=\(c) | health=\(r.health) g=\(String(format: "%.2f", r.greenShare)) y=\(String(format: "%.2f", r.yellowShare)) b=\(String(format: "%.2f", r.brownShare)) | \(labels)")
        }
    }
}
