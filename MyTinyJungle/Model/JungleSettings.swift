import Foundation
import Observation

@Observable
final class JungleSettings {
    static let shared = JungleSettings()
    private let defaults = UserDefaults.standard

    /// Derived from where you live (or your region until you tell us).
    var southernHemisphere: Bool { Climate.shared.isSouth }
    var hasCats: Bool { didSet { defaults.set(hasCats, forKey: "cats") } }
    var hasDogs: Bool { didSet { defaults.set(hasDogs, forKey: "dogs") } }
    var hasKids: Bool { didSet { defaults.set(hasKids, forKey: "kids") } }
    var ownerName: String { didSet { defaults.set(ownerName, forKey: "owner") } }

    init() {
        hasCats = defaults.bool(forKey: "cats")
        hasDogs = defaults.bool(forKey: "dogs")
        hasKids = defaults.bool(forKey: "kids")
        ownerName = defaults.string(forKey: "owner") ?? ""
    }
}
