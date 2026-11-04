#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-run}"
PROJECT="LeadersBook.xcodeproj"
DERIVED="$PWD/build/DerivedData"
BUNDLE_ID="com.leadersbook.app"

if [[ "$MODE" == "--build" ]]; then
    xcodebuild -project "$PROJECT" -scheme LeadersBook -configuration Debug \
        -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" \
        CODE_SIGNING_ALLOWED=NO build
    exit
fi

# A caller can select a specific booted or shutdown device with SIMULATOR_UDID.
DEVICE="${SIMULATOR_UDID:-}"
if [[ -z "$DEVICE" ]]; then
    DEVICE="$(xcrun simctl list devices available -j | python3 -c '
import json,sys
devices=[d for group in json.load(sys.stdin)["devices"].values() for d in group if d["isAvailable"]]
preferred=[d for d in devices if "Duo" in d["name"]]
preferred=preferred or [d for d in devices if "iPhone 18 Pro" == d["name"]]
print((preferred or [d for d in devices if "iPhone" in d["name"]])[0]["udid"])
')"
fi

if ! xcrun simctl list devices booted | /usr/bin/grep -q "$DEVICE"; then
    xcrun simctl boot "$DEVICE"
fi
xcrun simctl bootstatus "$DEVICE" -b
if [[ "$MODE" == "--validate" ]]; then
    # Keep signed build products outside document-provider folders with Finder metadata.
    VALIDATION_ROOT="${TMPDIR:-/tmp}/LeadersBookValidation"
    DERIVED="$VALIDATION_ROOT/DerivedData"
    swift test --scratch-path "$VALIDATION_ROOT/Core" --filter ThemeContrastTests
    xcodebuild -project "$PROJECT" -scheme LeadersBook -configuration Debug \
        -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath "$DERIVED" \
        -only-testing:ThemeAdapterTests CODE_SIGNING_ALLOWED=NO test
    xcodebuild -project "$PROJECT" -scheme LeadersBook -configuration Release \
        -destination 'generic/platform=iOS' -derivedDataPath "$DERIVED" \
        CODE_SIGNING_ALLOWED=NO build
    exit
fi
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcodebuild -project "$PROJECT" -scheme LeadersBook -configuration Debug \
    -destination "platform=iOS Simulator,id=$DEVICE" -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO build
xcrun simctl install "$DEVICE" "$DERIVED/Build/Products/Debug-iphonesimulator/LeadersBook.app"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID"
SIMULATOR_APP="$(xcode-select -p)/Applications/Simulator.app"
if [[ -d "$SIMULATOR_APP" ]]; then
    open "$SIMULATOR_APP" --args -CurrentDeviceUDID "$DEVICE"
else
    echo "App launched in the headless simulator: $DEVICE"
fi
