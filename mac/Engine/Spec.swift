import Foundation

/// The collection, read from clocks.json. Mirrors the website's CLOCKS table so both stay in step.
public struct Catalog: Decodable {
    public struct Shadow: Decodable { public let dir: [Double]; public let slope: Double; public let alpha: Double }
    public struct Flip: Decodable {
        public let z, w, h, gap: Double
        public let units: [Double]
        public let ink: [String: String]
        public let card: String
    }
    public struct Clock: Decodable {
        public let name, designer: String
        public let year: Int
        public let movement: String
        public let size: Double?
        public let lift: [String: Double]
        public let glass: Double
        public let flip: Flip?
    }
    public struct View: Decodable { public let lens, sprite, fitMetres: Double }
    public let order: [String]
    public let shadow: [String: Shadow]
    public let schedule: [[ScheduleEntry]]
    public let clocks: [String: Clock]
    public let view: View

    /// A schedule row is [hour, look]; JSON mixes a number and a string.
    public enum ScheduleEntry: Decodable {
        case hour(Double), look(String)
        public init(from d: Decoder) throws {
            let c = try d.singleValueContainer()
            if let h = try? c.decode(Double.self) { self = .hour(h) } else { self = .look(try c.decode(String.self)) }
        }
    }

    public static func load(from resources: URL) throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: resources.appendingPathComponent("clocks.json")))
    }

    /// Look weights for an hour of the day, e.g. 18.2 -> [("dusk", 1)], 20.4 -> [("night", 0.6), ("dusk", 0.4)].
    public func lookWeights(available: [String], hour: Double) -> [(String, Double)] {
        guard available.count > 1 else { return [(available.first ?? "day", 1)] }
        let rows: [(Double, String)] = schedule.compactMap {
            guard case .hour(let h)? = $0.first, case .look(let l)? = $0.last else { return nil }; return (h, l)
        }
        for i in 0..<(rows.count - 1) {
            let (h0, a) = rows[i], (h1, b) = rows[i + 1]
            guard hour >= h0 && hour < h1 else { continue }
            let pa = available.contains(a) ? a : available[0], pb = available.contains(b) ? b : available[0]
            if pa == pb { return [(pa, 1)] }
            let w = (hour - h0) / (h1 - h0)
            return [(pa, 1 - w), (pb, w)]
        }
        return [(available[0], 1)]
    }
}
