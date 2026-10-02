#!/bin/bash
set -euo pipefail
task_root="$(cd -- "$(dirname -- "$0")" && pwd)"
task_arch="$(uname -m)"
task_app="$task_root/build/Echo Recorder.app"
mkdir -p "$task_app/Contents/MacOS"
xcrun swiftc -swift-version 5 -O -target "$task_arch-apple-macos14.0" \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  "$task_root"/Sources/*.swift -o "$task_app/Contents/MacOS/EchoRecorder"
cp "$task_root/Info.plist" "$task_app/Contents/Info.plist"
/usr/bin/xattr -cr "$task_app"
codesign --force --sign - --entitlements "$task_root/Echo.entitlements" "$task_app"
printf 'Built %s\n' "$task_app"
