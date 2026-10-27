#!/usr/bin/env bash
# Build carli for the iOS Simulator, install it and launch it.
#   scripts/sim.sh                 build + run
#   scripts/sim.sh shot <name>     also save light/dark screenshots to screenshots/<name>-{light,dark}.png
#   SIM="iPhone 17 Pro" scripts/sim.sh   pick a simulator by name
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE=dev.jotade.personal
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate --quiet

if [[ -n "${SIM:-}" ]]; then
  UDID=$(xcrun simctl list devices available | grep -m1 "    $SIM (" | grep -oE '[0-9A-F-]{36}')
else
  UDID=$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)
  [[ -z "$UDID" ]] && UDID=$(xcrun simctl list devices available | grep -m1 -E '    iPhone [0-9]+ Pro \(' | grep -oE '[0-9A-F-]{36}')
fi
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator

xcodebuild -project Carli.xcodeproj -scheme Carli -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build build -quiet
xcrun simctl install "$UDID" build/Build/Products/Debug-iphonesimulator/Carli.app
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

if [[ "${1:-}" == "shot" ]]; then
  name=${2:?screenshot name}
  mkdir -p screenshots
  for mode in light dark; do
    xcrun simctl ui "$UDID" appearance "$mode"
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE" -skipLaunch "${@:3}" >/dev/null
    sleep 3
    xcrun simctl io "$UDID" screenshot "screenshots/$name-$mode.png" >/dev/null
  done
  echo "screenshots/$name-light.png screenshots/$name-dark.png"
else
  xcrun simctl launch "$UDID" "$BUNDLE" "$@"
fi
