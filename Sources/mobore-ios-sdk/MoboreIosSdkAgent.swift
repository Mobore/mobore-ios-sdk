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

  // MARK: - Public RUM APIs (new)
  public static func startView(name: String, url: String? = nil) {
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "RUM", instrumentationVersion: MoboreIosSdkAgent.moboreSwiftAgentVersion)
    let span = tracer.spanBuilder(spanName: "view.\(name)")
      .setAttribute(key: "view.name", value: .string(name))
      .setAttribute(key: "view.url", value: .string(url ?? "ios://\(Bundle.main.bundleIdentifier ?? "app")/\(name)"))
      .startSpan()
    OpenTelemetry.instance.contextProvider.setActiveSpan(span)
  }

  public static func endCurrentView() {
    if let active = OpenTelemetry.instance.contextProvider.activeSpan {
      active.end()
      OpenTelemetry.instance.contextProvider.removeContextForSpan(active)
    }
  }

  public static func forceFlush() {
    MoboreSpanProcessor.forceFlushAll(timeout: 2.0)
    MoboreLogRecordProcessor.forceFlushAll(explicitTimeout: 2.0)
  }

  public static func setUser(_ user: [String: String]) {
    var attrs: [String: AttributeValue] = [:]
    for (k, v) in user { attrs["user.\(k)"] = .string(v) }
    GlobalAttributesStore.shared.setMany(attrs)
  }

  public static func addAction(name: String, type: String = "custom", attributes: [String: Any] = [:]) {
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "RUM", instrumentationVersion: MoboreIosSdkAgent.moboreSwiftAgentVersion)
    let builder = tracer.spanBuilder(spanName: "action.\(type).\(name)")
    var attrs: [String: AttributeValue] = [
      "action.name": .string(name),
      "action.type": .string(type)
    ]
    attributes.forEach { key, value in
      switch value {
      case let v as String: attrs[key] = .string(v)
      case let v as Bool: attrs[key] = .bool(v)
      case let v as Double: attrs[key] = .double(v)
      case let v as Int: attrs[key] = .int(v)
      default: break
      }
    }
    attrs.forEach { builder.setAttribute(key: $0.key, value: $0.value) }
    let span = builder.startSpan()
    span.end()
  }

  public static func addError(message: String, source: String? = nil, stack: String? = nil) {
    let logger = OpenTelemetry.instance.loggerProvider.loggerBuilder(instrumentationScopeName: "RUM").setEventDomain("device").build()
    var attrs: [String: AttributeValue] = [
      SemanticAttributes.exceptionMessage.rawValue: .string(message)
    ]
    if let source { attrs["error.source"] = .string(source) }
    if let stack { attrs[SemanticAttributes.exceptionStacktrace.rawValue] = .string(stack) }
    logger.eventBuilder(name: SemanticAttributes.exception.rawValue)
      .setSeverity(.error)
      .setAttributes(attrs)
      .emit()
  }

  public static func addTiming(name: String, durationMs: Double) {
    let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "RUM", instrumentationVersion: MoboreIosSdkAgent.moboreSwiftAgentVersion)
    let span = tracer.spanBuilder(spanName: "timing.\(name)")
      .setAttribute(key: "timing.name", value: .string(name))
      .setAttribute(key: "timing.duration", value: .double(durationMs))
      .startSpan()
    span.end()
  }

  public static func addGlobalAttribute(key: String, value: String) {
    GlobalAttributesStore.shared.set(key: key, value: .string(value))
  }

  public static func addGlobalAttributes(_ attrs: [String: String]) {
    var converted: [String: AttributeValue] = [:]
    for (k, v) in attrs { converted[k] = .string(v) }
    GlobalAttributesStore.shared.setMany(converted)
  }

  public static func removeGlobalAttribute(key: String) {
    GlobalAttributesStore.shared.remove(key: key)
  }

  // View-scoped helpers
  public static func setViewAttribute(key: String, value: String) {
    if let span = OpenTelemetry.instance.contextProvider.activeSpan {
      span.setAttribute(key: key, value: .string(value))
    }
  }

  public static func setViewAttributes(_ attrs: [String: String]) {
    if let span = OpenTelemetry.instance.contextProvider.activeSpan {
      for (k, v) in attrs { span.setAttribute(key: k, value: .string(v)) }
    }
  }

  public static func addViewEvent(name: String, attributes: [String: Any]) {
    if let span = OpenTelemetry.instance.contextProvider.activeSpan {
      var attrs: [String: AttributeValue] = [:]
      attributes.forEach { key, value in
        switch value {
        case let v as String: attrs[key] = .string(v)
        case let v as Bool: attrs[key] = .bool(v)
        case let v as Double: attrs[key] = .double(v)
        case let v as Int: attrs[key] = .int(v)
        default: break
        }
      }
      span.addEvent(name: name, attributes: attrs)
    }
  }
}
