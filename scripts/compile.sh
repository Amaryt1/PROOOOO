#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
out=${1:?Specify the output dylib path}
if [[ -n "${ZIG:-}" ]]; then
  : "${IOS_SDK:?Set IOS_SDK to the iPhoneOS SDK}"
  compiler=("$ZIG" cc -target aarch64-ios.13.0 -isysroot "$IOS_SDK" -isystem "$IOS_SDK/usr/include" -F"$IOS_SDK/System/Library/Frameworks" -L"$IOS_SDK/usr/lib")
else
  compiler=(xcrun --sdk iphoneos clang -arch arm64 -miphoneos-version-min=13.0)
fi
"${compiler[@]}" -Oz -fobjc-arc -fblocks -dynamiclib source/AMARYTKit.m -framework UIKit -framework WebKit -framework Foundation -framework JavaScriptCore -framework QuartzCore -framework CoreGraphics -lobjc -Wl,-install_name,@rpath/AMARYTKit.dylib -o "$out"
