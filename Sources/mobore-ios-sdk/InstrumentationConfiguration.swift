import Foundation
import PersistenceExporter

public struct InstrumentationConfiguration {
  public var enableCrashReporting = true
  // When true, allow enabling crash reporting even while a debugger is attached (debug builds/testing)
  public var enableCrashReportingInDebugMode = false
  public var enableURLSessionInstrumentation = true
  public var enableViewControllerInstrumentation = true
  public var enableAppMetricInstrumentation = true
  public var enableSystemMetrics = true
  public var enableLifecycleEvents = true
  public var enableHangInstrumentation = true
  public var enableLowPowerModeInstrumentation = true
  public var enableTapInstrumentation = true
  public var enableExitInstrumentation = true
  public var enablePushNotificationInstrumentation = true
  public var enableWebViewInstrumentation = true
  public var enableMetricsExport = false
  public var enableLogsExport = false
  // List of URL substrings; if a request URL starts with any of these, it will not be instrumented
  public var urlSessionIgnoreSubstrings: [String] = []
  // List of regular expression patterns (as strings). If any pattern matches a request URL, it will not be instrumented
  public var urlSessionIgnoreRegexes: [String] = []
  // Whether to exclude exporter endpoints (collector URLs) from instrumentation by default
  public var ignoreExporterURLsByDefault: Bool = true
  public var urlSessionShouldInstrument: ((URLRequest) -> Bool)?
  public init() {}
}
