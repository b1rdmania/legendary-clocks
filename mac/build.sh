#!/bin/zsh
# Builds Legendary Clocks.app (and, from step 3, the .saver) with swiftc. No Xcode project.
set -e
cd "${0:A:h}"
APP="build/Legendary Clocks.app"; T=arm64-apple-macos14
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target $T -module-name LegendaryClocks Engine/*.swift App/*.swift \
  -framework AppKit -framework QuartzCore -framework IOKit -framework SwiftUI \
  -o "$APP/Contents/MacOS/Legendary Clocks"
cp -R Resources/* "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Legendary Clocks</string>
  <key>CFBundleDisplayName</key><string>Legendary Clocks</string>
  <key>CFBundleIdentifier</key><string>studio.legendaryclocks.app</string>
  <key>CFBundleExecutable</key><string>Legendary Clocks</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.lifestyle</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
  <key>NSHumanReadableCopyright</key><string>Rendered approximations for personal use.</string>
</dict></plist>
PL
[[ -f Resources/AppIcon.icns ]] && /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
codesign --force --deep -s - "$APP" 2>/dev/null
echo "built $APP"

# ---- Screen saver: a loadable bundle (MH_BUNDLE) whose principal class is LegendaryClocksView
SAVER="build/Legendary Clocks.saver"
rm -rf "$SAVER"; mkdir -p "$SAVER/Contents/MacOS" "$SAVER/Contents/Resources"
swiftc -O -target $T -module-name LegendaryClocksSaver -parse-as-library Engine/*.swift Saver/*.swift \
  -framework AppKit -framework QuartzCore -framework IOKit -framework ScreenSaver \
  -Xlinker -bundle -o "$SAVER/Contents/MacOS/Legendary Clocks"
cp -R Resources/* "$SAVER/Contents/Resources/"
cat > "$SAVER/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Legendary Clocks</string>
  <key>CFBundleIdentifier</key><string>studio.legendaryclocks.saver</string>
  <key>CFBundleExecutable</key><string>Legendary Clocks</string>
  <key>CFBundlePackageType</key><string>BNDL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>NSPrincipalClass</key><string>LegendaryClocksView</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PL
codesign --force -s - "$SAVER" 2>/dev/null
# the app carries the saver so it can install and repair it
cp -R "$SAVER" "$APP/Contents/Resources/"
codesign --force --deep -s - "$APP" 2>/dev/null
file "$SAVER/Contents/MacOS/Legendary Clocks" | sed 's/.*: //'
echo "built $SAVER"
