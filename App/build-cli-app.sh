#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release --product EngineCLI 2>&1 | grep -E 'error:|complete!' | tail -5
[[ ${pipestatus[1]} -eq 0 ]]
APP=.build/EngineCLI.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/EngineCLI "$APP/Contents/MacOS/EngineCLI"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.gabi.tapspike</string>
  <key>CFBundleName</key><string>EngineCLI</string>
  <key>CFBundleExecutable</key><string>EngineCLI</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAudioCaptureUsageDescription</key><string>Ajusta o volume de apps individualmente. Nenhum audio e gravado ou enviado.</string>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP" 2>&1 | tail -1
echo "built $APP"
