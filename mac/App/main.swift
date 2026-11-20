import AppKit
import QuartzCore
import CryptoKit

// MARK: - The clock view

final class ClockView: NSView {
    let scene: ClockScene
    private var link: CADisplayLink?

    init(scene: ClockScene) {
        self.scene = scene
        super.init(frame: .zero)
        layer = scene.root           // layer-hosting: the scene owns the tree
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        link?.invalidate(); link = nil
        guard window != nil else { return }
        let l = displayLink(target: self, selector: #selector(frame(_:)))
        l.add(to: .main, forMode: .common)
        link = l
        applyFrameRate()
    }
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        scene.scale = window?.backingScaleFactor ?? 2
    }
    override func layout() { super.layout(); scene.layout() }

    func applyFrameRate() {
        let maxFPS = window?.screen?.maximumFramesPerSecond ?? 60
        let fps = Float(Power.frameRate(settings: AppState.shared.settings, displayMax: maxFPS))
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: min(30, fps), maximum: fps, preferred: fps)
    }

    @objc private func frame(_ l: CADisplayLink) {
        let want = AppState.shared.currentClock()
        if want != scene.clockID { scene.show(want, animated: true); AppState.shared.clockChanged() }
        scene.update()
        setAccessibilityLabel(accessibilityTime())
    }

    private func accessibilityTime() -> String {
        let f = DateFormatter(); f.timeStyle = .short
        return "\(scene.clock.name) clock, after \(scene.clock.designer), showing \(f.string(from: Date()))"
    }

    override func keyDown(with e: NSEvent) {
        guard let s = e.charactersIgnoringModifiers, e.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
            return super.keyDown(with: e)
        }
        let app = AppState.shared
        switch s {
        case "1"..."9": app.select(index: Int(s)! - 1)
        case "l": app.cycleLight()
        case "s": app.toggleShuffle()
        case "c": app.cycleCaption()
        case "f": window?.toggleFullScreen(nil)
        default:
            switch e.keyCode {
            case 123: app.step(-1)            // left
            case 124: app.step(1)             // right
            case 53 where window?.styleMask.contains(.fullScreen) == true: window?.toggleFullScreen(nil)
            default: super.keyDown(with: e)
            }
        }
    }

    override func mouseMoved(with event: NSEvent) { NSCursor.setHiddenUntilMouseMoves(window?.styleMask.contains(.fullScreen) == true) }
}

// MARK: - App state

/// One source of truth for the app. Every change saves the file the screensaver reads.
final class AppState: ObservableObject {
    static let shared = AppState()
    let catalog: Catalog
    @Published var settings = ClockSettings.load() { didSet { if settings != oldValue { apply() } } }
    @Published private(set) var showing: String = ""
    private var skip = 0                          // Next/Previous while shuffling step through the shuffle
    private let started = Date()
    var scenes: [ClockScene] = []
    var onChange: (() -> Void)?

    private init() {
        let res = Bundle.main.resourceURL!
        AssetStore.shared.root = res
        FlipLayer.fontURL = res.appendingPathComponent("InterDisplay-Medium.ttf")
        catalog = try! Catalog.load(from: res)
        if catalog.clocks[settings.clock] == nil { settings.clock = catalog.order[0] }
        settings.included = settings.included.filter { catalog.clocks[$0] != nil }
        showing = currentClock()
    }

    var rotation: Rotation { Rotation(settings: settings, catalog: catalog, started: started) }
    func currentClock(at date: Date = Date()) -> String { rotation.clock(at: date, display: skip) }

    func makeScene() -> ClockScene {
        let s = ClockScene(catalog: catalog, clock: currentClock())
        configure(s); scenes.append(s); return s
    }
    private func configure(_ s: ClockScene) {
        s.light = Light(rawValue: settings.light) ?? .automatic
        s.fit = CGFloat(settings.size)
        s.captionMode = settings.caption
    }

    private func apply() {
        scenes.forEach(configure)
        settings.save()
        clockChanged()
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
    func clockChanged() {
        let now = currentClock()
        if showing != now { showing = now }
        onChange?()
    }

    func select(index: Int) {
        guard catalog.order.indices.contains(index) else { return }
        var s = settings; s.mode = .one; s.clock = catalog.order[index]; settings = s
    }
    func step(_ d: Int) {
        if settings.mode == .shuffle { skip += d; clockChanged(); return }
        let i = catalog.order.firstIndex(of: settings.clock) ?? 0, n = catalog.order.count
        settings.clock = catalog.order[(i + d + n) % n]
    }
    func toggleShuffle() {
        var s = settings
        if s.mode == .shuffle { s.mode = .one; s.clock = showing } else { s.mode = .shuffle; skip = 0 }
        settings = s
    }
    func setLight(_ l: Light) { settings.light = l.rawValue }
    func cycleLight() { let all = Light.allCases; setLight(all[((all.firstIndex(of: Light(rawValue: settings.light) ?? .automatic) ?? 0) + 1) % all.count]) }
    func cycleCaption() { let all = ClockSettings.Caption.allCases; settings.caption = all[((all.firstIndex(of: settings.caption) ?? 0) + 1) % all.count] }
}

extension Notification.Name { static let settingsChanged = Notification.Name("LegendaryClocksSettingsChanged") }

// MARK: - Screen saver install

enum SaverInstall {
    static var bundled: URL { Bundle.main.resourceURL!.appendingPathComponent("Legendary Clocks.saver") }
    static var installed: URL {
        URL(fileURLWithPath: ClockSettings.realHome()).appendingPathComponent("Library/Screen Savers/Legendary Clocks.saver")
    }
    static func digest(_ saver: URL) -> String? {
        guard let d = try? Data(contentsOf: saver.appendingPathComponent("Contents/MacOS/Legendary Clocks")) else { return nil }
        return SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
    }
    static var isCurrent: Bool { digest(installed) != nil && digest(installed) == digest(bundled) }

    /// Copy over a live bundle and the host keeps the old code, so: remove, copy, then restart the host.
    @discardableResult static func install() -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.removeItem(at: installed)
        do { try fm.copyItem(at: bundled, to: installed) } catch { return false }
        for name in ["legacyScreenSaver", "legacyScreenSaver (Wallpaper)"] {
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/killall"); p.arguments = [name]
            p.standardError = FileHandle.nullDevice; p.standardOutput = FileHandle.nullDevice
            try? p.run(); p.waitUntilExit()
        }
        return isCurrent
    }
    /// An installed but stale saver is replaced quietly at launch; a missing one waits for the menu command.
    static func repairIfStale() { if digest(installed) != nil && !isCurrent { install() } }
}

// MARK: - Menus and window

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    var window: NSWindow!
    let app = AppState.shared

    func applicationDidFinishLaunching(_ n: Notification) {
        buildMenus()
        let scene = app.makeScene()
        let view = ClockView(scene: scene)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Legendary Clocks"
        window.contentMinSize = NSSize(width: 420, height: 320)
        window.collectionBehavior = [.fullScreenPrimary]
        window.contentView = view
        window.acceptsMouseMovedEvents = true
        window.isMovableByWindowBackground = true
        window.setFrameAutosaveName("Clock")
        if !window.setFrameUsingName("Clock") { window.center() }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        scene.show(app.currentClock())
        app.onChange = { [weak self] in guard let self else { return }; self.window.title = self.app.catalog.clocks[self.app.showing]?.name ?? "" }
        app.onChange?()
        NotificationCenter.default.addObserver(forName: .settingsChanged, object: nil, queue: .main) { _ in view.applyFrameRate() }
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { _ in view.applyFrameRate() }
        NSApp.activate()
        SaverInstall.repairIfStale()
    }

    @objc func installSaver() {
        let ok = SaverInstall.install()
        let a = NSAlert()
        a.messageText = ok ? "Screen saver installed" : "Couldn’t install the screen saver"
        a.informativeText = ok ? "In Wallpaper settings, choose Legendary Clocks under Screen Saver. It follows the choices in Legendary Clocks Settings."
                               : "Check that ~/Library/Screen Savers is writable, then try again."
        a.addButton(withTitle: ok ? "Open Wallpaper Settings" : "OK")
        if ok { a.addButton(withTitle: "Done") }
        if a.runModal() == .alertFirstButtonReturn, ok,
           let url = URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension") { NSWorkspace.shared.open(url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }

    private func item(_ title: String, _ action: Selector?, _ key: String = "", _ mods: NSEvent.ModifierFlags = .command, tag: Int = 0) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key); i.keyEquivalentModifierMask = mods; i.tag = tag; i.target = self; return i
    }

    private func buildMenus() {
        let main = NSMenu()
        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(item("About Legendary Clocks", #selector(about)))
        appMenu.addItem(.separator())
        appMenu.addItem(item("Settings…", #selector(openSettings), ","))
        appMenu.addItem(item("Install Screen Saver…", #selector(installSaver)))
        appMenu.addItem(.separator())
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: ""); services.submenu = NSMenu(); NSApp.servicesMenu = services.submenu
        appMenu.addItem(services)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide Legendary Clocks", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let others = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h"); others.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(others)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Legendary Clocks", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        add(main, "Legendary Clocks", appMenu)
        // File: Close only, so ⌘W behaves
        let file = NSMenu(title: "File")
        file.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        add(main, "File", file)
        // Clock: the collection, then light
        let clocks = NSMenu(title: "Clock")
        for (i, id) in app.catalog.order.enumerated() {
            let c = app.catalog.clocks[id]!
            clocks.addItem(item("\(c.name)  ·  \(c.designer), \(c.year)", #selector(pickClock(_:)), "\(i + 1)", tag: i))
        }
        clocks.addItem(.separator())
        clocks.addItem(item("Shuffle", #selector(toggleShuffle), "r"))
        clocks.addItem(item("Next Clock", #selector(nextClock), "]"))
        clocks.addItem(item("Previous Clock", #selector(previousClock), "["))
        clocks.addItem(.separator())
        for (i, l) in Light.allCases.enumerated() {
            clocks.addItem(item(l == .automatic ? "Light Follows the Day" : "\(l.rawValue.capitalized) Light", #selector(pickLight(_:)), "\(i + 1)", [.command, .option], tag: i))
        }
        add(main, "Clock", clocks)
        // View: the system adds Enter Full Screen here
        add(main, "View", NSMenu(title: "View"))
        // Window
        let win = NSMenu(title: "Window")
        win.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        win.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        win.addItem(.separator())
        win.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        add(main, "Window", win); NSApp.windowsMenu = win
        let help = NSMenu(title: "Help"); add(main, "Help", help); NSApp.helpMenu = help
        NSApp.mainMenu = main
    }
    private func add(_ main: NSMenu, _ title: String, _ sub: NSMenu) { let i = NSMenuItem(title: title, action: nil, keyEquivalent: ""); i.submenu = sub; main.addItem(i) }

    func validateMenuItem(_ m: NSMenuItem) -> Bool {
        if m.action == #selector(pickClock(_:)) { m.state = app.settings.mode == .one && app.catalog.order[m.tag] == app.settings.clock ? .on : .off }
        if m.action == #selector(toggleShuffle) { m.state = app.settings.mode == .shuffle ? .on : .off }
        if m.action == #selector(pickLight(_:)) { m.state = Light.allCases[m.tag].rawValue == app.settings.light ? .on : .off }
        return true
    }
    @objc func pickClock(_ m: NSMenuItem) { app.select(index: m.tag) }
    @objc func pickLight(_ m: NSMenuItem) { app.setLight(Light.allCases[m.tag]) }
    @objc func nextClock() { app.step(1) }
    @objc func toggleShuffle() { app.toggleShuffle() }
    private var settingsWindow: NSWindow?
    @objc func openSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindow.make() }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    @objc func previousClock() { app.step(-1) }

    @objc func about() {
        let credits = NSMutableAttributedString()
        let body: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        let lines = app.catalog.order.map { id -> String in let c = app.catalog.clocks[id]!; return "\(c.name), after \(c.designer), \(c.year)" }
        credits.append(NSAttributedString(string: lines.joined(separator: "\n") + "\n\nRendered approximations, made for personal use.\nNumerals: Inter Display, SIL Open Font License 1.1.", attributes: body))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits, .applicationVersion: "0.1"])
    }
}

// MARK: - Snapshot mode: render one frame to PNG without a window (for checking frames from the command line)
// LegendaryClocks --snapshot out.png --clock station --time 10:09:36 --light day --size 1600x1000

func snapshot(_ args: [String]) -> Never {
    func arg(_ k: String) -> String? { args.firstIndex(of: k).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } }
    let app = AppState.shared
    let scene = ClockScene(catalog: app.catalog, clock: arg("--clock") ?? "station")
    scene.light = Light(rawValue: arg("--light") ?? "day") ?? .day
    scene.driftEnabled = false
    scene.captionMode = ClockSettings.Caption(rawValue: arg("--caption") ?? "off") ?? .off
    if let f = arg("--fit").flatMap(Double.init) { scene.fit = CGFloat(f) }
    let wh = (arg("--size") ?? "1600x1000").split(separator: "x").map { CGFloat(Double($0) ?? 1000) }
    scene.scale = 1
    scene.root.frame = CGRect(x: 0, y: 0, width: wh[0], height: wh[1])
    scene.show(scene.clockID); scene.layout()
    var date = Date()
    if let t = arg("--time") {
        let p = t.split(separator: ":").map { Int($0) ?? 0 }
        date = Calendar.current.date(bySettingHour: p[0], minute: p[1], second: p.count > 2 ? p[2] : 0, of: Date())!
    }
    scene.update(at: date)
    let w = Int(wh[0]), h = Int(wh[1])
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    scene.root.render(in: ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: arg("--snapshot")!))
    exit(0)
}

func settingsSnapshot(_ out: String, dark: Bool) -> Never {
    _ = NSApplication.shared
    NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    let w = SettingsWindow.make()
    w.appearance = NSApp.appearance
    w.orderBack(nil); w.contentView!.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.6))
    let v = w.contentView!, rep = v.bitmapImageRepForCachingDisplay(in: v.bounds)!
    v.cacheDisplay(in: v.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
    exit(0)
}

let args = CommandLine.arguments
if args.contains("--snapshot") { snapshot(args) }
if let i = args.firstIndex(of: "--settings-snapshot") { settingsSnapshot(args[i + 1], dark: args.contains("--dark")) }
let nsapp = NSApplication.shared
let delegate = AppDelegate()
nsapp.delegate = delegate
nsapp.setActivationPolicy(.regular)
nsapp.run()
