import Foundation
import Observation

@Observable
final class JungleSettings {
    static let shared = JungleSettings()
    private let defaults = UserDefaults.standard

    var southernHemisphere: Bool { didSet { defaults.set(southernHemisphere, forKey: "south") } }
    var hasCats: Bool { didSet { defaults.set(hasCats, forKey: "cats") } }
    var hasDogs: Bool { didSet { defaults.set(hasDogs, forKey: "dogs") } }
    var hasKids: Bool { didSet { defaults.set(hasKids, forKey: "kids") } }
    var ownerName: String { didSet { defaults.set(ownerName, forKey: "owner") } }

    init() {
        southernHemisphere = defaults.bool(forKey: "south")
        hasCats = defaults.bool(forKey: "cats")
        hasDogs = defaults.bool(forKey: "dogs")
        hasKids = defaults.bool(forKey: "kids")
        ownerName = defaults.string(forKey: "owner") ?? ""
    }
}
