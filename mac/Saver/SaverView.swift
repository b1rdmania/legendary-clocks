import ScreenSaver
import QuartzCore

/// Thin shell around ClockScene. Apple's legacyScreenSaver host has been broken since Sonoma (again in Sequoia
/// and Tahoe): stopAnimation never arrives, dismissed views keep animating and pile up, one set per display, and
/// the process never exits. So: every view stops when the session's willstop arrives or it leaves its window,
/// and the process exits shortly after willstop. Tahoe fires willstop early, hence the one-second delay.
@objc(LegendaryClocksView)
final class LegendaryClocksView: ScreenSaverView {
    private static var live = NSHashTable<LegendaryClocksView>.weakObjects()
    private static var observing = false
    private static let catalog: Catalog? = {
        guard let res = Bundle(for: LegendaryClocksView.self).resourceURL else { return nil }
        AssetStore.shared.root = res
        FlipLayer.fontURL = res.appendingPathComponent("InterDisplay-Medium.ttf")
        return try? Catalog.load(from: res)
    }()
    private static let started = Date()            // shared by every display, so "each start" picks one shuffle
    private var scene: ClockScene?
    private var rotation: Rotation?
    private var display = 0
    private var dead = false

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        guard let catalog = Self.catalog else { return }
        let settings = ClockSettings.load()
        let r = Rotation(settings: settings, catalog: catalog, started: Self.started)
        rotation = r
        let s = ClockScene(catalog: catalog, clock: r.clock(at: Date()))
        s.light = Light(rawValue: settings.light) ?? .automatic
        s.captionMode = isPreview ? .off : settings.caption
        s.fit = CGFloat(settings.size)
        scene = s
        layer = s.root; wantsLayer = true
        animationTimeInterval = 1.0 / Double(Power.frameRate(settings: settings, displayMax: 60))
        Self.live.add(self)
        Self.observeSessionEnd()
    }
    required init?(coder: NSCoder) { fatalError() }

    private static func observeSessionEnd() {
        guard !observing else { return }; observing = true
        DistributedNotificationCenter.default().addObserver(forName: .init("com.apple.screensaver.willstop"), object: nil, queue: .main) { _ in
            let views = live.allObjects
            views.forEach { $0.retire() }
            if views.contains(where: { !$0.isPreview }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }
            }
        }
    }

    private func retire() { dead = true; scene = nil; layer = nil; Self.live.remove(self) }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { retire(); return }
        scene?.scale = window?.backingScaleFactor ?? 2
        display = isPreview ? 0 : (window?.screen).flatMap { NSScreen.screens.firstIndex(of: $0) } ?? 0
        if isPreview { scene?.fit = 0.8 }
        let first = rotation?.clock(at: Date(), display: display) ?? scene!.clockID
        scene?.show(first); scene?.layout(); scene?.update()
    }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); scene?.scale = window?.backingScaleFactor ?? 2 }
    override func resizeSubviews(withOldSize s: NSSize) { super.resizeSubviews(withOldSize: s); scene?.layout() }
    override func startAnimation() { guard !dead else { return }; super.startAnimation() }
    override func animateOneFrame() {
        guard !dead, let scene else { return }
        if let want = rotation?.clock(at: Date(), display: display), want != scene.clockID { scene.show(want, animated: true) }
        scene.update()
    }
    override func draw(_ rect: NSRect) {}                  // the layer tree draws
    override var hasConfigureSheet: Bool { false }        // the app owns settings
    override var configureSheet: NSWindow? { nil }
}
