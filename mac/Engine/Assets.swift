import Foundation
import ImageIO
import CoreGraphics

/// One clock in one light: the baked plate (case, dial, wall, shadows), the glass reflection layer, and hand sprites.
/// Hand sprites are the centre `sprite` fraction of the plate, drawn with the camera on the clock axis, so rotating
/// them in 2D is exact.
public final class LookImages {
    public let plate: CGImage
    public var hands: [String: CGImage] = [:]       // hour, minute, second, cap, hour_s, hour_c, ...
    public let edge: CGColor                        // average plate border, for the area outside the plate

    init?(folder: URL, glassAmount: Double = 0) {
        guard let p = LookImages.image(folder.appendingPathComponent("plate.jpg")) else { return nil }
        let glass = glassAmount > 0 ? LookImages.image(folder.appendingPathComponent("glass.jpg")) : nil   // baked in, then freed
        edge = LookImages.borderColour(p)
        plate = LookImages.bake(p, glass: glass, amount: glassAmount) ?? p
        for key in ["hour", "minute", "second", "cap"] {
            for suffix in ["", "_s", "_c"] {
                // shadows are blurred masks: a quarter (soft) or half (contact) of the pixels look the same, at a fraction of the memory
                let max = suffix == "_s" ? 4 : suffix == "_c" ? 2 : 1
                if let im = LookImages.image(folder.appendingPathComponent("\(key)\(suffix).webp"), shrink: max) { hands[key + suffix] = im }
            }
        }
    }

    /// Static layers are flattened once: the glass reflection is added onto the plate, and the plate's outer ring fades
    /// to transparent so it melts into the background colour. Per frame, only the hands move.
    static func bake(_ p: CGImage, glass: CGImage?, amount: Double) -> CGImage? {
        let w = p.width, h = p.height, cs = CGColorSpace(name: CGColorSpace.displayP3)!
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let r = CGRect(x: 0, y: 0, width: w, height: h)
        ctx.draw(p, in: r)
        if let g = glass { ctx.setBlendMode(.plusLighter); ctx.setAlpha(amount); ctx.draw(g, in: r); ctx.setAlpha(1) }
        ctx.setBlendMode(.destinationIn)
        let grad = CGGradient(colorsSpace: cs, colors: [CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 0)] as CFArray,
                              locations: [0, 0.72, 1])!
        let c = CGPoint(x: w / 2, y: h / 2)
        ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0, endCenter: c, endRadius: CGFloat(w) / 2, options: [.drawsAfterEndLocation])
        return ctx.makeImage()
    }

    static func image(_ url: URL, shrink: Int = 1) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        if shrink > 1, let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
           let w = props[kCGImagePropertyPixelWidth] as? Int {
            return CGImageSourceCreateThumbnailAtIndex(src, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: w / shrink, kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        }
        return CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }

    /// Average of the outer ring of an 16x16 thumbnail.
    static func borderColour(_ im: CGImage) -> CGColor {
        let n = 16
        var px = [UInt8](repeating: 0, count: n * n * 4)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ok = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                      space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(im, in: CGRect(x: 0, y: 0, width: n, height: n)); return true
        }
        guard ok else { return CGColor(gray: 0.9, alpha: 1) }
        var r = 0.0, g = 0.0, b = 0.0, c = 0.0
        for y in 0..<n { for x in 0..<n where x == 0 || y == 0 || x == n - 1 || y == n - 1 {
            let i = (y * n + x) * 4; r += Double(px[i]); g += Double(px[i + 1]); b += Double(px[i + 2]); c += 1 } }
        return CGColor(colorSpace: cs, components: [r / c / 255, g / c / 255, b / c / 255, 1])!
    }
}

/// Finds and caches looks. Shared by every view in a process, so several displays decode each image once.
public final class AssetStore {
    public static let shared = AssetStore()
    private var cache: [String: LookImages] = [:]
    private let lock = NSLock()
    public var root: URL?

    public func looks(for id: String) -> [String] {
        guard let root else { return [] }
        return ["day", "dusk", "night"].filter {
            FileManager.default.fileExists(atPath: root.appendingPathComponent("Clocks/\(id)/\($0)/plate.jpg").path)
        }
    }

    public var glassAmount: [String: Double] = [:]

    public func images(_ id: String, _ look: String) -> LookImages? {
        let key = "\(id)/\(look)"
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[key] { return hit }
        guard let root, let im = LookImages(folder: root.appendingPathComponent("Clocks/\(key)"), glassAmount: glassAmount[id] ?? 0) else { return nil }
        cache[key] = im
        return im
    }

    /// Keep only the given clock's looks; a clock's three looks are a few hundred MB decoded at 3000 px.
    public func trim(keeping ids: [String]) {
        lock.lock(); cache = cache.filter { k in ids.contains { k.key.hasPrefix($0 + "/") } }; lock.unlock()
    }
}
