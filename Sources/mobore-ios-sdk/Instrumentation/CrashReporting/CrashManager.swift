#if !os(watchOS)
import CrashReporter
#endif
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

import os.log

#if !os(watchOS)
struct CrashManager {
  static let crashEventName: String = "crash"
  static let crashManagerVersion = "0.0.1"
  static let lastResourceDefaultsKey: String = "mobore.last.resource"
  static let instrumentationName = "CrashReporter"
  let lastResource: Resource
  private let logger = OSLog(subsystem: "com.mobore.crash-reporter", category: "instrumentation")
  init(resource: Resource, logExporter: LogRecordExporter, agentConfiguration: AgentConfiguration) {
    // if something went wrong with the lastResource in the user defaults, fallback of the current resource data.
    var tempResource = resource

    if let lastResourceJson = UserDefaults.standard.data(forKey: Self.lastResourceDefaultsKey) {
      do {
        let decoder = JSONDecoder()
        tempResource = try decoder.decode(Resource.self, from: lastResourceJson)
      } catch {
        os_log("initialization: unable to load last Resource from user defaults.",
               log: logger,
               type: .error)
      }
    }
    lastResource = tempResource

    do {
      let encoder = JSONEncoder()
      let data = try encoder.encode(resource)
      UserDefaults.standard.set(data, forKey: Self.lastResourceDefaultsKey)
    } catch {
      os_log("initialization: unable to save current Resource from user defaults.", log: logger,  type: .error)

    }
  }


  public func initializeCrashReporter(configuration: CrashManagerConfiguration) {
    // It is strongly recommended that local symbolication only be enabled for non-release builds.
    // Use [] for release versions.
    let signalHandler: PLCrashReporterSignalHandlerType = configuration.allowWhenDebuggerAttached ? .BSD : getSignalHandler()
    let config = PLCrashReporterConfig(signalHandlerType: signalHandler, symbolicationStrategy: [])
    guard let crashReporter = PLCrashReporter(configuration: config) else {
      os_log("Could not create an instance of PLCrashReporter", log: logger, type: .error)
      return
    }

    // Enable the Crash Reporter.
    do {
      if configuration.allowWhenDebuggerAttached || !isDebuggerAttached() {
        try crashReporter.enableAndReturnError()
      } else {
        os_log("Debugger attached; crash reporter not enabled.", log: logger, type: .info)
      }
    } catch let error {
      os_log("Warning: Could not enable crash reporter: %@",
             log: logger,
             type: .error,
             error.localizedDescription)
    }

    // Try loading the crash report.
    if crashReporter.hasPendingCrashReport() {
      do {
        let data = try crashReporter.loadPendingCrashReportDataAndReturnError()
        let otLogger = OpenTelemetry
          .instance
          .loggerProvider
          .loggerBuilder(instrumentationScopeName: Self.instrumentationName)
          .setInstrumentationVersion(Self.crashManagerVersion)
          .setEventDomain("device")
          .build()

        // Retrieving crash reporter data.
        let report = try PLCrashReport(data: data)

        if let text = PLCrashReportTextFormatter.stringValue(
          for: report, with: PLCrashReportTextFormatiOS) {

            
          var attributes = [
            SemanticAttributes.exceptionType.rawValue: AttributeValue.string(report.signalInfo.name),
            SemanticAttributes.exceptionStacktrace.rawValue: AttributeValue.string(text)
          ]
          // TODO:get from lastResource
          if let lastSessionId = configuration.sessionId {
            attributes[MoboreAttributes.sessionId.rawValue] = AttributeValue.string(lastSessionId)
          }

          if let lastNetworkStatus = configuration.networkStatus {
            attributes[SemanticAttributes.networkConnectionType.rawValue] = AttributeValue.string(lastNetworkStatus)
          }
          if let code = report.signalInfo.code {
              attributes[SemanticAttributes.exceptionMessage.rawValue] = AttributeValue.string(
              "\(code) at \(report.signalInfo.address)")
          }
            
            otLogger.eventBuilder(name: Self.crashEventName)
            .setSeverity(.fatal)
            .setAttributes(attributes)
            .emit()
        } else {
          os_log("CrashReporter: can't convert report to text",log: self.logger, type: .error)
        }
      } catch let error {
        os_log("CrashReporter failed to load and parse with error: %@",
               log: logger,
               type: .error,
               error.localizedDescription)
      }

    }

    // Purge the report.
    crashReporter.purgePendingCrashReport()
  }

  
  private func getSignalHandler() -> PLCrashReporterSignalHandlerType {
    #if os(tvOS)
      return .BSD
    #else
      return .mach
    #endif
  }
  
  private func isDebuggerAttached() -> Bool {
    var info = kinfo_proc()
    let infoSize = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    infoSize[0] = MemoryLayout<kinfo_proc>.size
    let name = UnsafeMutablePointer<Int32>.allocate(capacity: 4)

    name[0] = CTL_KERN
    name[1] = KERN_PROC
    name[2] = KERN_PROC_PID
    name[3] = getpid()

    if sysctl(name, 4, &info, infoSize, nil, 0) == -1 {
      os_log("sysctl() failed: %@",
             log: logger,
             type:.error,
             String(describing: strerror(errno)))
      return false
    }

    if (info.kp_proc.p_flag & P_TRACED) != 0 {
      return true
    }

    return false
  }
}

#endif // !os(watchOS)
