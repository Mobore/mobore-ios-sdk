Pod::Spec.new do |spec|
  spec.name         = "MoboreIosSdk"
  spec.version      = "0.1.0"
  spec.summary      = "Mobore iOS SDK for Real User Monitoring"
  spec.description  = "A comprehensive iOS SDK for real user monitoring, crash reporting, and performance tracking."
  spec.homepage     = "https://github.com/mobore/mobore-ios-sdk"
  spec.license      = { :type => "Apache-2.0", :file => "LICENSE" }
  spec.author       = { "Mobore" => "team@mobore.com" }
  spec.ios.deployment_target          = "16.0"

  spec.swift_version = '5.10'
  spec.source       = { :git => 'https://github.com/mobore/mobore-ios-sdk.git', :tag => spec.version.to_s }
  spec.source_files = "Sources/mobore-ios-sdk/**/*.{swift,h,m}"
  spec.resource_bundles = {
    'MoboreIosSdk' => ['Sources/mobore-ios-sdk/Resources/**/*']
  }
  spec.requires_arc = true
  spec.static_framework = true

  # OpenTelemetry dependencies
  spec.dependency "OpenTelemetry-Swift-Sdk", "~> 2.0.0"

  # Other dependencies
  spec.dependency 'Kronos', '~> 4.2'
  spec.dependency 'PLCrashReporter', '~> 1.12'
  spec.dependency 'SwiftNIOConcurrencyHelpers', '~> 2.0'
end
