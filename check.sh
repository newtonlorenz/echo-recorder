#!/bin/bash
set -euo pipefail
task_root="$(cd -- "$(dirname -- "$0")" && pwd)"
mkdir -p "$task_root/build"
xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macos14.0" \
  "$task_root/Sources/AudioFiles.swift" "$task_root/Tests/AudioChecks.swift" \
  -o "$task_root/build/AudioChecks"
"$task_root/build/AudioChecks"

xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macos14.0" \
  "$task_root/Sources/SpectrumAnalysis.swift" "$task_root/Tests/SpectrumChecks.swift" \
  -o "$task_root/build/SpectrumChecks"
"$task_root/build/SpectrumChecks"
