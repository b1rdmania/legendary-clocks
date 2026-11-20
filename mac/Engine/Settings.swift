import Foundation

/// Shared between the app and the screensaver. The app writes a plain JSON file under the user's real Application
/// Support folder. The screensaver host is sandboxed, but its entitlements allow read-only access to the whole disk,
/// so it reads the same file each time it starts.
public struct ClockSettings: Codable, Equatable {
    public enum Mode: String, Codable, CaseIterable { case one, shuffle }
    public enum Caption: String, Codable, CaseIterable { case off, onChange, always }

    public var mode = Mode.one
    public var clock = "station"                 // the clock in `one` mode
    public var included: [String] = []           // clocks in the shuffle; empty means all
    public var interval = 3600                   // seconds between changes in `shuffle`; 0 = each start
    public var eachDisplayDifferent = true       // screensaver on several displays: a wall of different clocks
    public var light = Light.automatic.rawValue
    public var size = 0.74                       // share of the screen's short side the clock occupies
    public var caption = Caption.onChange
    public var reduceOnBattery = true            // 30 fps on battery or in Low Power Mode

    public init() {}

    // Tolerant decoding: a missing or renamed key falls back to its default instead of discarding the file.
    public init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self), o = ClockSettings()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? nil ?? def }
        mode = v(.mode, o.mode); clock = v(.clock, o.clock); included = v(.included, o.included)
        interval = v(.interval, o.interval); eachDisplayDifferent = v(.eachDisplayDifferent, o.eachDisplayDifferent)
        light = v(.light, o.light); size = v(.size, o.size); caption = v(.caption, o.caption)
        reduceOnBattery = v(.reduceOnBattery, o.reduceOnBattery)
    }

    public static func realHome() -> String {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir { return String(cString: dir) }
        return NSHomeDirectory()
    }
    public static var fileURL: URL {
        URL(fileURLWithPath: realHome()).appendingPathComponent("Library/Application Support/Legendary Clocks/settings.json")
    }
    public static func load() -> ClockSettings {
        (try? JSONDecoder().decode(ClockSettings.self, from: Data(contentsOf: fileURL))) ?? ClockSettings()
    }
    public func save() {
        let url = ClockSettings.fileURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? e.encode(self).write(to: url, options: .atomic)
    }

    /// The clocks in play, in catalogue order.
    public func pool(_ catalog: Catalog) -> [String] {
        let p = catalog.order.filter { included.isEmpty || included.contains($0) }
        return p.isEmpty ? catalog.order : p
    }
}

/// Which clock shows when. The shuffle is a pure function of the time, so the app, the screensaver and every
/// display agree without talking to each other. Each pass through the pool is a fresh random order, and the
/// first clock of a pass never repeats the last clock of the one before.
public struct Rotation {
    public let settings: ClockSettings
    public let catalog: Catalog
    public let started: Date                     // for interval 0: one random pick per start

    public init(settings: ClockSettings, catalog: Catalog, started: Date = Date()) {
        self.settings = settings; self.catalog = catalog; self.started = started
    }

    /// `display` offsets the pick so several screens show different clocks.
    public func clock(at date: Date, display: Int = 0) -> String {
        guard settings.mode == .shuffle else {
            return catalog.clocks[settings.clock] != nil ? settings.clock : catalog.order[0]
        }
        let pool = settings.pool(catalog), n = pool.count
        let slot = settings.interval > 0 ? Int(floor(date.timeIntervalSince1970 / Double(settings.interval)))
                                         : Int(started.timeIntervalSince1970 * 1000) & 0xFFFFFF
        let k = slot + (settings.eachDisplayDifferent ? display : 0)
        let pass = Int(floor(Double(k) / Double(n))), i = ((k % n) + n) % n
        return order(pass, pool)[i]
    }

    /// When the current pick will change, or nil if it never does.
    public func nextChange(after date: Date) -> Date? {
        guard settings.mode == .shuffle, settings.interval > 0, settings.pool(catalog).count > 1 else { return nil }
        let iv = Double(settings.interval)
        return Date(timeIntervalSince1970: (floor(date.timeIntervalSince1970 / iv) + 1) * iv)
    }

    private func order(_ pass: Int, _ pool: [String]) -> [String] {
        guard pool.count > 2 else { return pool }                 // one or two clocks simply alternate
        var o = shuffled(pool, seed: UInt64(bitPattern: Int64(pass)))
        if o.first == shuffled(pool, seed: UInt64(bitPattern: Int64(pass - 1))).last {
            // swap within 1...n-2 so this pass's last clock, which the next pass checks against, stays put
            o.swapAt(0, 1 + Int(UInt64(bitPattern: Int64(pass)) % UInt64(pool.count - 2)))
        }
        return o
    }
    private func shuffled(_ a: [String], seed: UInt64) -> [String] {
        var s = seed &+ 0x9E3779B97F4A7C15, out = a
        func next() -> UInt64 { s = s &+ 0x9E3779B97F4A7C15; var z = s; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) }
        for i in stride(from: out.count - 1, to: 0, by: -1) { out.swapAt(i, Int(next() % UInt64(i + 1))) }
        return out
    }
}
