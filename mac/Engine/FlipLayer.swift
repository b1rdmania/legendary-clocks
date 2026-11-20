import Foundation
import QuartzCore
import CoreText

/// Cifra 3: the render holds blank cards; this layer draws the numerals and the falling flap.
/// A flip is the old top half folding down to the split, then the new bottom half unfolding below it.
final class FlipLayer: CALayer {
    let spec: Catalog.Flip
    let ink: CGColor, card: CGColor
    private var centre = CGPoint.zero, ppm: CGFloat = 1
    private struct Unit { var cur: String; var prev: String; var t0: CFTimeInterval }
    private var units: [Unit] = []
    private static let duration: CFTimeInterval = 0.34
    static var fontURL: URL?
    static let registered: Bool = {
        if let u = fontURL { CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil) }; return true
    }()

    init(spec: Catalog.Flip, look: String) {
        self.spec = spec
        ink = FlipLayer.hex(spec.ink[look] ?? "#eeeeee"); card = FlipLayer.hex(spec.card)
        super.init()
        _ = FlipLayer.registered
        isGeometryFlipped = true          // draw like the page: y runs down
        needsDisplayOnBoundsChange = true
    }
    override init(layer: Any) { let o = layer as! FlipLayer; spec = o.spec; ink = o.ink; card = o.card; super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    static func hex(_ s: String) -> CGColor {
        let v = UInt32(s.dropFirst(), radix: 16) ?? 0xeeeeee
        return CGColor(srgbRed: CGFloat(v >> 16 & 255) / 255, green: CGFloat(v >> 8 & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }

    func place(centre c: CGPoint, pointsPerMetre p: CGFloat) {
        centre = CGPoint(x: c.x, y: bounds.height - c.y)   // flipped geometry
        ppm = p; setNeedsDisplay()
    }

    func tick(date: Date) {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let vals = [String(c.hour ?? 0), String(format: "%02d", c.minute ?? 0)]
        let now = CACurrentMediaTime()
        if units.isEmpty { units = vals.map { Unit(cur: $0, prev: $0, t0: 0) } }
        var animating = false
        for i in units.indices {
            if vals[i] != units[i].cur { units[i].prev = units[i].cur; units[i].cur = vals[i]; units[i].t0 = now }
            if now - units[i].t0 < FlipLayer.duration + 0.05 { animating = true }
        }
        if animating || contents == nil { setNeedsDisplay() }    // still frames cost nothing
    }

    override func draw(in ctx: CGContext) {
        let k = ppm * 1.15 / (1.15 - CGFloat(spec.z))     // cards sit nearer the camera than the wall
        let W = CGFloat(spec.w) * k, H = CGFloat(spec.h) * k, gp = max(1, CGFloat(spec.gap) * k)
        let fs = H * 0.86, hh = (H - gp) / 2
        let font = CTFontCreateWithName("InterDisplay-Medium" as CFString, fs, nil)
        let now = CACurrentMediaTime()
        func half(_ txt: String, _ x: CGFloat, top: Bool, scale sc: CGFloat, shade: CGFloat, backing: Bool) {
            let rect = CGRect(x: x - W / 2, y: top ? -gp / 2 - hh : gp / 2, width: W, height: hh)
            ctx.saveGState()
            ctx.translateBy(x: 0, y: centre.y); ctx.scaleBy(x: 1, y: max(sc, 0.001))
            ctx.clip(to: rect)
            if backing { ctx.setFillColor(card); ctx.fill(rect) }
            let attr = NSAttributedString(string: txt, attributes: [kCTFontAttributeName as NSAttributedString.Key: font,
                                                                   kCTForegroundColorAttributeName as NSAttributedString.Key: ink])
            let line = CTLineCreateWithAttributedString(attr)
            let wTxt = CTLineGetTypographicBounds(line, nil, nil, nil)
            ctx.saveGState()
            ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)        // flipped context
            ctx.textPosition = CGPoint(x: x - CGFloat(wTxt) / 2, y: fs * 0.364)
            CTLineDraw(line, ctx)
            ctx.restoreGState()
            if shade > 0 { ctx.setFillColor(CGColor(gray: 0, alpha: shade)); ctx.fill(rect) }
            ctx.restoreGState()
        }
        for (i, ux) in spec.units.enumerated() where i < units.count {
            let u = units[i], x = centre.x + CGFloat(ux) * k
            let p = min(1, (now - u.t0) / FlipLayer.duration)
            half(u.cur, x, top: true, scale: 1, shade: 0, backing: false)
            half(p < 1 ? u.prev : u.cur, x, top: false, scale: 1, shade: 0, backing: false)
            if p < 0.5 { half(u.prev, x, top: true, scale: cos(p * .pi), shade: p * 0.9, backing: true) }
            else if p < 1 { half(u.cur, x, top: false, scale: -cos(p * .pi), shade: (1 - p) * 0.7, backing: true) }
        }
    }
}
