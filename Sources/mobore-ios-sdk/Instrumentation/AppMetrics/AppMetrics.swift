import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

#if !os(watchOS)
import MetricKit
#endif

#if os(iOS)

@available(iOS 13.0, *)
class AppMetrics: NSObject, MXMetricManagerSubscriber {
  static let instrumentationName = "ApplicationMetrics"
  static let instrumentationVersion = "0.0.3"

  enum LaunchTimeValues: String {
    case key = "type"
    case resume = "resume"
    case optimizedFirstDraw = "optimized first draw"
    case firstDraw = "first draw"
  }

  enum AppExitValues: String {
    case key = "type"
    case resourceLimit = "memoryResourceLimit"
    case watchdog = "watchdog"
    case badAccess = "badAccess"
    case abnormal = "abnormal"
    case illegalInstruction = "illegalInstruction"
    case normal = "normal"
  }

  enum AppExitStates: String {
    case key = "appState"
    case foreground = "foreground"
    case background = "background"
  }

  let meter = OpenTelemetry.instance.meterProvider
    .meterBuilder(name: instrumentationName)
    .build()

  func receiveReports() {
    let shared = MXMetricManager.shared
    shared.add(self)
  }

  func pauseReports() {
    let shared = MXMetricManager.shared
    shared.remove(self)
  }

  func recordTimeToFirstDraw(metric: MXMetricPayload) {
    if let timeToFirstDrawEnumerator = metric.applicationLaunchMetrics?.histogrammedTimeToFirstDraw.bucketEnumerator {
      var histogram = meter.histogramBuilder(name: MoboreMetrics.appLaunchTime.rawValue).build()
      // swiftlint:disable:next force_cast
      for bucket in timeToFirstDrawEnumerator.allObjects as! [MXHistogramBucket] {
        let avg = (bucket.bucketStart.value + bucket.bucketEnd.value) / 2
        let bucketCount = bucket.bucketCount
        if bucketCount > 0 {
          for _ in 0 ..< bucketCount {
            histogram.record(value: avg, attributes: [LaunchTimeValues.key.rawValue: .string(LaunchTimeValues.firstDraw.rawValue)])
          }
        }
      }
    }
  }

  func recordResumeTime(metric: MXMetricPayload) {
    if let resumeTimeEnumerator = metric.applicationLaunchMetrics?.histogrammedApplicationResumeTime.bucketEnumerator {
      var histogram = meter.histogramBuilder(name: MoboreMetrics.appLaunchTime.rawValue).build()

      // swiftlint:disable:next force_cast
      for bucket in resumeTimeEnumerator.allObjects as! [MXHistogramBucket] {
        let avg = (bucket.bucketStart.value + bucket.bucketEnd.value) / 2
        let bucketCount = bucket.bucketCount
        if bucketCount > 0 {
          for _ in 0 ..< bucketCount {
            histogram.record(value: avg, attributes: [LaunchTimeValues.key.rawValue: .string(LaunchTimeValues.resume.rawValue)])
          }
        }
      }
    }
  }

  func recordOptimizedTimeToFirstDraw(metric: MXMetricPayload) {
    if #available(iOS 15.2, *) {
      if let optimizedTimeToFirstDraw = metric.applicationLaunchMetrics?
        .histogrammedOptimizedTimeToFirstDraw
        .bucketEnumerator {
        var histogram = meter.histogramBuilder(name: MoboreMetrics.appLaunchTime.rawValue).build()
        // swiftlint:disable:next force_cast
        for bucket in optimizedTimeToFirstDraw.allObjects as! [MXHistogramBucket] {
          let avg = (bucket.bucketStart.value + bucket.bucketEnd.value) / 2
          let bucketCount = bucket.bucketCount
          if bucketCount > 0 {
            for _ in 0 ..< bucketCount {
              histogram.record(value: avg, attributes: [LaunchTimeValues.key.rawValue: .string(LaunchTimeValues.optimizedFirstDraw.rawValue)])
            }
          }
        }
      }

    }
  }

  func recordHangTime(metric: MXMetricPayload) {
    if let applicationHangTime = metric.applicationResponsivenessMetrics?
      .histogrammedApplicationHangTime
      .bucketEnumerator {
      var histogram = meter.histogramBuilder(name: MoboreMetrics.appHangtime.rawValue).build()
      // swiftlint:disable:next force_cast
      for bucket in applicationHangTime.allObjects as! [MXHistogramBucket] {
        let avg = (bucket.bucketStart.value + bucket.bucketEnd.value) / 2
        let bucketCount = bucket.bucketCount
        if bucketCount > 0 {
          for _ in 0 ..< bucketCount {
            histogram.record(value: avg, attributes: [String: AttributeValue]())
          }
        }
      }
    }
  }

  func recordAppExitsBackground(metric: MXMetricPayload) {
    if #available(iOS 14.0, *) {
      var appExit = meter.counterBuilder(name: MoboreMetrics.appExits.rawValue).build()

      if let backgroundApplicationExit = metric.applicationExitMetrics?.backgroundExitData {
        appExit.add(value: backgroundApplicationExit.cumulativeMemoryResourceLimitExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.background.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.resourceLimit.rawValue)])

        appExit.add(value: backgroundApplicationExit.cumulativeAppWatchdogExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.background.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.watchdog.rawValue)])

        appExit.add(value: backgroundApplicationExit.cumulativeBadAccessExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.background.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.badAccess.rawValue)])

        appExit.add(value: backgroundApplicationExit.cumulativeAbnormalExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.background.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.abnormal.rawValue)])

        appExit.add(value: backgroundApplicationExit.cumulativeIllegalInstructionExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.background.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.illegalInstruction.rawValue)])

        appExit.add(value: backgroundApplicationExit.cumulativeNormalAppExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.background.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.normal.rawValue)])
      }

    }
  }

  func recordAppExitsForeground(metric: MXMetricPayload) {
    if #available(iOS 14.0, *) {
      var appExit = meter.counterBuilder(name: MoboreMetrics.appExits.rawValue).build()
      if let foregroundApplicationExit = metric.applicationExitMetrics?.foregroundExitData {
        appExit.add(value: foregroundApplicationExit.cumulativeMemoryResourceLimitExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.foreground.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.resourceLimit.rawValue)])

        appExit.add(value: foregroundApplicationExit.cumulativeAppWatchdogExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.foreground.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.watchdog.rawValue)])

        appExit.add(value: foregroundApplicationExit.cumulativeBadAccessExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.foreground.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.badAccess.rawValue)])

        appExit.add(value: foregroundApplicationExit.cumulativeAbnormalExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.foreground.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.abnormal.rawValue)])

        appExit.add(value: foregroundApplicationExit.cumulativeIllegalInstructionExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.foreground.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.illegalInstruction.rawValue)])

        appExit.add(value: foregroundApplicationExit.cumulativeNormalAppExitCount,
                    attributes: [AppExitStates.key.rawValue: .string(AppExitStates.foreground.rawValue),
                                 AppExitValues.key.rawValue: .string(AppExitValues.normal.rawValue)])
      }
    }
  }

  // Receive daily metrics.

  func didReceive(_ payloads: [MXMetricPayload]) {
    // Process metrics.

    for metric in payloads {

      recordTimeToFirstDraw(metric: metric)

      recordResumeTime(metric: metric)

      recordOptimizedTimeToFirstDraw(metric: metric)

      recordHangTime(metric: metric)

      recordAppExitsForeground(metric: metric)

      recordAppExitsBackground(metric: metric)
    }
  }

  // Receive diagnostics immediately when available.
  @available(iOS 14.0, *)
  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    // Process diagnostics.
  }

}
#endif
