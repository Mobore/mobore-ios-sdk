#if !os(watchOS)
import CrashReporter
import Kronos
#endif
import Foundation
 
import OpenTelemetryApi
import OpenTelemetrySdk
import os.log

public class MoboreIosSdkAgent {
 public static let name = "mobore-ios-sdk"

  public static func start(
    with configuration: AgentConfiguration,
    _ instrumentationConfiguration: InstrumentationConfiguration = InstrumentationConfiguration()
  ) {
    if !configuration.enableAgent {
      os_log("Mobore iOS SDK has been disabled.")
      return
    }
    #if !os(watchOS)
    Kronos.Clock.sync()
    #endif

    instance = MoboreIosSdkAgent(
      configuration: configuration, instrumentationConfiguration: instrumentationConfiguration)
  }

  public static func start() {
    MoboreIosSdkAgent.start(with: AgentConfiguration())
  }

  public class func shared() -> MoboreIosSdkAgent? {
    instance
  }

  private static var instance: MoboreIosSdkAgent?

  let instrumentation: InstrumentationWrapper

  #if !os(watchOS)
  let crashManager: CrashManager?
  #endif

  let crashLogExporter: LogRecordExporter

  let agentConfigManager: AgentConfigManager

  let openTelemetry: OpenTelemetryInitializer

  let sessionSampler: SessionSampler

  let crashConfig = CrashManagerConfiguration()

  private init(
    configuration: AgentConfiguration, instrumentationConfiguration: InstrumentationConfiguration
  ) {
    crashConfig.sessionId = SessionManager.instance.session(false)
    #if os(iOS) && !targetEnvironment(macCatalyst)
      crashConfig.networkStatus = NetworkStatusManager().lastStatus
    #endif // os(iOS) && !targetEnvironment(macCatalyst)

    crashConfig.allowWhenDebuggerAttached = instrumentationConfiguration.enableCrashReportingInDebugMode

    _ = SessionManager.instance.session()  // initialize session
    agentConfigManager = AgentConfigManager(
      resource: AgentResource.get(environment: configuration.environment).merging(other: AgentEnvResource.get()), config: configuration,
      instrumentationConfig: instrumentationConfiguration)

    sessionSampler = SessionSampler({
      configuration.sampleRate
    })

    instrumentation = InstrumentationWrapper(config: agentConfigManager)

    openTelemetry = OpenTelemetryInitializer(sessionSampler: sessionSampler)
    crashLogExporter = openTelemetry.initializeWithHttp(agentConfigManager)

    #if !os(watchOS)
    if instrumentationConfiguration.enableCrashReporting {
      crashManager = CrashManager(
        resource: AgentResource.get(environment: configuration.environment).merging(other: AgentEnvResource.get()),
        logExporter: crashLogExporter,
        agentConfiguration: configuration)
    } else {
      crashManager = nil
    }
    #endif

    os_log("Initializing Mobore iOS SDK.")

    Task { @MainActor in
      instrumentation.initalize()
    }

    #if !os(watchOS)
    if agentConfigManager.instrumentation.enableCrashReporting {
      crashManager?.initializeCrashReporter(configuration: crashConfig)
    }
    #endif
  }

  deinit {}
}
