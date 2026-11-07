# Install and Run

Requires a Mac, Xcode 27.2 or later as the project target, and an iOS 27.0+ simulator or device. No third-party package, backend, or Figma service is required. Prefer a local, nonsynced development folder for the checkout and build products.

## Xcode

1. Open `LeadersBook.xcodeproj` and select the **LeadersBook** scheme.
2. Choose an iPhone Duo when available, or an installed iPhone/iPad for compact/expanded previews.
3. For a physical device, select your development team and registered bundle identifier in Signing & Capabilities, then run. Debug and Release use system biometrics/device-passcode authentication.

## Command Line

```sh
./script/build_and_run.sh --build   # Unsigned simulator build
./script/build_and_run.sh           # Build, install, and launch
xcrun simctl list devices available # Find a simulator UUID
SIMULATOR_UDID=YOUR_SIMULATOR_UDID ./script/build_and_run.sh
SIMULATOR_UDID=YOUR_SIMULATOR_UDID ./script/build_and_run.sh --validate
```

Replace `YOUR_SIMULATOR_UDID` with an installed device UUID. Automatic selection prefers Duo, then iPhone 18 Pro, then another iPhone. The launcher opens Simulator when available and otherwise uses CoreSimulator headlessly.

## Validation

`--validate` runs the full core suite, both native test targets in **Testing**, then an unsigned **Release** build. Validation products use the temporary directory. Testing substitutes only the external OS authenticator; Testing archives are rejected. Normal Run uses Debug and Archive uses Release.

```sh
swift test --scratch-path /private/tmp/leaders-book-tests --filter FitnessTests
swift test --scratch-path /private/tmp/leaders-book-tests
```

Recorded validation used Xcode 27.0/iOS 27 SDK. Xcode 27.2+, real Duo displays/folds/reserved regions, physical authentication, accessibility, and signed distribution still need verification. See [Current Audit](docs/ARCHITECTURE-AUDIT.md), [Release-Gate Evidence](docs/validation/release-review-2026-11-06/release-gate.log), and [Wiki](docs/wiki/README.md).
