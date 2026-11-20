import Foundation
import IOKit.ps

/// Frame rate policy. A screensaver host pushes the whole screen every frame, so frame rate is the main power lever.
public enum Power {
    public static var onBattery: Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String? else { return false }
        return type == kIOPSBatteryPowerValue
    }
    public static func frameRate(settings: ClockSettings, displayMax: Int) -> Int {
        settings.reduceOnBattery && (onBattery || ProcessInfo.processInfo.isLowPowerModeEnabled) ? min(30, displayMax) : displayMax
    }
}
