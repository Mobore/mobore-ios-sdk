#if !os(watchOS)
import CrashReporter
import Kronos
#endif
import Foundation
 
import OpenTelemetryApi
import OpenTelemetrySdk
import os.log
#if os(iOS)
import UIKit
#endif

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

  // Root session span to act as the parent for all app spans
  private var rootSessionSpan: Span?
  private var sessionObserver: NSObjectProtocol?

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

    // Start a root session span to parent all subsequent spans
    startRootSessionIfNeeded()
    // Observe session refresh to rotate the root session span
    // Deliver synchronously on the posting thread to avoid races during exit flush
    sessionObserver = NotificationCenter.default.addObserver(forName: .moboreSessionManagerDidRefreshSession, object: nil, queue: nil) { [weak self] _ in
      self?.rotateRootSession()
    }

    Task { @MainActor in
      instrumentation.initalize()
    }

    #if !os(watchOS)
    if agentConfigManager.instrumentation.enableCrashReporting {
      crashManager?.initializeCrashReporter(configuration: crashConfig)
    }
    #endif
  }

  public static func endRootSessionNow() {
    if let previous = rootSessionSpan {
      previous.end()
      if let active = OpenTelemetry.instance.contextProvider.activeSpan, (active as AnyObject) === (previous as AnyObject) {
        OpenTelemetry.instance.contextProvider.removeContextForSpan(previous)
      }
      rootSessionSpan = nil
    }
  }

  private static func startRootSessionIfNeeded() {
    guard rootSessionSpan == nil else { return }
    let tracer = OpenTelemetry.instance.tracerProvider
      .get(instrumentationName: "RUM", instrumentationVersion: MoboreIosSdkAgent.moboreSwiftAgentVersion)
    let span = tracer
      .spanBuilder(spanName: "mobile-session")
      .startSpan()
    OpenTelemetry.instance.contextProvider.setActiveSpan(span)
    rootSessionSpan = span
    os_log("Starting root session span: %@", span.spanContext.spanId.hexString)
  }

  private static func rotateRootSession() {
    // End previous root span
    if let previous = rootSessionSpan {
      previous.end()
      if let active = OpenTelemetry.instance.contextProvider.activeSpan, (active as AnyObject) === (previous as AnyObject) {
        OpenTelemetry.instance.contextProvider.removeContextForSpan(previous)
      }
    }
    rootSessionSpan = nil
    startRootSessionIfNeeded()
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
      // Do not accidentally end the root session span
      if let root = MoboreIosSdkAgent.shared()?.rootSessionSpan, (active as AnyObject) === (root as AnyObject) {
        return
      }
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

  /// Generic logging API backed by OpenTelemetry LoggerProvider
  /// - Parameters:
  ///   - message: Log message
  ///   - level: one of trace, debug, info, warn, error, fatal (case-insensitive). Defaults to info
  ///   - attributes: Additional structured attributes (String, Bool, Double, Int supported)
  public static func addLog(message: String, level: String = "info", attributes: [String: Any] = [:]) {
    let logger = OpenTelemetry.instance.loggerProvider
      .loggerBuilder(instrumentationScopeName: "RUM")
      .setEventDomain("app")
      .build()

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

    logger
      .eventBuilder(name: "log")
      .setBody(AttributeValue.string(message))
      .setSeverity(severity(from: level))
      .setAttributes(attrs)
      .emit()
  }

  private static func severity(from level: String) -> Severity {
    switch level.lowercased() {
    case "trace": return .trace
    case "debug": return .debug
    case "info": return .info
    case "warn", "warning": return .warn
    case "error": return .error
    case "fatal", "critical": return .fatal
    default: return .info
    }
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

  // MARK: - UIViewController-based view control (for React Native)
  #if os(iOS)
  @MainActor private static func findTopViewController() -> UIViewController? {
    let keyWindow = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    guard let root = keyWindow?.rootViewController else { return nil }
    return topViewController(from: root)
  }

  @MainActor private static func topViewController(from root: UIViewController) -> UIViewController {
    if let nav = root as? UINavigationController {
      if let visible = nav.visibleViewController { return topViewController(from: visible) }
      if let top = nav.topViewController { return topViewController(from: top) }
    }
    if let tab = root as? UITabBarController {
      if let selected = tab.selectedViewController { return topViewController(from: selected) }
    }
    if let presented = root.presentedViewController {
      return topViewController(from: presented)
    }
    if let lastChild = root.children.last {
      return topViewController(from: lastChild)
    }
    return root
  }

  /// Starts a view trace tied to the current top UIViewController using the same machinery as ViewControllerInstrumentation.
  /// If no UIViewController can be found, falls back to startView(name:url:).
  public static func startUIViewControllerView(name: String? = nil, url: String? = nil) {
    Task { @MainActor in
      guard let vc = findTopViewController() else {
        startView(name: name ?? "unknown", url: url)
        return
      }
      let tracer = ViewControllerInstrumentation.getTracer()
      let defaultName = "\(type(of: vc))"
      let preferred = name ?? ViewControllerInstrumentation.getViewControllerName(vc)
      _ = ViewControllerInstrumentation
        .traceLogger
        .startTrace(tracer: tracer,
                    associatedObject: vc,
                    name: defaultName,
                    preferredName: preferred)
    }
  }

  /// Ends the current UIViewController-tied view trace.
  public static func endUIViewControllerView() {
    Task { @MainActor in
      let vc = findTopViewController()
      ViewControllerInstrumentation
        .traceLogger
        .stopTrace(associatedObject: vc ?? NSObject(),
                   preferredName: nil)
    }
  }
  #endif
}
