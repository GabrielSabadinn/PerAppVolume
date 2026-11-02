#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release 2>&1 | tail -3
APP=.build/TapSpike.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/TapSpike "$APP/Contents/MacOS/TapSpike"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.gabi.tapspike</string>
  <key>CFBundleName</key><string>TapSpike</string>
  <key>CFBundleExecutable</key><string>TapSpike</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.2</string>
  <key>LSUIElement</key><true/>
  <key>NSAudioCaptureUsageDescription</key><string>TapSpike ajusta o volume de apps individualmente. Nenhum audio e gravado ou enviado.</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP" 2>&1 | tail -1
echo "built $APP"
