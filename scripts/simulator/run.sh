#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
work=$(mktemp -d)
app="$work/Host.app"
mkdir -p "$app/Frameworks" "$app/AMARYTKit"
arch=$(uname -m)
cc=(xcrun --sdk iphonesimulator clang -target "$arch-apple-ios16.0-simulator" -fobjc-arc -fblocks)
"${cc[@]}" -dynamiclib source/AMARYTKit.m -framework UIKit -framework WebKit -framework Foundation -framework JavaScriptCore -framework CoreGraphics -framework QuartzCore -install_name @rpath/AMARYTKit.dylib -o "$app/Frameworks/AMARYTKit.dylib"
"${cc[@]}" scripts/simulator/Host.m -framework CoreGraphics -framework Foundation -framework UIKit -Wl,-rpath,@executable_path/Frameworks -Wl,-needed_library,"$app/Frameworks/AMARYTKit.dylib" -o "$app/Host"
cp config.json mods.json source/policy.js source/panel.html "$app/AMARYTKit/"
python3 - "$app" <<'PY'
import json,sys,plistlib
from pathlib import Path
app=Path(sys.argv[1])
cfg=app/'AMARYTKit/config.json';d=json.loads(cfg.read_bytes());d['welcome']['title']='أهلًا بك في AMAR YT';cfg.write_text(json.dumps(d))
(app/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier='test.amaryt.launcher',CFBundleExecutable='Host',CFBundleName='Host',CFBundlePackageType='APPL',CFBundleVersion='1',CFBundleShortVersionString='1',MinimumOSVersion='16.0',UIDeviceFamily=[1,2],UILaunchScreen={})))
PY
codesign -fs - "$app/Frameworks/AMARYTKit.dylib"
codesign -fs - "$app"
udid=$(xcrun simctl list devices available --json | python3 -c "import json,sys; print(next(d['udid'] for ds in reversed(list(json.load(sys.stdin)['devices'].values())) for d in ds if 'iPad' in d['name']))")
xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" "$app"
data=$(xcrun simctl get_app_container "$udid" test.amaryt.launcher data)
rm -f "$data/Documents/result.txt"
xcrun simctl launch "$udid" test.amaryt.launcher
for ((i=0;i<45;i++)); do
  if [[ -s "$data/Documents/result.txt" ]]; then cat "$data/Documents/result.txt"; grep -q '^PASS' "$data/Documents/result.txt"; exit; fi
  sleep 1
done
cat "$data/Documents/AMARYT-debug.txt" || true
exit 1
