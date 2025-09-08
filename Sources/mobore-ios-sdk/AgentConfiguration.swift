import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public struct AgentConfiguration {
  init() {}
  /// Whether to enable the agent. Defaults to true.
  public var enableAgent = true
  /// Deployment environment name used in resource attributes.
  public var environment: String = "development"
  /// Collector hostname for exporting telemetry.
  public var collectorHost = "traces.mobore.com"
  /// Collector port. Defaults to 443.
  public var collectorPort = 443
  /// Whether to use TLS when connecting to the collector.
  public var collectorTLS = true
  var auth: String?
  var sampleRate: Double = 1.0

  var spanFilters = [SignalFilter<ReadableSpan>]()
  var logFilters = [SignalFilter<ReadableLogRecord>]()

  var spanAttributeInterceptor: any Interceptor<[String: AttributeValue]> = NoopInterceptor<[String: AttributeValue]>()
  var logRecordAttributeInterceptor: any Interceptor<[String: AttributeValue]> = NoopInterceptor<[String: AttributeValue]>()
}
