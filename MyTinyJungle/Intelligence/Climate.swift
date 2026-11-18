import Foundation
import CoreLocation
import Observation

/// Where the jungle lives: place, climate (Köppen + hardiness zone), seasons, home conditions and local weather.
/// Location is rounded to ~10 km before it leaves the phone; weather and climate come from Open-Meteo (no account, no key).
@Observable
final class Climate {
    static let shared = Climate()

    struct Profile: Codable, Equatable {
        var place: String
        var country: String
        var lat: Double
        var lon: Double
        var monthlyTemp: [Double] = []      // °C, Jan…Dec
        var monthlyRain: [Double] = []      // mm, Jan…Dec
        var coldestNight: Double?           // average yearly minimum, °C
        var fetched: Date?
    }
    struct Day: Codable, Hashable { let date: Date; let tMin: Double; let tMax: Double; let rain: Double; let humidity: Double? }
    enum HomeAir: Int, Codable, CaseIterable { case dry, normal, humid
        var label: String { switch self { case .dry: "On the dry side"; case .normal: "Comfortable"; case .humid: "Quite humid" } }
    }

    private let d = UserDefaults.standard
    var profile: Profile? { didSet { save(profile, "climate.profile") } }
    var forecast: [Day] = [] { didSet { save(forecast, "climate.forecast") } }
    var forecastFetched: Date? { didSet { d.set(forecastFetched, forKey: "climate.forecastAt") } }
    var heating: Bool { didSet { d.set(heating, forKey: "home.heating") } }
    var aircon: Bool { didSet { d.set(aircon, forKey: "home.ac") } }
    var drafts: Bool { didSet { d.set(drafts, forKey: "home.drafts") } }
    var homeAir: HomeAir { didSet { d.set(homeAir.rawValue, forKey: "home.air") } }
    var growsOutside: Bool { didSet { d.set(growsOutside, forKey: "home.outside") } }
    var busy = false
    var lastError: String?

    init() {
        heating = d.object(forKey: "home.heating") as? Bool ?? true
        aircon = d.bool(forKey: "home.ac")
        drafts = d.bool(forKey: "home.drafts")
        homeAir = HomeAir(rawValue: d.integer(forKey: "home.air")) ?? .normal
        if d.object(forKey: "home.air") == nil { homeAir = .normal }
        growsOutside = d.bool(forKey: "home.outside")
        profile = load("climate.profile")
        forecast = load("climate.forecast") ?? []
        forecastFetched = d.object(forKey: "climate.forecastAt") as? Date
    }
    private func save<T: Encodable>(_ v: T?, _ k: String) { d.set(v.flatMap { try? JSONEncoder().encode($0) }, forKey: k) }
    private func load<T: Decodable>(_ k: String) -> T? { d.data(forKey: k).flatMap { try? JSONDecoder().decode(T.self, from: $0) } }

    // MARK: Derived climate

    var isSouth: Bool {
        if let p = profile { return p.lat < 0 }
        let south: Set<String> = ["AU", "NZ", "BR", "AR", "CL", "ZA", "UY", "PY", "PE", "BO", "NA", "BW", "MZ", "MG", "ZW", "LS", "SZ", "FJ"]
        return south.contains(Locale.current.region?.identifier ?? "")
    }
    var hasClimate: Bool { (profile?.monthlyTemp.count ?? 0) == 12 }

    /// Köppen–Geiger code from monthly normals (Peel, Finlayson & McMahon 2007).
    var koppen: String? {
        guard let p = profile, p.monthlyTemp.count == 12, p.monthlyRain.count == 12 else { return nil }
        let T = p.monthlyTemp, P = p.monthlyRain
        let mat = T.reduce(0, +) / 12, map = P.reduce(0, +)
        let hot = T.max()!, cold = T.min()!
        let summer = isSouth ? [9, 10, 11, 0, 1, 2] : [3, 4, 5, 6, 7, 8]
        let winter = (0..<12).filter { !summer.contains($0) }
        let pS = summer.map { P[$0] }, pW = winter.map { P[$0] }
        let summerRain = pS.reduce(0, +)
        let thr: Double = summerRain >= 0.7 * map ? 2 * mat + 28 : (map - summerRain) >= 0.7 * map ? 2 * mat : 2 * mat + 14
        if map < 10 * thr {
            return (map < 5 * thr ? "BW" : "BS") + (mat >= 18 ? "h" : "k")
        }
        if cold >= 18 {
            let dry = P.min()!
            return dry >= 60 ? "Af" : dry >= 100 - map / 25 ? "Am" : "Aw"
        }
        if hot <= 10 { return hot > 0 ? "ET" : "EF" }
        let second: String = (pS.min()! < 40 && pS.min()! < pW.max()! / 3) ? "s" : (pW.min()! < pS.max()! / 10) ? "w" : "f"
        let warmMonths = T.filter { $0 >= 10 }.count
        let third: String = hot >= 22 ? "a" : warmMonths >= 4 ? "b" : cold < -38 ? "d" : "c"
        return (cold > 0 ? "C" : "D") + second + third
    }

    /// 3D art for the local landscape.
    var biomeIcon: Icon3D {
        guard let k = koppen else { return .globe }
        switch k.prefix(1) {
        case "A": return .palm
        case "B": return .cactus
        case "C": return k.hasPrefix("Cs") ? .sunny : .tree
        case "D": return .pine
        default: return .summit
        }
    }

    var biome: String {
        guard let k = koppen else { return "Not set yet" }
        switch k {
        case "Af": return "Tropical rainforest"
        case "Am": return "Tropical monsoon"
        case "Aw": return "Tropical savanna"
        case "BWh": return "Hot desert"
        case "BWk": return "Cold desert"
        case "BSh": return "Hot semi-arid"
        case "BSk": return "Cold semi-arid"
        case let c where c.hasPrefix("Cs"): return "Mediterranean"
        case "Cfa", "Cwa": return "Humid subtropical"
        case "Cwb", "Cwc": return "Subtropical highland"
        case let c where c.hasPrefix("Cf"): return "Temperate oceanic"
        case let c where c.hasPrefix("D"): return "Continental"
        case "ET": return "Tundra and alpine"
        default: return "Polar"
        }
    }
    var isTropical: Bool { koppen?.hasPrefix("A") ?? false }
    var isDry: Bool { koppen?.hasPrefix("B") ?? false }

    /// USDA hardiness zone from the average coldest night of the year.
    var hardinessZone: String? {
        guard let c = profile?.coldestNight else { return nil }
        let f = c * 9 / 5 + 32
        let z = Int(((f + 60) / 10).rounded(.down)) + 1
        let half = (f + 60).truncatingRemainder(dividingBy: 10) < 5 ? "a" : "b"
        return "\(min(13, max(1, z)))\(half)"
    }

    /// Mean outdoor temperature for the month of `date`.
    func monthTemp(_ date: Date = Date()) -> Double? {
        guard let p = profile, p.monthlyTemp.count == 12 else { return nil }
        return p.monthlyTemp[Calendar.current.component(.month, from: date) - 1]
    }

    // MARK: Seasons

    enum Phase { case spring, summer, autumn, winter }
    /// Season from the real climate: tropics follow the rains, mild places have no true winter.
    func phase(_ date: Date = Date()) -> Phase {
        let m = Calendar.current.component(.month, from: date) - 1
        if let p = profile, p.monthlyTemp.count == 12, p.monthlyRain.count == 12, isTropical {
            let wet = p.monthlyRain[m] >= p.monthlyRain.sorted()[6]
            return wet ? .summer : .spring
        }
        var mm = m + 1
        if isSouth { mm = (mm + 5) % 12 + 1 }
        switch mm { case 3...5: return .spring; case 6...8: return .summer; case 9...11: return .autumn; default: return .winter }
    }
    func isWinter(_ date: Date = Date()) -> Bool {
        if isTropical { return false }
        if let t = monthTemp(date), hasClimate {
            let p = profile!
            let coldest3 = p.monthlyTemp.sorted().prefix(3).last!
            return t <= max(10, coldest3)  && phase(date) != .summer
        }
        return phase(date) == .winter
    }
    func isGrowing(_ date: Date = Date()) -> Bool {
        if isTropical { return true }
        if let t = monthTemp(date), hasClimate, t < 8 { return false }
        let ph = phase(date)
        if ph == .spring || ph == .summer { return true }
        if ph == .autumn {
            var mm = Calendar.current.component(.month, from: date)
            if isSouth { mm = (mm + 5) % 12 + 1 }
            return mm == 9
        }
        return false
    }
    func isPeakSummer(_ date: Date = Date()) -> Bool {
        if let t = monthTemp(date), hasClimate { return t >= max(20, profile!.monthlyTemp.max()! - 2) }
        return phase(date) == .summer
    }

    // MARK: Water factors

    /// Indoor drying multiplier from the home and the outside climate (below 1 dries faster).
    func indoorFactor(_ date: Date = Date()) -> Double {
        var f = 1.0
        let winter = isWinter(date)
        if winter && heating { f *= 0.88 }
        if !winter && aircon && isPeakSummer(date) { f *= 1.05 }
        switch homeAir { case .dry: f *= 0.9; case .humid: f *= 1.1; case .normal: break }
        if let t = monthTemp(date) { if t >= 26 { f *= 0.9 } else if t >= 22 { f *= 0.95 } }
        if isDry { f *= 0.93 }
        return f
    }

    /// Outdoor drying multiplier from this week's forecast, or the month's normal.
    func outdoorFactor(_ date: Date = Date()) -> Double? {
        let days = forecast.filter { abs($0.date.timeIntervalSince(date)) < 3 * 86_400 }
        let t = days.isEmpty ? monthTemp(date) : days.map { ($0.tMax + $0.tMin) / 2 }.reduce(0, +) / Double(days.count)
        guard let t else { return nil }
        var f: Double = t >= 28 ? 0.55 : t >= 22 ? 0.7 : t >= 15 ? 0.85 : t >= 8 ? 1.1 : 1.4
        if let h = days.compactMap(\.humidity).first, h < 40 { f *= 0.85 }
        return f
    }

    /// Rain that fell in the last two days (mm).
    func recentRain(_ now: Date = Date()) -> Double {
        forecast.filter { $0.date <= now && now.timeIntervalSince($0.date) < 2 * 86_400 }.map(\.rain).reduce(0, +)
    }
    func upcoming(_ now: Date = Date(), days: Int = 3) -> [Day] {
        let start = Calendar.current.startOfDay(for: now)
        return forecast.filter { $0.date >= start && $0.date.timeIntervalSince(start) < Double(days) * 86_400 }
    }

    // MARK: Units

    static var metric: Bool { Locale.current.measurementSystem == .metric || Locale.current.measurementSystem == .uk }
    static func temp(_ c: Double) -> String {
        Measurement(value: c, unit: UnitTemperature.celsius).converted(to: metricTemp ? .celsius : .fahrenheit)
            .formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0))))
    }
    static var metricTemp: Bool { Locale.current.measurementSystem != .us }
    static func rain(_ mm: Double) -> String {
        metric ? "\(Int(mm.rounded())) mm" : String(format: "%.1f in", mm / 25.4)
    }
    static func tempRange(_ lo: Double, _ hi: Double) -> String { "\(temp(lo))–\(temp(hi))" }

    // MARK: Fetching

    /// Look up a place typed by the person ("Lisbon", "São Paulo, Brazil").
    @MainActor func setPlace(named name: String) async {
        busy = true; lastError = nil
        defer { busy = false }
        guard let mark = try? await CLGeocoder().geocodeAddressString(name).first, let loc = mark.location else {
            lastError = "I couldn't find that place. Try a nearby city."
            return
        }
        await set(loc, mark: mark)
    }

    @MainActor func set(_ loc: CLLocation, mark: CLPlacemark? = nil) async {
        busy = true; lastError = nil
        defer { busy = false }
        var m = mark
        if m == nil { m = try? await CLGeocoder().reverseGeocodeLocation(loc).first }
        let lat = (loc.coordinate.latitude * 10).rounded() / 10, lon = (loc.coordinate.longitude * 10).rounded() / 10
        profile = Profile(place: m?.locality ?? m?.administrativeArea ?? m?.name ?? "Your area", country: m?.isoCountryCode ?? "", lat: lat, lon: lon)
        await refreshClimate(force: true)
        await refreshForecast(force: true)
    }

    @MainActor func refreshClimate(force: Bool = false) async {
        guard let p = profile, force || !hasClimate else { return }
        let y = Calendar.current.component(.year, from: Date()) - 1
        var c = URLComponents(string: "https://archive-api.open-meteo.com/v1/archive")!
        c.queryItems = [.init(name: "latitude", value: "\(p.lat)"), .init(name: "longitude", value: "\(p.lon)"),
                        .init(name: "start_date", value: "\(y - 9)-01-01"), .init(name: "end_date", value: "\(y)-12-31"),
                        .init(name: "daily", value: "temperature_2m_mean,temperature_2m_min,precipitation_sum"), .init(name: "timezone", value: "auto")]
        struct R: Decodable { struct D: Decodable { let time: [String]; let temperature_2m_mean: [Double?]; let temperature_2m_min: [Double?]; let precipitation_sum: [Double?] }; let daily: D }
        guard let (data, _) = try? await URLSession.shared.data(from: c.url!), let r = try? JSONDecoder().decode(R.self, from: data) else {
            lastError = "Couldn't reach the weather service. I'll try again later."
            return
        }
        var tSum = [Double](repeating: 0, count: 12), tN = [Double](repeating: 0, count: 12), rain = [Double](repeating: 0, count: 12)
        var yearMin: [Int: Double] = [:]
        for (i, day) in r.daily.time.enumerated() {
            let parts = day.split(separator: "-"); guard parts.count == 3, let yy = Int(parts[0]), let mm = Int(parts[1]) else { continue }
            if let t = r.daily.temperature_2m_mean[i] { tSum[mm - 1] += t; tN[mm - 1] += 1 }
            if let pr = r.daily.precipitation_sum[i] { rain[mm - 1] += pr }
            if let lo = r.daily.temperature_2m_min[i] { yearMin[yy] = min(yearMin[yy] ?? lo, lo) }
        }
        let years = Double(max(1, Set(r.daily.time.map { $0.prefix(4) }).count))
        var np = p
        np.monthlyTemp = (0..<12).map { tN[$0] > 0 ? tSum[$0] / tN[$0] : 0 }
        np.monthlyRain = rain.map { $0 / years }
        np.coldestNight = yearMin.isEmpty ? nil : yearMin.values.reduce(0, +) / Double(yearMin.count)
        np.fetched = Date()
        profile = np
    }

    @MainActor func refreshForecast(force: Bool = false) async {
        guard let p = profile else { return }
        if !force, let f = forecastFetched, Date().timeIntervalSince(f) < 3 * 3600 { return }
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [.init(name: "latitude", value: "\(p.lat)"), .init(name: "longitude", value: "\(p.lon)"),
                        .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_sum,relative_humidity_2m_mean"),
                        .init(name: "past_days", value: "2"), .init(name: "forecast_days", value: "5"), .init(name: "timezone", value: "auto")]
        struct R: Decodable { struct D: Decodable { let time: [String]; let temperature_2m_max: [Double?]; let temperature_2m_min: [Double?]; let precipitation_sum: [Double?]; let relative_humidity_2m_mean: [Double?]? }; let daily: D }
        guard let (data, _) = try? await URLSession.shared.data(from: c.url!), let r = try? JSONDecoder().decode(R.self, from: data) else { return }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        forecast = r.daily.time.enumerated().compactMap { i, s in
            guard let date = fmt.date(from: s), let lo = r.daily.temperature_2m_min[i], let hi = r.daily.temperature_2m_max[i] else { return nil }
            return Day(date: date, tMin: lo, tMax: hi, rain: r.daily.precipitation_sum[i] ?? 0, humidity: r.daily.relative_humidity_2m_mean?[i] ?? nil)
        }
        forecastFetched = Date()
    }

    /// Coarse "where am I" with the person's permission.
    @MainActor func useMyLocation() async {
        busy = true; lastError = nil
        defer { busy = false }
        guard let loc = await LocationOnce.shared.request() else {
            lastError = "Location is off. Type your city instead, that works just as well."
            return
        }
        await set(loc)
    }
}

/// One-shot, reduced-accuracy location request.
@MainActor final class LocationOnce: NSObject, CLLocationManagerDelegate {
    static let shared = LocationOnce()
    private let m = CLLocationManager()
    private var cont: CheckedContinuation<CLLocation?, Never>?
    override init() { super.init(); m.delegate = self; m.desiredAccuracy = kCLLocationAccuracyReduced }
    func request() async -> CLLocation? {
        await withCheckedContinuation { c in
            cont?.resume(returning: nil)
            cont = c
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(12))
                self?.finish(nil)
            }
            switch m.authorizationStatus {
            case .notDetermined: m.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways: m.requestLocation()
            default: finish(nil)
            }
        }
    }
    private func finish(_ l: CLLocation?) { cont?.resume(returning: l); cont = nil }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
            case .denied, .restricted: finish(nil)
            default: break
            }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let l = locations.last
        Task { @MainActor in finish(l) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finish(nil) }
    }
}

// MARK: Weather alerts and climate advice

struct WeatherAlert: Identifiable, Hashable {
    enum Kind { case frost, cold, heat, storm, dry }
    let kind: Kind
    let title: String
    let detail: String
    let plantNames: [String]
    var id: String { title }
    var icon: Icon3D {
        switch kind { case .frost: .frost; case .cold: .cold; case .heat: .hot; case .storm: .storm; case .dry: .sunny }
    }
    var symbol: String {
        switch kind { case .frost: "snowflake"; case .cold: "thermometer.snowflake"; case .heat: "sun.max.trianglebadge.exclamationmark"; case .storm: "cloud.heavyrain"; case .dry: "drop.triangle" }
    }
}

extension Climate {
    /// Alerts for plants that live outside (or on the balcony) from the next three days.
    func alerts(for plants: [Plant], now: Date = Date()) -> [WeatherAlert] {
        let outside = plants.filter { !$0.isArchived && $0.isOutdoor }
        let days = upcoming(now)
        guard !outside.isEmpty, !days.isEmpty else { return [] }
        let low = days.map(\.tMin).min()!, high = days.map(\.tMax).max()!, rain = days.map(\.rain).max()!
        var out: [WeatherAlert] = []
        func names(_ ps: [Plant]) -> String { ListFormatter.localizedString(byJoining: ps.prefix(3).map(\.name)) + (ps.count > 3 ? " and friends" : "") }
        let frosty = outside.filter { low < min(2, $0.species?.tempMin ?? 5) }
        if low <= 1, !frosty.isEmpty {
            out.append(.init(kind: .frost, title: "Frost coming (\(Climate.temp(low)))",
                             detail: "Please bring \(names(frosty)) inside or wrap them in fleece tonight. Frost hurts tender leaves overnight.", plantNames: frosty.map(\.name)))
        } else {
            let chilly = outside.filter { low < ($0.species?.tempMin ?? 5) }
            if !chilly.isEmpty {
                out.append(.init(kind: .cold, title: "Chilly nights (\(Climate.temp(low)))",
                                 detail: "\(names(chilly)) like it warmer than that. A sheltered corner or a night indoors will keep them cosy.", plantNames: chilly.map(\.name)))
            }
        }
        let hot = outside.filter { high > ($0.species?.tempMax ?? 32) }
        if !hot.isEmpty {
            out.append(.init(kind: .heat, title: "Heat on the way (\(Climate.temp(high)))",
                             detail: "Water \(names(hot)) early in the morning and give them some afternoon shade. Pots dry out fast now.", plantNames: hot.map(\.name)))
        }
        if rain >= 20 {
            let soggy = outside.filter { $0.species?.waterStyle == .dry || !$0.potHasDrainage }
            if !soggy.isEmpty {
                out.append(.init(kind: .storm, title: "Heavy rain (\(Climate.rain(rain)))",
                                 detail: "\(names(soggy)) hate wet feet. Tuck them under cover or tip out saucers after the rain.", plantNames: soggy.map(\.name)))
            }
        } else if days.allSatisfy({ $0.rain < 1 }) && high >= 25 {
            out.append(.init(kind: .dry, title: "Dry, warm days ahead", detail: "No rain in sight. Check outdoor pots every morning.", plantNames: outside.map(\.name)))
        }
        return out
    }

    /// How a species fits this place, in warm words.
    func fit(_ s: Species) -> String? {
        guard let p = profile else { return nil }
        let place = p.place
        if let c = p.coldestNight {
            if s.tempMin <= c - 2 { return "Hardy enough to live outside all year in \(place) (zone \(hardinessZone ?? "?"))." }
            if s.tempMin <= c + 6 { return "Can spend most of the year outside in \(place); bring it in on the coldest nights below \(Climate.temp(s.tempMin))." }
        }
        if let w = monthTemp(Date()) , w < s.tempMin { return "It's cooler outside than it likes right now. Keep it indoors until nights stay above \(Climate.temp(s.tempMin))." }
        return "Happiest indoors in \(place); outside only on warm summer days above \(Climate.temp(s.tempMin))."
    }

    /// Season card copy shaped by the real climate and this week's weather.
    func seasonTip(plants: [Plant], now: Date = Date()) -> String? {
        if let a = alerts(for: plants, now: now).first { return a.title + ". " + a.detail }
        guard hasClimate else { return nil }
        let place = profile!.place
        if isTropical {
            return phase(now) == .summer ? "Rainy season in \(place). Plants grow fast; feed them and watch for soggy pots."
                : "Drier season in \(place). Check soil more often and keep humidity up."
        }
        if isDry { return "Dry air in \(place). Group plants together and water deeply when the soil is dry." }
        switch phase(now) {
        case .spring: return "Spring is waking up in \(place). Fresh pots and a first gentle meal."
        case .summer: return "Warm days in \(place). Peek at the soil a little more often."
        case .autumn: return "Autumn in \(place). One last meal, then let them rest."
        case .winter:
            return heating ? "Winter in \(place) with the heating on. Less water, no food, and keep them away from radiators."
                : "Winter in \(place). Sleepy time: less water, no food, keep them off cold glass."
        }
    }

    /// One-line summary for chat and settings.
    var summary: String {
        guard let p = profile else { return "Tell me where you live and I'll tune care to your climate." }
        var t = "\(p.place)\(p.country.isEmpty ? "" : ", \(p.country)")"
        if hasClimate {
            t += ": \(biome.lowercased()) climate (Köppen \(koppen ?? "?"))"
            if let z = hardinessZone { t += ", hardiness zone \(z)" }
            t += ", \(isSouth ? "southern" : "northern") hemisphere."
            if let pt = profile?.monthlyTemp, pt.count == 12 { t += " Months range from about \(Climate.temp(pt.min()!)) to \(Climate.temp(pt.max()!))." }
        }
        return t
    }
}

/// Light per room, mirrored from Spaces so care maths can read it without a database context.
enum JungleRooms {
    private static let key = "rooms.light"
    static var all: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    static func light(for room: String) -> Species.Light? {
        let r = room.folded.trimmingCharacters(in: .whitespaces)
        guard !r.isEmpty else { return nil }
        return all.first { $0.key.folded == r }.flatMap { Species.Light(rawValue: $0.value) }
    }
    static func sync(_ spaces: [Space]) {
        all = Dictionary(spaces.map { ($0.name, $0.lightRaw) }, uniquingKeysWith: { a, _ in a })
    }
}
