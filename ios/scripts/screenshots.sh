#!/usr/bin/env bash
# Builds the app for the simulator and captures App Store screenshots from the
# built-in demo data (launch argument `-demo <scenario>`, see DemoData.swift).
#
# Usage: ios/scripts/screenshots.sh [output-dir]   (default ios/fastlane/screenshots/en-US)
# Runs on macOS with Xcode. CI calls it from ios.yml and ios-release.yml.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${1:-$ROOT/ios/fastlane/screenshots/en-US}"
DERIVED="${DERIVED_DATA_PATH:-${RUNNER_TEMP:-/tmp}/scorekeep-screenshots-derived}"
BUNDLE_ID="co.scorekeep.app"
SCENARIOS=(scoreboard celebration history)

# name pattern | file prefix | accepted App Store sizes (portrait WxH)
DEVICES=(
  "iPhone [0-9]+ Pro Max|iphone-6.9|1320x2868 1290x2796"
  "iPad Pro 13-inch.*|ipad-13|2064x2752 2048x2732"
)

mkdir -p "$OUT"
rm -f "$OUT"/*.png

xcodebuild build \
  -project "$ROOT/ios/Scorekeep.xcodeproj" \
  -scheme Scorekeep \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" \
  -quiet \
  CODE_SIGNING_ALLOWED=NO
APP="$DERIVED/Build/Products/Release-iphonesimulator/Scorekeep.app"

for entry in "${DEVICES[@]}"; do
  IFS='|' read -r pattern prefix sizes <<<"$entry"
  udid="$(python3 "$ROOT/ios/scripts/find_simulator.py" "$pattern")"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" appearance dark || true
  xcrun simctl status_bar "$udid" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 --dataNetwork wifi || true
  xcrun simctl install "$udid" "$APP"

  n=1
  for scenario in "${SCENARIOS[@]}"; do
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" -demo "$scenario" >/dev/null
    # Celebration: catch the confetti mid-fall. Others: let sheets finish animating.
    if [ "$scenario" = celebration ]; then sleep 2.5; else sleep 4; fi
    file="$OUT/${prefix}-${n}-${scenario}.png"
    xcrun simctl io "$udid" screenshot --type=png "$file" >/dev/null
    size="$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{print w "x" h}')"
    if [[ " $sizes " != *" $size "* ]]; then
      echo "::error::$file is $size; App Store accepts $sizes for this device class" >&2
      exit 1
    fi
    echo "Captured $file ($size)"
    n=$((n + 1))
  done
  xcrun simctl shutdown "$udid" || true
done
