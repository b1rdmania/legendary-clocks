import Foundation
import QuartzCore
import CoreText

public enum Light: String, CaseIterable { case automatic, day, dusk, night }

/// The whole clock as a Core Animation layer tree. Host it in any layer-backed view (app window or screensaver)
/// and call `update(at:)` once per frame. Nothing here imports AppKit or ScreenSaver.
/// A change of clock crossfades: the new clock fades in over the old one, then the old one is released.
public final class ClockScene {
    public let root = CALayer()
    private let stage = CALayer()                 // drifts slowly to protect OLED panels
    private let caption = CATextLayer()
    private let catalog: Catalog
    private let store: AssetStore
    private var looks: [String: LookLayer] = [:]  // keyed "clock/look"
    public private(set) var clockID: String
    private var outgoing: String?
    private var changedAt: CFTimeInterval = CACurrentMediaTime()
    public var light: Light = .automatic
    public var fit: CGFloat = 0.74 { didSet { if fit != oldValue { layout() } } }
    public var captionMode = ClockSettings.Caption.off
    public var scale: CGFloat = 2 { didSet { looks.values.forEach { $0.contentsScale = scale }; caption.contentsScale = scale } }
    public var driftEnabled = true
    public static var fadeDuration: CFTimeInterval = 2.4
    public static var captionHold: CFTimeInterval = 8

    public init(catalog: Catalog, store: AssetStore = .shared, clock: String) {
        self.catalog = catalog; self.store = store; self.clockID = clock
        for (id, c) in catalog.clocks { store.glassAmount[id] = c.glass }
        root.masksToBounds = true
        root.addSublayer(stage)
        caption.actions = Self.noActions; caption.opacity = 0; caption.alignmentMode = .left
        caption.isWrapped = false; caption.zPosition = 100
        root.addSublayer(caption)
        root.actions = Self.noActions; stage.actions = Self.noActions
        _ = FlipLayer.registered
    }

    static let noActions: [String: CAAction] = ["position": NSNull(), "bounds": NSNull(), "opacity": NSNull(),
        "transform": NSNull(), "contents": NSNull(), "backgroundColor": NSNull(), "sublayers": NSNull(), "frame": NSNull(),
        "string": NSNull(), "foregroundColor": NSNull()]

    public var clock: Catalog.Clock { catalog.clocks[clockID]! }

    /// Switch clock. `animated` crossfades; otherwise the new clock replaces the old at once.
    public func show(_ id: String, animated: Bool = false) {
        guard catalog.clocks[id] != nil else { return }
        if id == clockID && !looks.isEmpty { return }
        let hadClock = !looks.isEmpty
        if let o = outgoing { drop(o) }                       // a change during a fade: the oldest goes now
        if animated && hadClock { outgoing = clockID } else { drop(clockID); outgoing = nil }
        clockID = id
        changedAt = CACurrentMediaTime()
        store.trim(keeping: [id, outgoing].compactMap { $0 })
        layout()
    }

    private func drop(_ id: String) {
        for (k, l) in looks where k.hasPrefix(id + "/") { l.removeFromSuperlayer(); looks[k] = nil }
    }

    public func layout() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        stage.frame = root.bounds
        looks.values.forEach { $0.frame = stage.bounds; $0.layoutClock(fit: fit) }
        let short = min(root.bounds.width, root.bounds.height)
        let h = max(34, short * 0.062), m = max(20, short * 0.05)    // a wall label, bottom left
        caption.frame = CGRect(x: m, y: m * 0.8, width: root.bounds.width - 2 * m, height: h)
        CATransaction.commit()
    }

    private func look(_ id: String, _ name: String) -> LookLayer? {
        let key = "\(id)/\(name)"
        if let l = looks[key] { return l }
        guard let im = store.images(id, name), let c = catalog.clocks[id] else { return nil }
        let l = LookLayer(images: im, clock: c, view: catalog.view, shadow: catalog.shadow[name], look: name)
        l.contentsScale = scale
        l.frame = stage.bounds; l.layoutClock(fit: fit)
        looks[key] = l
        stage.addSublayer(l)
        return l
    }

    /// Weights of each look at this moment: one look, or two during a dawn or dusk crossfade.
    public func weights(_ id: String, at date: Date) -> [(String, Double)] {
        let available = store.looks(for: id)
        if light != .automatic { return [(available.contains(light.rawValue) ? light.rawValue : available.first ?? "day", 1)] }
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return catalog.lookWeights(available: available, hour: Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60)
    }

    /// Draws one clock's looks at `alpha`, stacked from `z`. Returns its background colour and the keys shown.
    private func render(_ id: String, alpha: Float, z: CGFloat, date: Date, shown: inout Set<String>) -> CGColor? {
        guard let c = catalog.clocks[id] else { return nil }
        let ws = weights(id, at: date).sorted { $0.1 > $1.1 }
        let angles = Movement.angles(Movement(c.movement), at: date)
        var base: LookLayer?, second: (LookLayer, Double)?
        for (i, (name, w)) in ws.enumerated() where w > 0.004 || i == 0 {
            guard let l = look(id, name) else { continue }
            shown.insert("\(id)/\(name)")
            l.opacity = alpha * (i == 0 ? 1 : Float(w))
            l.zPosition = z + CGFloat(i)
            l.update(angles: angles, date: date)
            if i == 0 { base = l } else if second == nil { second = (l, w) }
        }
        guard let b = base else { return nil }
        return second.map { b.mixEdge(with: $0.0, weight: $0.1) } ?? b.edge
    }

    public func update(at date: Date = Date()) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let now = CACurrentMediaTime()
        var p = outgoing == nil ? 1 : min(1, (now - changedAt) / Self.fadeDuration)
        if p >= 1, let o = outgoing { drop(o); outgoing = nil; store.trim(keeping: [clockID]); p = 1 }
        let e = Float(p * p * (3 - 2 * p))                    // smoothstep
        var shown = Set<String>()
        var bgOut: CGColor?
        if let o = outgoing { bgOut = render(o, alpha: 1, z: 0, date: date, shown: &shown) }
        let bgIn = render(clockID, alpha: outgoing == nil ? 1 : e, z: 10, date: date, shown: &shown)
        for (k, l) in looks where !shown.contains(k) { l.opacity = 0 }
        if let i = bgIn { root.backgroundColor = bgOut.map { Self.mix($0, i, Double(e)) } ?? i }
        updateCaption(now: now, crossfade: outgoing == nil ? 1 : Double(e))
        if driftEnabled {   // about 1% of the short side, on a 47 x 61 minute path: invisible, but no pixel stays lit
            let t = date.timeIntervalSinceReferenceDate, a = min(root.bounds.width, root.bounds.height) * 0.01
            stage.frame.origin = CGPoint(x: a * sin(t / (47 * 60) * 2 * .pi), y: a * sin(t / (61 * 60) * 2 * .pi))
        }
        CATransaction.commit()
    }

    // MARK: caption: a catalogue label under the clock

    private var captionFor = ""
    private func updateCaption(now: CFTimeInterval, crossfade: Double) {
        var a: Double
        switch captionMode {
        case .off: a = 0
        case .always: a = 1
        case .onChange:
            let t = now - changedAt - Self.fadeDuration * 0.5
            a = t < 0 ? 0 : t < 1 ? t : t < Self.captionHold ? 1 : max(0, 1 - (t - Self.captionHold) / 1.5)
        }
        if captionMode == .always && crossfade < 1 { a = crossfade }   // the label fades with the clock it names
        caption.opacity = Float(a) * 0.8
        guard a > 0 else { return }
        let bg = root.backgroundColor ?? CGColor(gray: 0.9, alpha: 1)
        let key = "\(clockID)|\(Self.isDark(bg))|\(Int(caption.bounds.height))"
        guard key != captionFor else { return }
        captionFor = key
        let c = clock, h = caption.bounds.height
        let ink = Self.isDark(bg) ? CGColor(srgbRed: 0.93, green: 0.91, blue: 0.87, alpha: 1) : CGColor(srgbRed: 0.1, green: 0.1, blue: 0.11, alpha: 1)
        let soft = ink.copy(alpha: 0.58)!
        let s = NSMutableAttributedString()
        s.append(NSAttributedString(string: c.name + "\n", attributes: [
            kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("InterDisplay-Medium" as CFString, h * 0.36, nil),
            kCTForegroundColorAttributeName as NSAttributedString.Key: ink,
            kCTKernAttributeName as NSAttributedString.Key: h * 0.36 * 0.01]))
        s.append(NSAttributedString(string: "\(c.designer), \(c.year)", attributes: [
            kCTFontAttributeName as NSAttributedString.Key: CTFontCreateWithName("InterDisplay-Medium" as CFString, h * 0.25, nil),
            kCTForegroundColorAttributeName as NSAttributedString.Key: soft]))
        caption.string = s
    }

    static func isDark(_ c: CGColor) -> Bool {
        guard let k = c.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components, k.count >= 3 else { return false }
        return 0.2126 * k[0] + 0.7152 * k[1] + 0.0722 * k[2] < 0.45
    }
    static func mix(_ a: CGColor, _ b: CGColor, _ w: Double) -> CGColor {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let x = a.converted(to: cs, intent: .defaultIntent, options: nil)?.components,
              let y = b.converted(to: cs, intent: .defaultIntent, options: nil)?.components, x.count >= 3, y.count >= 3 else { return b }
        return CGColor(colorSpace: cs, components: (0..<3).map { x[$0] * (1 - w) + y[$0] * w } + [1])!
    }
}

/// One clock in one light.
final class LookLayer: CALayer {
    let images: LookImages
    let clock: Catalog.Clock
    let view: Catalog.View
    let shadow: Catalog.Shadow?
    let edge: CGColor
    private let plate = CALayer()
    private var hands: [(key: String, shadow: CALayer?, contact: CALayer?, hand: CALayer)] = []
    private var flip: FlipLayer?
    private var pointsPerMetre: CGFloat = 1
    private var centre = CGPoint.zero

    init(images: LookImages, clock: Catalog.Clock, view: Catalog.View, shadow: Catalog.Shadow?, look: String) {
        self.images = images; self.clock = clock; self.view = view; self.shadow = shadow; self.edge = images.edge
        super.init()
        actions = ClockScene.noActions
        plate.actions = ClockScene.noActions
        plate.contents = images.plate          // glass and edge fade already baked in
        addSublayer(plate)
        for key in ["hour", "minute", "second", "cap"] {
            guard let im = images.hands[key] else { continue }
            func sprite(_ c: CGImage?, _ a: Float) -> CALayer? {
                guard let c else { return nil }
                let l = CALayer(); l.contents = c; l.opacity = a; l.actions = ClockScene.noActions; addSublayer(l); return l
            }
            let s = sprite(images.hands[key + "_s"], Float(shadow?.alpha ?? 0.4))
            let c = sprite(images.hands[key + "_c"], 0.35)
            let h = sprite(im, 1)!
            hands.append((key, s, c, h))
        }
        if let f = clock.flip {
            let fl = FlipLayer(spec: f, look: look); fl.actions = ClockScene.noActions
            flip = fl; addSublayer(fl)
        }
    }
    override init(layer: Any) { let o = layer as! LookLayer; images = o.images; clock = o.clock; view = o.view; shadow = o.shadow; edge = o.edge; super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    override var contentsScale: CGFloat { didSet { flip?.contentsScale = contentsScale } }

    /// Plate pixels -> points: the plate spans `36 / lens * 1.15` metres at the wall; `fitMetres / size` of that
    /// fills `fit` of the short side.
    func layoutClock(fit: CGFloat) {
        let src = CGFloat(images.plate.width)
        let frameM = 36 / view.lens * 1.15
        let pxm = src / frameM
        let fitM = view.fitMetres / (clock.size ?? 1)
        let s = min(bounds.width, bounds.height) * fit / (fitM * pxm)
        let P = src * s, S = src * view.sprite * s
        centre = CGPoint(x: bounds.midX, y: bounds.midY)
        pointsPerMetre = pxm * s
        let pf = CGRect(x: centre.x - P / 2, y: centre.y - P / 2, width: P, height: P)
        plate.frame = pf
        for h in hands {
            for l in [h.shadow, h.contact, h.hand].compactMap({ $0 }) { l.bounds = CGRect(x: 0, y: 0, width: S, height: S) }
        }
        flip?.frame = bounds
        flip?.place(centre: centre, pointsPerMetre: pointsPerMetre)
    }

    func update(angles a: HandAngles, date: Date) {
        let turns = ["hour": a.hour, "minute": a.minute, "second": a.second, "cap": 0]
        let dir = shadow?.dir ?? [0.6, 0.8], slope = shadow?.slope ?? 1
        for h in hands {
            let r = CATransform3DMakeRotation(-CGFloat(turns[h.key]! * 2 * .pi), 0, 0, 1)
            let d = CGFloat((clock.lift[h.key] ?? 0) * slope) * pointsPerMetre
            let off = CGPoint(x: CGFloat(dir[0]) * d, y: -CGFloat(dir[1]) * d)    // page y runs down, layers' y runs up
            h.shadow?.position = CGPoint(x: centre.x + off.x, y: centre.y + off.y); h.shadow?.transform = r
            h.contact?.position = CGPoint(x: centre.x + off.x * 0.3, y: centre.y + off.y * 0.3); h.contact?.transform = r
            h.hand.position = centre; h.hand.transform = r
        }
        flip?.tick(date: date)
    }

    func mixEdge(with other: LookLayer?, weight w: Double) -> CGColor {
        guard let o = other, let a = edge.components, let b = o.edge.components, a.count >= 3, b.count >= 3 else { return edge }
        let m = (0..<3).map { a[$0] * (1 - CGFloat(w)) + b[$0] * CGFloat(w) }
        return CGColor(colorSpace: edge.colorSpace!, components: m + [1])!
    }
}
