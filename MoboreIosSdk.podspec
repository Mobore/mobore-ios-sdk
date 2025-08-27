Pod::Spec.new do |spec|
  spec.name         = "MoboreIosSdk"
  spec.version      = "0.1.0"
  spec.summary      = "Mobore iOS SDK for Real User Monitoring"
  spec.description  = "A comprehensive iOS SDK for real user monitoring, crash reporting, and performance tracking."
  spec.homepage     = "https://github.com/mobore/mobore-ios-sdk"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Mobore" => "team@mobore.com" }
  spec.platform     = :ios, "16.0"
  spec.source       = { :path => "." }
  spec.source_files = "Sources/mobore-ios-sdk/**/*.{swift,h,m}"
  spec.resource_bundles = {
    'MoboreIosSdk' => ['Sources/mobore-ios-sdk/Resources/**/*']
  }
  spec.requires_arc = true
  spec.static_framework = true

  # OpenTelemetry dependencies
  spec.dependency 'OpenTelemetryApi', '~> 2.0'
  spec.dependency 'OpenTelemetrySdk', '~> 2.0'
  spec.dependency 'PersistenceExporter', '~> 2.0'
  spec.dependency 'URLSessionInstrumentation', '~> 2.0'
  spec.dependency 'ResourceExtension', '~> 2.0'

  # Other dependencies
  spec.dependency 'Kronos', '~> 4.2'
  spec.dependency 'PLCrashReporter', '~> 1.12'
  spec.dependency 'NIOConcurrencyHelpers', '~> 2.0'
end
