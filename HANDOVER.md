# CI Workflow Implementation - Handover Document

## Summary
Task: Add GitHub Actions workflow to compile and validate the Mobore iOS SDK project using CocoaPods.

**Current Status**: Fixes pushed (CI upgraded to macOS 15, Concurrency fixed). CI running.

**PR**: https://github.com/Mobore/mobore-ios-sdk/pull/1  
**Branch**: `ci/add-github-workflow`

---

## What Was Done

### 1. Dependencies Updated (Committed)
- `opentelemetry-swift`: 2.2.1 → 2.3.0
- `Kronos`: 4.2.2 → 4.3.1
- `PLCrashReporter`: 1.12.0 → 1.12.2
- Aligned all OpenTelemetry podspec deps to 2.3.0

### 2. TODOs Fixed (Committed)
- **MoboreCrashManager.swift**: Now uses `lastResource.attributes` to get session ID from crash time
- **MoboreAppMetrics.swift**: Implemented `didReceive(_: [MXDiagnosticPayload])` for MetricKit diagnostics

### 3. CI Workflow Created (Needs Fixing)
File: `.github/workflows/ci.yml`

Current workflow has two jobs:
1. **build-spm**: Builds with Swift Package Manager via xcodebuild
2. **validate-podspec**: Runs `pod lib lint`

### 9. Fixes Applied (Round 6)
- **CI Environment**: Upgraded GitHub Actions workflow to use `macos-15` and `Xcode 16.0`.
    - **Reason**: The `opentelemetry-swift` 2.3.0 dependency chain includes `grpc-swift` 1.27.1, which mandates Swift 6 tools (available only in Xcode 16+). The previous `macos-14` runner with Xcode 15.4 was insufficient.
- **PushNotificationInstrumentation.swift**:
    - Removed incorrect usage of `@preconcurrency` on the class inheritance clause.
    - Moved `@preconcurrency` to the `import UserNotifications` statement.
    - Updated `MoborePushDelegateProxy` to use `nonisolated` delegate methods wrapping logic in `Task { @MainActor in ... }` to satisfy strict concurrency checking in Swift 6.

### 10. Fixes Applied (Round 7)
- **OpenTelemetry API Alignment**: Fixed several incorrect OTel Swift API usages that were likely causing compilation errors during `pod lib lint`:
    - Replaced non-existent `eventBuilder(name:)` and `setEventDomain(_:)` with standard `logRecordBuilder()` and `emit()` calls in `MoboreAppMetrics`, `MoboreCrashManager`, and `MoboreIosSdkAgent`.
    - Corrected asynchronous gauge instrumentation in `MoboreCPUSampler` and `MoboreMemorySampler` to use `observe()` instead of `record()` within callbacks.
    - Removed incorrect `mutating` keywords from `MoboreSpanProcessor` methods to comply with the `SpanProcessor` protocol.
- **SwiftUI Module Reference**: Updated `SwiftUICore.View` to `SwiftUI.View` in `MoboreViewControllerInstrumentation` for broader compatibility.
- **Project Structure**: Fixed a typo in the directory name from `OpenTelementry Extensions` to `OpenTelemetry Extensions`.

The `pod lib lint` step is failing. Without access to the full GitHub Actions logs (requires sign-in), the exact error is unknown.

### Common Causes for `pod lib lint` Failures

1. **Swift compilation errors** in the source files
2. **Dependency resolution issues** with OpenTelemetry pods
3. **Missing imports** or type mismatches
4. **Architecture issues** (arm64 simulator exclusions in podspec)

---

## Files Changed

```
.github/workflows/ci.yml          # NEW - CI workflow
Package.swift                      # Updated dependency versions
MoboreIosSdk.podspec              # Updated dependency versions
Sources/mobore-ios-sdk/Instrumentation/CrashReporting/MoboreCrashManager.swift
Sources/mobore-ios-sdk/Instrumentation/AppMetrics/MoboreAppMetrics.swift
```

---

## Current Workflow Configuration

```yaml
name: CI - Build and Validate

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-spm:
    name: Build with Swift Package Manager
    runs-on: macos-14
    timeout-minutes: 30
    
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.4'
      - run: swift package resolve
      - run: |
          xcodebuild build \
            -scheme mobore-ios-sdk \
            -destination 'generic/platform=iOS Simulator' \
            -skipPackagePluginValidation \
            CODE_SIGNING_ALLOWED=NO

  validate-podspec:
    name: Validate Podspec
    runs-on: macos-14
    timeout-minutes: 30
    
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.4'
      - run: gem install cocoapods
      - run: pod lib lint MoboreIosSdk.podspec --allow-warnings --skip-tests --skip-import-validation --verbose
```

---

## To Debug Locally

1. Clone the branch:
   ```bash
   git clone git@github.com:Mobore/mobore-ios-sdk.git
   cd mobore-ios-sdk
   git checkout ci/add-github-workflow
   ```

2. Test Swift PM build:
   ```bash
   swift package resolve
   xcodebuild build -scheme mobore-ios-sdk -destination 'generic/platform=iOS Simulator'
   ```

3. Test podspec lint:
   ```bash
   pod lib lint MoboreIosSdk.podspec --allow-warnings --skip-tests --verbose
   ```

4. Check the verbose output for the actual compilation error

---

## Likely Issues to Investigate

### 1. Check MoboreAppMetrics.swift Changes
The new `didReceive(_: [MXDiagnosticPayload])` implementation may have issues:
- `MXDiagnosticPayload` properties like `crashDiagnostics`, `hangDiagnostics` return optionals
- `callStackTree` property access
- iOS version availability (`@available(iOS 14.0, *)`)

### 2. Check MoboreCrashManager.swift Changes
- `lastResource.attributes[MoboreAttributes.sessionId.rawValue]` returns `AttributeValue?`
- Ensure the type is correctly handled

### 3. OpenTelemetry Import Issues
The code uses:
```swift
import OpenTelemetryApi
import OpenTelemetrySdk
```
CocoaPods may have different module names than SPM.

---

## Workflow Run URLs
- First run (failed): https://github.com/Mobore/mobore-ios-sdk/actions/runs/21152317749
- Second run (failed): https://github.com/Mobore/mobore-ios-sdk/actions/runs/21152426489
- Latest commit: `a8775ef` - check status at https://github.com/Mobore/mobore-ios-sdk/commit/a8775ef/checks

---

## Next Steps

1. **Verify CI passes** (Check GitHub Actions)
2. **Merge PR** once green

---

## Contact
Work done by: Amp Agent  
Date: January 19, 2026
