import SwiftUI

/// Tiny Jungle 3D icon library (Woopicx free 3D packs, exported from Figma).
/// Use `Icon3D.water.image(size:)` or `Icon3DView(.water)`. Never emoji.
enum Icon3D: String, CaseIterable, Identifiable {
    case sprout, pottedSprout, seedling, succulent, leaf, leaves, pottedPlant, snakePlant, herbs, bonsai, careHands, plantStand
    case cactus, palm, fern, waterDrops, addPlant, plantTimer, terrarium, leafTag, autumnLeaf, growth, sunflower, salad
    case feedJar, healthShield, pot, soilTest, fertilizer, wilted, roots, award, soil, tools, trellis, waterTray, frost
    case greenhouse, emptyPot, clover, cream
    case calendar, calendarClock, calendarCheck, calendarHeart, travel, `repeat`, weather, treatment
    case flower, flowerPot, bouquet, rainFlower, garden, blossomTree, tulips, lotus, hummingbird
    case pin, home, globe, heartPin, pushPin, park
    case shieldCheck, shieldLeaf, firstAid, shieldStar, profile, crown, bug
    case gift, box, celebrate
    case mail, notification, chat, share
    case sun, hill, summit, waterfall
    case sunny, moon, snowCloud, bayLeaf, thermometer, cold, hot, rainCloud, windCloud, wind, storm, snow, drop, humidity
    case livingRoom, bedroom, kitchen, fridge, bathroom, office, desk, diningRoom, kidsRoom, hallway, laundry, balcony, patio, backyard
    case gardenSwing, shed, stairs, tvRoom, homeLeaf, cabin, wateringCan, lamp, armchair, humidifier, radiator, heaterFan, airCooler, shelf, bench, stool, birdhouse, nightstand
    case hygrometer, fan, airConditioner, heater, tap, frostDrop, coolingDown, warmingUp, mistRain, umbrella, puddle
    case tree, pine, willow, forest, cherryTree, bigTree, twoLeaves

    var id: String { rawValue }
    var assetName: String { "Icons3D/\(rawValue)" }
    func image(size: CGFloat = 28) -> some View { Icon3DView(self, size: size) }

    /// The icon for each kind of care.
    static func care(_ k: CareKind) -> Icon3D {
        switch k {
        case .water: .waterDrops
        case .feed: .fertilizer
        case .mist: .rainFlower
        case .repot: .pot
        case .prune: .tools
        case .move: .home
        case .rotate: .repeat
        case .clean: .leaf
        case .soilCheck: .soilTest
        case .photo: .flowerPot
        case .note: .leafTag
        case .measure: .growth
        case .newLeaf: .sprout
        case .flower: .flower
        case .treat: .treatment
        case .health: .healthShield
        case .propagate: .seedling
        }
    }
}

struct Icon3DView: View {
    let icon: Icon3D
    var size: CGFloat
    init(_ icon: Icon3D, size: CGFloat = 28) { self.icon = icon; self.size = size }
    var body: some View {
        Image(icon.assetName).resizable().interpolation(.high).scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Soft tile behind a 3D icon, for rows and buttons.
struct Icon3DTile: View {
    let icon: Icon3D
    var size: CGFloat = 44
    var tint: Color = Jungle.mint
    var body: some View {
        Icon3DView(icon, size: size * 0.72)
            .frame(width: size, height: size)
            .background(tint.opacity(0.55), in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

extension Icon3D {
    /// 3D stand-in for an SF Symbol used in content (not in controls like chevrons or the tab bar).
    static func forSymbol(_ s: String) -> Icon3D? {
        switch s {
        case "drop.fill", "drop", "drop.halffull", "water.waves", "shower.fill": .waterDrops
        case "leaf.fill", "leaf", "leaf.circle.fill": .leaf
        case "leaf.arrow.triangle.circlepath": .fertilizer
        case "calendar", "calendar.badge.plus": .calendar
        case "scissors": .herbs
        case "scissors.badge.ellipsis": .seedling
        case "hand.point.down.fill", "hand.point.down": .soilTest
        case "thermometer.medium", "thermometer", "thermometer.sun": .thermometer
        case "thermometer.snowflake": .cold
        case "wind", "wind.snow": .wind
        case "cloud.rain", "cloud.rain.fill", "cloud.drizzle": .rainCloud
        case "leaf.arrow.circlepath", "leaf.fill.autumn": .autumnLeaf
        case "arrow.up.bin", "arrow.up.bin.fill": .pot
        case "sun.max", "sun.max.fill", "sun.horizon", "sun.min", "sun.min.fill": .sunny
        case "moon", "moon.fill", "moon.stars": .moon
        case "pawprint.fill", "pawprint": .shieldCheck
        case "heart.fill": .calendarHeart
        case "ant.fill": .bug
        case "stethoscope": .healthShield
        case "ruler", "ruler.fill": .growth
        case "moon.zzz": .moon
        case "snowflake": .snow
        case "humidity", "humidity.fill": .humidity
        case "house": .home
        case "cart": .box
        case "tray.full", "tray", "tray.and.arrow.down.fill": .box
        case "book.fill": .leafTag
        case "airplane": .travel
        case "sparkles", "sparkle": .hummingbird
        case "camera.macro", "camera.fill", "camera", "photo", "photo.on.rectangle": .flowerPot
        case "square.stack.3d.down.right", "square.stack.3d.down.forward": .soil
        case "cylinder": .emptyPot
        case "barcode.viewfinder", "text.viewfinder": .fertilizer
        case "tree": .tree
        case "arrow.clockwise": .repeat
        case "nosign": .shieldStar
        case "hand.raised", "hand.raised.fill": .shieldCheck
        case "person.2.fill": .forest
        case "eye": .healthShield
        default: nil
        }
    }
}

extension Icon3D {
    /// Icon for a room or outdoor spot, from its name (English and Portuguese).
    static func room(_ name: String) -> Icon3D {
        let n = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
        let table: [([String], Icon3D)] = [
            (["balcon", "varanda", "sacada"], .balcony),
            (["terrace", "terraco", "patio", "deck", "rooftop", "roof"], .patio),
            (["greenhouse", "estufa", "conservator", "sunroom"], .greenhouse),
            (["garden", "jardim", "horta", "yard", "quintal", "lawn"], .garden),
            (["backyard", "bbq", "churrasq"], .backyard),
            (["porch", "alpendre", "entrance", "entry", "entrada", "hall", "corredor", "foyer"], .hallway),
            (["shed", "garage", "garagem", "barracao", "workshop"], .shed),
            (["stair", "escada", "landing"], .stairs),
            (["kitchen", "cozinha", "pantry", "despensa"], .kitchen),
            (["dining", "jantar"], .diningRoom),
            (["bath", "banheiro", "casa de banho", "wc", "toilet", "lavabo", "shower"], .bathroom),
            (["laundry", "lavandaria", "lavanderia", "utility"], .laundry),
            (["kid", "nursery", "crianc", "infantil", "bebe", "baby"], .kidsRoom),
            (["bed", "quarto", "suite", "dormit"], .bedroom),
            (["office", "escritorio", "study", "estudo", "work"], .office),
            (["tv", "media", "cinema"], .tvRoom),
            (["living", "lounge", "sala", "family"], .livingRoom),
            (["attic", "sotao", "loft", "cabin"], .cabin),
            (["window", "janela", "sill", "parapeito"], .pottedPlant),
            (["shelf", "estante", "prateleira"], .shelf),
        ]
        for (keys, icon) in table where keys.contains(where: { n.contains($0) }) { return icon }
        return .homeLeaf
    }
}

/// Shows the 3D icon for a symbol when one exists, else the SF Symbol.
struct SmartIcon: View {
    let symbol: String
    var size: CGFloat = 24
    var tint: Color = Jungle.leaf
    var body: some View {
        if let i = Icon3D.forSymbol(symbol) { Icon3DView(i, size: size * 1.15) }
        else { Image(systemName: symbol).font(.system(size: size * 0.75, weight: .semibold)).foregroundStyle(tint).frame(width: size, height: size) }
    }
}
