# Reproduction

## Toolchain

- Xcode 27.0 (build 27A5237l)
- Swift 6 with complete strict concurrency
- XcodeGen
- iOS deployment target 17.0
- Verification runtimes: iOS 26.5 and iOS 27.0, iPhone 17 Pro simulator

## Generate and inspect

```sh
xcodegen generate
git diff --check
plutil -p ServoGrid/Resources/Info.plist
```

The plist must contain `BGTaskSchedulerPermittedIdentifiers` with `com.sidkrishnan.ServoGrid.refresh` and `UIBackgroundModes` with `fetch`.

## Build and test on the latest installed simulator

```sh
xcrun simctl list devices available
xcodebuild build-for-testing \
  -project ServoGrid.xcodeproj \
  -scheme ServoGrid \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO
xcodebuild test-without-building \
  -project ServoGrid.xcodeproj \
  -scheme ServoGrid \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Focused commands use `-only-testing:ServoGridTests` or `-only-testing:ServoGridUITests`. Add `-collect-test-diagnostics never` for a faster known-good UI replay, or omit it when diagnosing a failure.

## Compile for physical iPhone without signing

```sh
xcodebuild build \
  -project ServoGrid.xcodeproj \
  -scheme ServoGrid \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DeviceDerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Actual device installation needs a configured development team, a compatible connected/unlocked device, and valid signing. Do not treat a generic compile as an install.

During the recorded verification, the first CoreDevice attempt could not mount the developer disk image because the phone was locked. After the phone was unlocked and kept awake, the same Xcode installation mounted its services, installed ServoGrid, launched `com.sidkrishnan.ServoGrid`, and returned both an installed-app record and a running process. A generic compile alone remains insufficient evidence.

The verified physical-device sequence was:

```sh
xcodebuild build \
  -project ServoGrid.xcodeproj \
  -scheme ServoGrid \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DeviceSigned \
  DEVELOPMENT_TEAM='<your-team-id>' \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration
xcrun devicectl device install app --device '<device-id>' \
  .build/DeviceSigned/Build/Products/Debug-iphoneos/ServoGrid.app
xcrun devicectl device process launch --device '<device-id>' \
  com.sidkrishnan.ServoGrid
xcrun devicectl device info apps --device '<device-id>' \
  --bundle-id com.sidkrishnan.ServoGrid
xcrun devicectl device info processes --device '<device-id>' \
  --search ServoGrid
```

## Install and launch the built simulator app manually

Replace `<UDID>` with a booted simulator identifier from `simctl list`.

```sh
xcrun simctl bootstatus <UDID> -b
xcrun simctl install <UDID> .build/DerivedData/Build/Products/Debug-iphonesimulator/ServoGrid.app
xcrun simctl launch <UDID> com.sidkrishnan.ServoGrid -ui-testing
```

The checked-in evidence frames under `docs/screenshots/ios27-evidence` were attached by the UI evidence journey, exported from its `.xcresult`, and visually inspected.
