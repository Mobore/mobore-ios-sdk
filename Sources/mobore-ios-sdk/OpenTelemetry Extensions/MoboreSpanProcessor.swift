import Foundation
import NetworkStatus
import OpenTelemetryApi
import OpenTelemetrySdk
import os.log

public struct MoboreSpanProcessor: SpanProcessor {
  var processor: SpanProcessor
  var exporter: SpanExporter
  var filters = [SignalFilter<any ReadableSpan>]()
  var attributeInterceptor: any Interceptor<[String: AttributeValue]>
  public let isStartRequired: Bool
  public let isEndRequired: Bool

  // MARK: - Global Active Span Tracking / Flushing
  // Tracks currently active spans so we can end them on app exit.
  private static var activeSpansLock = NSLock()
  private static var activeSpans: [ObjectIdentifier: OpenTelemetrySdk.ReadableSpan] = [:]
  private static var globalSpanProcessor: SpanProcessor?
  private static var globalSpanExporter: SpanExporter?

#if os(iOS) && !targetEnvironment(macCatalyst)

  static var netstatInjector: NetworkStatusInjector? = { () -> NetworkStatusInjector? in
    do {
      let netstats = try NetworkStatus()
      return NetworkStatusInjector(netstat: netstats)
    } catch {
      if #available(iOS 14, macOS 11, tvOS 14, *) {
        os_log(
          .error, "failed to initialize network connection status: %@", error.localizedDescription)
      } else {
        NSLog("failed to initialize network connection status: %@", error.localizedDescription)
      }
      return nil
    }
  }()

#endif // os(iOS) && !targetEnvironment(macCatalyst)

  public init(
    spanExporter: SpanExporter,
    agentConfiguration: MoboreAgentConfiguration,
    scheduleDelay: TimeInterval = 5, exportTimeout: TimeInterval = 30,
    maxQueueSize: Int = 2048, maxExportBatchSize: Int = 512,
    willExportCallback: ((inout [SpanData]) -> Void)? = nil
  ) {
    processor = BatchSpanProcessor(
      spanExporter: spanExporter, scheduleDelay: scheduleDelay, exportTimeout: exportTimeout,
      maxQueueSize: maxQueueSize, maxExportBatchSize: maxExportBatchSize,
      willExportCallback: willExportCallback)
    isStartRequired = processor.isStartRequired
    isEndRequired = processor.isEndRequired
    exporter = spanExporter
    self.filters = agentConfiguration.spanFilters
    self.attributeInterceptor = agentConfiguration.spanAttributeInterceptor
      .join { attributes in
        var newAttributes = attributes
        newAttributes["type"] =  .string("mobile")
        return newAttributes
      }

    // Expose globally for forced flushing on exit
    Self.globalSpanProcessor = processor
    Self.globalSpanExporter = spanExporter
  }

  public func onStart(
    parentContext: OpenTelemetryApi.SpanContext?, span: OpenTelemetrySdk.ReadableSpan
  ) {

    var attrs = attributeInterceptor.intercept(span.getAttributes())
    // Merge global attributes
    let globals = MoboreGlobalAttributesStore.shared.getAll()
    for (k, v) in globals { attrs[k] = v }
    span.setAttributes(attrs)

    // Track active span
    Self.activeSpansLock.lock()
    Self.activeSpans[ObjectIdentifier(span)] = span
    Self.activeSpansLock.unlock()

    #if os(iOS) && !targetEnvironment(macCatalyst)
    if span.isHttpSpan(), let networkStatusInjector = Self.netstatInjector {
      networkStatusInjector.inject(span: span)
    } else {
      let status = (try? NetworkStatus())?.status().0 ?? "unavailable"
      span.setAttribute(key: SemanticAttributes.networkConnectionType.rawValue,
                        value: .string(status))
    }
    #endif
    processor.onStart(parentContext: parentContext, span: span)
  }

  public func onEnd(span: OpenTelemetrySdk.ReadableSpan) {

    // Remove from active spans immediately to avoid double-ending
    Self.activeSpansLock.lock()
    _ = Self.activeSpans.removeValue(forKey: ObjectIdentifier(span))
    Self.activeSpansLock.unlock()

    for filter in filters where !filter.shouldInclude(span) {
      return
    }

    processor.onEnd(span: span)
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {
    processor.shutdown(explicitTimeout: explicitTimeout)
  }

  public func forceFlush(timeout: TimeInterval?) {
    processor.forceFlush(timeout: timeout)
  }

  // MARK: - Exit helpers
  public static func endAllActiveSpans() {
    Self.activeSpansLock.lock()
    let spansToEnd = Array(Self.activeSpans.values)
    Self.activeSpans.removeAll()
    Self.activeSpansLock.unlock()

    for span in spansToEnd {
      span.end()
    }
  }

  public static func forceFlushAll(timeout: TimeInterval? = 1.0) {
    Self.globalSpanProcessor?.forceFlush(timeout: timeout)
    _ = Self.globalSpanExporter?.flush(explicitTimeout: timeout)
  }
}

internal struct NoopSpanProcessor: SpanProcessor {
  init() {}

  let isStartRequired = false
  let isEndRequired = false

  func onStart(parentContext: SpanContext?, span: ReadableSpan) {}

  func onEnd(span: ReadableSpan) {}

  func shutdown(explicitTimeout: TimeInterval? = nil) {}

  func forceFlush(timeout: TimeInterval? = nil) {}
}
