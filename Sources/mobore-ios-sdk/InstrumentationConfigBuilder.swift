import Foundation
import PersistenceExporter

public class InstrumentationConfigBuilder {
  var enableCrashReporting: Bool?
  var enableCrashReportingInDebugMode: Bool?
  var enableURLSessionInstrumentation: Bool?
  var enableViewControllerInstrumentation: Bool?
  var enableAppMetricInstrumentation: Bool?
  var enableSystemMetrics: Bool?
  var enableLifecycleEvents: Bool?
  var enableHangInstrumentation: Bool?
  var enableLowPowerModeInstrumentation: Bool?
  var enableTapInstrumentation: Bool?
  var enableExitInstrumentation: Bool?
  var enablePushNotificationInstrumentation: Bool?
  var enableWebViewInstrumentation: Bool?
  var enableMetricsExport: Bool?
  var enableLogsExport: Bool?
  var urlSessionShouldInstrument: ((URLRequest) -> Bool)?
  var persistentStorageConfig: PersistencePerformancePreset?
  var urlSessionIgnoreSubstrings: [String]?
  var urlSessionIgnoreRegexes: [String]?
  var ignoreExporterURLsByDefault: Bool?

  public init() {}

  public func withCrashReporting(_ enable: Bool) -> Self {
    self.enableCrashReporting = enable
    return self
  }

  public func withCrashReportingInDebugMode(_ enable: Bool) -> Self {
    self.enableCrashReportingInDebugMode = enable
    return self
  }

  public func withURLSessionInstrumentation(_ enable: Bool) -> Self {
    self.enableURLSessionInstrumentation = enable
    return self
  }

  public func withViewControllerInstrumentation(_ enable: Bool) -> Self {
    self.enableViewControllerInstrumentation = enable
    return self
  }
  public func withAppMetricInstrumentation(_ enable: Bool) -> Self {
    self.enableAppMetricInstrumentation = enable
    return self
  }

  public func withSystemMetrics(_ enable: Bool) -> Self {
    self.enableSystemMetrics = enable
    return self
  }

  public func withLifecycleEvents(_ enable: Bool) -> Self {
    self.enableLifecycleEvents = enable
    return self
  }

  public func withHangInstrumentation(_ enable: Bool) -> Self {
    self.enableHangInstrumentation = enable
    return self
  }

  public func withLowPowerModeInstrumentation(_ enable: Bool) -> Self {
    self.enableLowPowerModeInstrumentation = enable
    return self
  }

  public func withTapInstrumentation(_ enable: Bool) -> Self {
    self.enableTapInstrumentation = enable
    return self
  }

  public func withExitInstrumentation(_ enable: Bool) -> Self {
    self.enableExitInstrumentation = enable
    return self
  }

  public func withPushNotificationInstrumentation(_ enable: Bool) -> Self {
    self.enablePushNotificationInstrumentation = enable
    return self
  }

  public func withWebViewInstrumentation(_ enable: Bool) -> Self {
    self.enableWebViewInstrumentation = enable
    return self
  }

  public func withMetricsExport(_ enable: Bool) -> Self {
    self.enableMetricsExport = enable
    return self
  }

  public func withLogsExport(_ enable: Bool) -> Self {
    self.enableLogsExport = enable
    return self
  }

  public func withURLSessionShouldInstrument(_ shouldInstrument: @escaping (URLRequest) -> Bool) -> Self {
    self.urlSessionShouldInstrument = shouldInstrument
    return self
  }

  public func withURLSessionIgnoreSubstrings(_ list: [String]) -> Self {
    self.urlSessionIgnoreSubstrings = list
    return self
  }

  public func withURLSessionIgnoreRegexes(_ patterns: [String]) -> Self {
    self.urlSessionIgnoreRegexes = patterns
    return self
  }

  public func withIgnoreExporterURLsByDefault(_ ignore: Bool) -> Self {
    self.ignoreExporterURLsByDefault = ignore
    return self
  }


  public func build() -> InstrumentationConfiguration {
    var config = InstrumentationConfiguration()

    if let enableCrashReporting = self.enableCrashReporting {
      config.enableCrashReporting = enableCrashReporting
    }

    if let enableCrashReportingInDebugMode = self.enableCrashReportingInDebugMode {
      config.enableCrashReportingInDebugMode = enableCrashReportingInDebugMode
    }

    if let enableURLSessionInstrumentation = self.enableURLSessionInstrumentation {
      config.enableURLSessionInstrumentation = enableURLSessionInstrumentation
    }

    if let enableViewControllerInstrumentation = self.enableViewControllerInstrumentation {
      config.enableViewControllerInstrumentation = enableViewControllerInstrumentation
    }

    if let enableAppMetricInstrumentation = self.enableAppMetricInstrumentation {
      config.enableAppMetricInstrumentation = enableAppMetricInstrumentation
    }

    if let enableSystemMetrics = self.enableSystemMetrics {
      config.enableSystemMetrics = enableSystemMetrics
    }

    if let enableLifecycleEvents = self.enableLifecycleEvents {
      config.enableLifecycleEvents = enableLifecycleEvents
    }

    if let enableHangInstrumentation = self.enableHangInstrumentation {
      config.enableHangInstrumentation = enableHangInstrumentation
    }

    if let enableLowPowerModeInstrumentation = self.enableLowPowerModeInstrumentation {
      config.enableLowPowerModeInstrumentation = enableLowPowerModeInstrumentation
    }

    if let enableTapInstrumentation = self.enableTapInstrumentation {
      config.enableTapInstrumentation = enableTapInstrumentation
    }

    if let enableExitInstrumentation = self.enableExitInstrumentation {
      config.enableExitInstrumentation = enableExitInstrumentation
    }

    if let enablePushNotificationInstrumentation = self.enablePushNotificationInstrumentation {
      config.enablePushNotificationInstrumentation = enablePushNotificationInstrumentation
    }

    if let enableWebViewInstrumentation = self.enableWebViewInstrumentation {
      config.enableWebViewInstrumentation = enableWebViewInstrumentation
    }

    if let enableMetricsExport = self.enableMetricsExport {
      config.enableMetricsExport = enableMetricsExport
    }

    if let enableLogsExport = self.enableLogsExport {
      config.enableLogsExport = enableLogsExport
    }

    if let urlSessionShouldInstrument = self.urlSessionShouldInstrument {
      config.urlSessionShouldInstrument = urlSessionShouldInstrument
    }

    if let urlSessionIgnoreSubstrings = self.urlSessionIgnoreSubstrings {
      config.urlSessionIgnoreSubstrings = urlSessionIgnoreSubstrings
    }

    if let urlSessionIgnoreRegexes = self.urlSessionIgnoreRegexes {
      config.urlSessionIgnoreRegexes = urlSessionIgnoreRegexes
    }

    if let ignoreExporterURLsByDefault = self.ignoreExporterURLsByDefault {
      config.ignoreExporterURLsByDefault = ignoreExporterURLsByDefault
    }

    return config
  }
}
