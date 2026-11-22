#!/usr/bin/env bash
set -eu
cd "$(dirname "$0")/.."
out=${1:?Specify output dylib path}
frameworks=(-framework UIKit -framework WebKit -framework Foundation -framework JavaScriptCore -framework QuartzCore -framework CoreGraphics)
if [[ -z "${ZIG:-}" ]]; then
  xcrun --sdk iphoneos clang -arch arm64 -miphoneos-version-min=13.0 -Oz -fobjc-arc -fblocks -dynamiclib source/AMARYTKit.m "${frameworks[@]}" -lobjc -Wl,-headerpad,4000 -Wl,-install_name,@rpath/AMARYTKit.dylib -o "$out"
else
  : "${IOS_SDK:?Set IOS_SDK}" "${LD64:?Set LD64 to the LLVM Mach-O linker}"
  object=$(mktemp)
  trap 'rm -f "$object"' EXIT
  "$ZIG" cc -target aarch64-ios.13.0 -isysroot "$IOS_SDK" -isystem "$IOS_SDK/usr/include" -F"$IOS_SDK/System/Library/Frameworks" -Oz -fobjc-arc -fblocks -c source/AMARYTKit.m -o "$object"
  "$LD64" -dylib -arch arm64 -platform_version ios 13.0 16.5 -syslibroot "$IOS_SDK" -L"$IOS_SDK/usr/lib" -F"$IOS_SDK/System/Library/Frameworks" "$object" "${frameworks[@]}" -lobjc -lSystem -headerpad 0x4000 -install_name @rpath/AMARYTKit.dylib -o "$out"
fi
