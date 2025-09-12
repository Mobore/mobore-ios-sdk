//swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "mobore-ios-sdk",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v10),
  ],
  products: [
    // Products define the executables and libraries a package produces, and make them visible to other package.
    .library(name: "MoboreIosSdk", type: .static, targets: ["MoboreIosSdk"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/open-telemetry/opentelemetry-swift", .upToNextMajor(from: "2.1.0")),
    .package(url: "https://github.com/MobileNativeFoundation/Kronos.git", .upToNextMajor(from: "4.2.2")),
    .package(
      url: "https://github.com/microsoft/plcrashreporter.git", .upToNextMajor(from: "1.12.0")),
  ],
  targets: [
    .target(
      name: "MoboreIosSdk",
      dependencies: [
        .product(name: "OpenTelemetryProtocolExporterHTTP", package: "opentelemetry-swift"),
        .product(name: "PersistenceExporter", package: "opentelemetry-swift"),
        .product(name: "URLSessionInstrumentation", package: "opentelemetry-swift"),
        .product(name: "ResourceExtension", package: "opentelemetry-swift"),
        .product(
          name: "Kronos",
          package: "Kronos",
          condition: .when(platforms: [.macOS, .iOS, .tvOS])
        ),
        .product(
          name: "CrashReporter",
          package: "plcrashreporter",
          condition: .when(platforms: [.macOS, .iOS, .tvOS])
        ),
      ],
      path: "Sources/mobore-ios-sdk",
      resources: [
        .process("Resources/PrivacyInfo.xcprivacy")
      ]
    ),
  ]
)
