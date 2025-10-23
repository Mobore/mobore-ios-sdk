# Mobore iOS SDK

[![Version](https://img.shields.io/badge/version-0.7.2-blue.svg)](https://github.com/mobore/mobore-ios-sdk)
[![License](https://img.shields.io/badge/license-Apache%202.0-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://github.com/mobore/mobore-ios-sdk)

A comprehensive iOS SDK for Real User Monitoring (RUM), crash reporting, and performance tracking. Monitor your iOS apps with actionable insights using OpenTelemetry-based observability.

## Features

### 🔍 **Auto-Instrumentation**
- **View Controller Tracking**: Automatic view lifecycle monitoring
- **Network Requests**: URLSession instrumentation with detailed request/response metrics
- **Crash Reporting**: Comprehensive crash detection and reporting (PLCrashReporter)
- **App Lifecycle**: Application state transitions and lifecycle events
- **System Metrics**: CPU usage, memory consumption, and device performance
- **User Interactions**: Tap gestures and UI interaction tracking
- **Push Notifications**: Notification delivery and engagement tracking
- **WebView Monitoring**: Web content loading and performance
- **Low Power Mode**: Battery optimization detection
- **App Hangs**: ANR (Application Not Responding) detection
- **Session Usage**: Active usage time and inactivity tracking

### 📊 **Manual Instrumentation APIs**
- **Custom Views**: `startView()` / `endCurrentView()` for manual view tracking
- **User Actions**: `addAction()` for custom user interaction events
- **Error Tracking**: `addError()` for custom error reporting
- **Logging**: `addLog()` for structured logging with multiple severity levels
- **Performance Timing**: `addTiming()` for custom performance measurements
- **User Context**: `setUser()` for user identification and attributes
- **Custom Attributes**: Global, session, and view-scoped attribute management

### 🔧 **Advanced Configuration**
- **Sampling**: Configurable session sampling rates
- **Filtering**: URL filtering for network requests
- **Environment Support**: Development, staging, production environments
- **Custom Collectors**: Flexible OpenTelemetry collector configuration
- **Privacy Compliance**: Built-in privacy manifest support

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/mobore/mobore-ios-sdk.git", .upToNextMajor(from: "0.7.0"))
]
```

Or add it directly in Xcode:
1. Go to **File > Add Packages**
2. Enter `https://github.com/mobore/mobore-ios-sdk.git`
3. Select the version you want to use

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'MoboreIosSdk', '~> 0.7.0'
```

Then run:
```bash
pod install
```

## Quick Start

### Basic Setup

1. **Import the SDK** in your `AppDelegate.swift` or main application file:

```swift
import MoboreIosSdk
```

2. **Initialize the SDK** early in your app lifecycle:

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Initialize Mobore SDK
    MoboreIosSdkAgent.start()

    return true
}
```

### Advanced Configuration

For more control over SDK behavior, configure it explicitly. You can use either the direct configuration structs or the builder pattern:

#### Using Builder Pattern (Recommended)

```swift
let agentConfig = AgentConfigBuilder()
    .withClientToken("your-client-token-here")
    .withEnvironment("production")
    .withSessionSampleRate(0.1)  // Sample 10% of sessions
    .build()

let instrumentationConfig = InstrumentationConfigBuilder()
    .withCrashReporting(true)
    .withCrashReportingInDebugMode(true)
    .withLogsExport(true)
    .withSystemMetrics(true)
    .withTapInstrumentation(false)  // Disable if privacy concerns
    .build()

MoboreIosSdkAgent.start(with: agentConfig, instrumentationConfig)
```

#### Using Direct Configuration

```swift
let config = AgentConfiguration()
config.environment = "production"
config.sampleRate = 0.1  // Sample 10% of sessions
config.auth = "your-client-token-here"

let instrumentation = InstrumentationConfiguration()
instrumentation.enableCrashReporting = true
instrumentation.enableSystemMetrics = true
instrumentation.enableTapInstrumentation = false  // Disable if privacy concerns

MoboreIosSdkAgent.start(with: config, instrumentation)
```

## Usage Examples

### View Tracking

```swift
// Manual view tracking
MoboreIosSdkAgent.startView(name: "ProductDetails", url: "myapp://products/123")
defer { MoboreIosSdkAgent.endCurrentView() }

// Or use UIViewController-based tracking
MoboreIosSdkAgent.startUIViewControllerView(name: "ProductDetails")
defer { MoboreIosSdkAgent.endUIViewControllerView() }
```

### User Actions

```swift
// Track user interactions
MoboreIosSdkAgent.addAction(
    name: "purchase",
    type: "ecommerce",
    attributes: [
        "product_id": "12345",
        "amount": 99.99,
        "currency": "USD"
    ]
)
```

### Error Tracking

```swift
// Report errors
MoboreIosSdkAgent.addError(
    message: "Failed to load user profile",
    source: "ProfileViewController",
    stack: error.localizedDescription
)
```

### Logging

```swift
// Structured logging
MoboreIosSdkAgent.addLog(
    "User authentication successful",
    level: "info",
    attributes: [
        "user_id": "12345",
        "auth_method": "biometric"
    ]
)
```

### Performance Monitoring

```swift
// Measure custom timings
let startTime = Date()
performExpensiveOperation()
let duration = Date().timeIntervalSince(startTime) * 1000
MoboreIosSdkAgent.addTiming(name: "expensive_operation", durationMs: duration)
```

### User Context

```swift
// Set user information
MoboreIosSdkAgent.setUser([
    "id": "12345",
    "email": "user@example.com",
    "subscription": "premium"
])
```

### Custom Attributes

```swift
// Global attributes (applied to all telemetry)
MoboreIosSdkAgent.addGlobalAttribute(key: "app_version", value: "1.2.3")
MoboreIosSdkAgent.addGlobalAttributes([
    "device_type": "tablet",
    "region": "us-west"
])

// View-specific attributes
MoboreIosSdkAgent.setViewAttribute(key: "screen_category", value: "ecommerce")
MoboreIosSdkAgent.setViewAttributes([
    "product_category": "electronics",
    "has_discount": "true"
])

// View events
MoboreIosSdkAgent.addViewEvent(name: "scroll_to_bottom", attributes: [
    "scroll_depth": 100,
    "time_spent": 45.2
])
```

## Configuration Options

### AgentConfigBuilder Methods

The builder pattern provides a fluent API for configuring the agent:

| Method | Parameter | Description |
|--------|-----------|-------------|
| `withClientToken(_:)` | `String` | Set the client authentication token |
| `withEnvironment(_:)` | `String` | Set deployment environment ("development", "staging", "production") |
| `withExportUrl(_:)` | `URL` | Set custom collector endpoint URL |
| `withSessionSampleRate(_:)` | `Double` | Set session sampling rate (0.0-1.0) |
| `disableAgent()` | - | Disable the agent completely |
| `addSpanFilter(_:)` | `@escaping (ReadableSpan) -> Bool` | Add custom span filtering logic |
| `addLogFilter(_:)` | `@escaping (ReadableLogRecord) -> Bool` | Add custom log filtering logic |

### InstrumentationConfigBuilder Methods

Configure which instrumentations to enable/disable:

| Method | Parameter | Default | Description |
|--------|-----------|---------|-------------|
| `withCrashReporting(_:)` | `Bool` | `true` | Enable crash reporting |
| `withCrashReportingInDebugMode(_:)` | `Bool` | `false` | Allow crash reporting in debug builds |
| `withURLSessionInstrumentation(_:)` | `Bool` | `true` | Network request tracking |
| `withViewControllerInstrumentation(_:)` | `Bool` | `true` | UIViewController lifecycle tracking |
| `withAppMetricInstrumentation(_:)` | `Bool` | `true` | App performance metrics |
| `withSystemMetrics(_:)` | `Bool` | `true` | CPU, memory, battery metrics |
| `withLifecycleEvents(_:)` | `Bool` | `true` | App lifecycle events |
| `withHangInstrumentation(_:)` | `Bool` | `true` | ANR detection |
| `withLowPowerModeInstrumentation(_:)` | `Bool` | `true` | Battery optimization detection |
| `withTapInstrumentation(_:)` | `Bool` | `true` | UI tap gesture tracking |
| `withExitInstrumentation(_:)` | `Bool` | `true` | App exit tracking |
| `withPushNotificationInstrumentation(_:)` | `Bool` | `true` | Push notification tracking |
| `withWebViewInstrumentation(_:)` | `Bool` | `true` | WebView monitoring |
| `withSessionUsageInstrumentation(_:)` | `Bool` | `true` | Active usage tracking |
| `withLogsExport(_:)` | `Bool` | `false` | Enable log export |
| `withMetricsExport(_:)` | `Bool` | `false` | Enable metrics export |
| `withSessionInactivityThresholdSeconds(_:)` | `Double` | `90.0` | Inactivity timeout in seconds |

### Direct Configuration (Advanced)

For advanced use cases, you can also configure using the structs directly:

#### AgentConfiguration Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enableAgent` | `Bool` | `true` | Whether to enable the agent |
| `environment` | `String` | `"development"` | Deployment environment name |
| `collectorHost` | `String` | `"traces.mobore.com"` | Collector hostname |
| `collectorPort` | `Int` | `443` | Collector port |
| `collectorTLS` | `Bool` | `true` | Use TLS for collector connection |
| `sampleRate` | `Double` | `1.0` | Session sampling rate (0.0-1.0) |
| `auth` | `String?` | `nil` | Client authentication token |

#### InstrumentationConfiguration Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `enableCrashReporting` | `Bool` | `true` | Enable crash reporting |
| `enableCrashReportingInDebugMode` | `Bool` | `false` | Allow crash reporting in debug |
| `enableURLSessionInstrumentation` | `Bool` | `true` | Network request tracking |
| `enableViewControllerInstrumentation` | `Bool` | `true` | UIViewController tracking |
| `enableAppMetricInstrumentation` | `Bool` | `true` | App performance metrics |
| `enableSystemMetrics` | `Bool` | `true` | CPU, memory, battery metrics |
| `enableLifecycleEvents` | `Bool` | `true` | App lifecycle events |
| `enableHangInstrumentation` | `Bool` | `true` | ANR detection |
| `enableLowPowerModeInstrumentation` | `Bool` | `true` | Battery optimization detection |
| `enableTapInstrumentation` | `Bool` | `true` | UI tap gesture tracking |
| `enableExitInstrumentation` | `Bool` | `true` | App exit tracking |
| `enablePushNotificationInstrumentation` | `Bool` | `true` | Push notification tracking |
| `enableWebViewInstrumentation` | `Bool` | `true` | WebView monitoring |
| `enableSessionUsageInstrumentation` | `Bool` | `true` | Active usage tracking |
| `sessionInactivityThresholdSeconds` | `Double` | `90.0` | Inactivity timeout |
| `urlSessionIgnoreSubstrings` | `[String]` | `[]` | URL substrings to ignore |
| `urlSessionIgnoreRegexes` | `[String]` | `[]` | URL regex patterns to ignore |

## Privacy & Security

The Mobore iOS SDK includes a comprehensive privacy manifest and follows Apple's privacy guidelines:

- **Data Collection**: Only collects telemetry data necessary for monitoring
- **Privacy Manifest**: Included in the SDK bundle (`PrivacyInfo.xcprivacy`)
- **Data Minimization**: Configurable sampling and filtering options
- **Secure Transmission**: TLS encryption for all data transmission
- **Local Storage**: Minimal local data storage with encryption

## Requirements

- **iOS**: 16.0+
- **macOS**: 13.0+
- **tvOS**: 16.0+
- **watchOS**: 10.0+
- **Swift**: 5.10+
- **Xcode**: 15.0+

## Dependencies

The SDK uses the following key dependencies:

- **OpenTelemetry Swift**: Core observability framework
- **PLCrashReporter**: Advanced crash reporting
- **Kronos**: NTP time synchronization

## Documentation

For comprehensive documentation, visit [docs.mobore.com](https://docs.mobore.com).

## Support

- **Documentation**: [docs.mobore.com](https://docs.mobore.com)
- **Issues**: [GitHub Issues](https://github.com/mobore/mobore-ios-sdk/issues)
- **Discussions**: [GitHub Discussions](https://github.com/mobore/mobore-ios-sdk/discussions)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
