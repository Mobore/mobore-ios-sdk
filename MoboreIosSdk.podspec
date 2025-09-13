Pod::Spec.new do |spec|
  spec.name         = "MoboreIosSdk"
  spec.version      = "0.3.0"
  spec.summary      = "Mobore iOS SDK for Real User Monitoring"
  spec.description  = "A comprehensive iOS SDK for real user monitoring, crash reporting, and performance tracking."
  spec.homepage     = "https://github.com/mobore/mobore-ios-sdk"
  spec.license      = { :type => "Commercial", :text => "Copyright 2025 Mobore.com" }
  spec.author       = { "Mobore" => "team@mobore.com" }
  spec.documentation_url = "https://docs.mobore.com"
  spec.platform = :ios, '16.0'
  spec.ios.deployment_target          = "16.0"

  spec.swift_version = '5.10'
  spec.pod_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64'
  }
  spec.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64'
  }
  
  spec.source           = { :git => "https://github.com/mobore/mobore-ios-sdk.git", :tag => spec.version.to_s }
  spec.source_files = "Sources/mobore-ios-sdk/**/*.{swift,h,m}"
  spec.resource_bundles = {
    'MoboreIosSdk' => ['Sources/mobore-ios-sdk/Resources/**/*']
  }
  spec.requires_arc = true
  spec.static_framework = true

  # OpenTelemetry dependencies
  spec.dependency "OpenTelemetry-Swift-Sdk", "~> 2.1.0"
  spec.dependency "OpenTelemetry-Swift-SdkResourceExtension", "~> 2.1.0"
  spec.dependency "OpenTelemetry-Swift-PersistenceExporter", "~> 2.1.0"
  spec.dependency "OpenTelemetry-Swift-Instrumentation-URLSession", "~> 2.1.0"
  spec.dependency "OpenTelemetry-Swift-Protocol-Exporter-Http", "~> 2.1.0"
  spec.dependency "OpenTelemetry-Swift-Instrumentation-NetworkStatus", "~> 2.1.0"
  # spec.dependency "OpenTelemetry-Swift-BaggagePropagationProcessor", "~> 2.1.0"

  # Other dependencies
  spec.dependency 'Kronos', '~> 4.2'
  spec.dependency 'PLCrashReporter', '~> 1.12'
end
