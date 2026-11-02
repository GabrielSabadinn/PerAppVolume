#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
[[ -f Local.xcconfig ]] || echo "PER_APP_VOLUME_TOKEN = $(openssl rand -hex 32)" > Local.xcconfig
xcodegen generate >/dev/null
xcodebuild -project PerAppVolume.xcodeproj -scheme PerAppVolume -configuration Release -derivedDataPath .build/xcode build -allowProvisioningUpdates 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)' | grep -v CoreSimulator | sort -u
[[ ${pipestatus[1]} -eq 0 ]]
BUILT="$PWD/.build/xcode/Build/Products/Release/PerAppVolume.app"
APP="/Applications/PerAppVolume.app"
pkill -x PerAppVolume || true
rm -rf "$APP"
ditto "$BUILT" "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" >/dev/null
pluginkit -r "$BUILT/Contents/PlugIns/SafariExtension.appex" 2>/dev/null || true
pluginkit -a "$APP/Contents/PlugIns/SafariExtension.appex" 2>/dev/null || true
pluginkit -e use -i com.gabi.perappvolume.safari
open "$APP"
echo "$APP"
