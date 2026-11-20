import Foundation

/// Hand positions in turns (0...1) for a wall-clock time. Ported from the website engine.
public struct HandAngles { public var hour, minute, second: Double }

public enum Movement {
    case quartz, hilfiker, smooth

    public init(_ name: String) {
        switch name { case "quartz": self = .quartz; case "hilfiker": self = .hilfiker; default: self = .smooth }
    }

    /// h, m, s are whole units; ms is 0..<1000.
    public func angles(h: Int, m: Int, s: Int, ms: Double) -> HandAngles {
        let H = Double(h % 12), M = Double(m), S = Double(s)
        switch self {
        case .quartz:      // 1 Hz tick with a small overshoot as the step lands
            let k = min(ms / 110, 1)
            let sec = S + sin(k * .pi * 1.5) * (1 - k) * 0.12 - pow(1 - k, 3)
            return HandAngles(hour: (H + M / 60 + S / 3600) / 12, minute: (M + sec / 60) / 60, second: sec / 60)
        case .hilfiker:    // seconds sweep in 58.5 s, rest at twelve, minute hand jumps with a little settle
            let sec = min((S + ms / 1000) / 58.5, 1)
            let k = s == 0 ? min(ms / 180, 1) : 1
            return HandAngles(hour: (H + M / 60) / 12, minute: M / 60 + pow(1 - k, 2) * sin(k * .pi * 2) * 0.004, second: sec)
        case .smooth:
            let sec = S + ms / 1000
            return HandAngles(hour: (H + M / 60 + sec / 3600) / 12, minute: (M + sec / 60) / 60, second: sec / 60)
        }
    }

    public static func angles(_ mv: Movement, at date: Date, calendar: Calendar = .current) -> HandAngles {
        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return mv.angles(h: c.hour ?? 0, m: c.minute ?? 0, s: c.second ?? 0, ms: Double(c.nanosecond ?? 0) / 1e6)
    }
}
