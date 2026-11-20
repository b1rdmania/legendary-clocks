import SwiftUI
import AppKit
import ImageIO

enum SettingsWindow {
    static func make() -> NSWindow {
        let host = NSHostingController(rootView: SettingsView().environmentObject(AppState.shared))
        host.sizingOptions = [.preferredContentSize]
        let w = NSWindow(contentViewController: host)
        w.title = "Settings"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.setFrameAutosaveName("Settings")
        if !w.setFrameUsingName("Settings") { w.center() }
        return w
    }
}

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @State private var saverCurrent = SaverInstall.isCurrent
    @State private var saverPresent = SaverInstall.digest(SaverInstall.installed) != nil

    private static let intervals: [(String, Int)] = [("Every 15 minutes", 900), ("Every hour", 3600),
        ("Every 3 hours", 10800), ("Every day", 86400), ("Each time it starts", 0)]

    var body: some View {
        Form {
            Section {
                Picker("Show", selection: $app.settings.mode) {
                    Text("One clock").tag(ClockSettings.Mode.one)
                    Text("Shuffle").tag(ClockSettings.Mode.shuffle)
                }
                .pickerStyle(.segmented)
                ForEach(app.catalog.order, id: \.self) { id in ClockRow(id: id) }
                if app.settings.mode == .shuffle {
                    Picker("Change", selection: $app.settings.interval) {
                        ForEach(Self.intervals, id: \.1) { Text($0.0).tag($0.1) }
                    }
                    Toggle("Different clock on each display", isOn: $app.settings.eachDisplayDifferent)
                }
            } header: { Text("Clocks") }

            Section {
                Picker("Light", selection: $app.settings.light) {
                    Text("Follows the day").tag(Light.automatic.rawValue)
                    Divider()
                    Text("Day").tag(Light.day.rawValue)
                    Text("Dusk").tag(Light.dusk.rawValue)
                    Text("Night").tag(Light.night.rawValue)
                }
                LabeledContent("Size") {
                    Slider(value: $app.settings.size, in: 0.5...0.9) {
                        EmptyView()
                    } minimumValueLabel: { Image(systemName: "circle").imageScale(.small) }
                      maximumValueLabel: { Image(systemName: "circle").imageScale(.large) }
                }
                Picker("Label", selection: $app.settings.caption) {
                    Text("Off").tag(ClockSettings.Caption.off)
                    Text("When the clock changes").tag(ClockSettings.Caption.onChange)
                    Text("Always").tag(ClockSettings.Caption.always)
                }
            } header: { Text("Appearance") }

            Section {
                LabeledContent("Screen saver") {
                    HStack(spacing: 10) {
                        if saverCurrent {
                            Text("Installed").foregroundStyle(.secondary)
                            Button("Open Wallpaper Settings…") {
                                if let u = URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension") { NSWorkspace.shared.open(u) }
                            }
                        } else {
                            Button(saverPresent ? "Update" : "Install") { SaverInstall.install(); refreshSaver() }
                        }
                    }
                }
                Toggle("30 fps on battery", isOn: $app.settings.reduceOnBattery)
            } header: { Text("System") }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refreshSaver() }
    }

    private func refreshSaver() {
        saverCurrent = SaverInstall.isCurrent
        saverPresent = SaverInstall.digest(SaverInstall.installed) != nil
    }
}

/// One clock: thumbnail, name, designer. In One mode the row picks the clock; in Shuffle it toggles it in or out.
struct ClockRow: View {
    @EnvironmentObject var app: AppState
    let id: String

    private var included: Bool { app.settings.included.isEmpty || app.settings.included.contains(id) }

    var body: some View {
        let c = app.catalog.clocks[id]!
        let shuffle = app.settings.mode == .shuffle
        HStack(spacing: 12) {
            Thumbnail(id: id).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(c.name)
                Text("\(c.designer), \(String(c.year))").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if shuffle {
                Toggle("", isOn: Binding(get: { included }, set: { setIncluded($0) }))
                    .labelsHidden().toggleStyle(.checkbox)
            } else if app.settings.clock == id {
                Image(systemName: "checkmark").foregroundStyle(.tint).fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { shuffle ? setIncluded(!included) : (app.settings.clock = id) }
        .opacity(shuffle && !included ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(shuffle ? [] : app.settings.clock == id ? [.isSelected, .isButton] : .isButton)
    }

    /// Stored as an explicit list; all ticked is stored as empty so clocks added later join the shuffle.
    private func setIncluded(_ on: Bool) {
        var set = Set(app.settings.included.isEmpty ? app.catalog.order : app.settings.included)
        if on { set.insert(id) } else if set.count > 1 { set.remove(id) }      // the shuffle never empties
        app.settings.included = set.count == app.catalog.order.count ? [] : app.catalog.order.filter(set.contains)
    }
}

/// The day plate cropped to the clock, decoded small once.
struct Thumbnail: View {
    let id: String
    private static var cache: [String: CGImage] = [:]

    var body: some View {
        if let im = Self.image(id) {
            Image(decorative: im, scale: 2).resizable().clipShape(RoundedRectangle(cornerRadius: 7))
        } else {
            RoundedRectangle(cornerRadius: 7).fill(.quaternary)
        }
    }

    static func image(_ id: String) -> CGImage? {
        if let c = cache[id] { return c }
        let app = AppState.shared
        guard let root = AssetStore.shared.root, let look = AssetStore.shared.looks(for: id).first,
              let src = CGImageSourceCreateWithURL(root.appendingPathComponent("Clocks/\(id)/\(look)/plate.jpg") as CFURL, nil),
              let full = CGImageSourceCreateThumbnailAtIndex(src, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                                      kCGImageSourceThumbnailMaxPixelSize: 480] as CFDictionary)
        else { return nil }
        // the clock spans fitMetres / size of a plate that spans 36 / lens * 1.15 metres
        let v = app.catalog.view, frameM = 36 / v.lens * 1.15, fitM = v.fitMetres / (app.catalog.clocks[id]?.size ?? 1)
        let f = min(1, fitM / frameM * 1.6), w = CGFloat(full.width), side = w * f
        let crop = full.cropping(to: CGRect(x: (w - side) / 2, y: (CGFloat(full.height) - side) / 2, width: side, height: side))
        cache[id] = crop ?? full
        return cache[id]
    }
}
