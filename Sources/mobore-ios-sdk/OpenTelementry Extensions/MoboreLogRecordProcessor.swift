import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public struct MoboreLogRecordProcessor: LogRecordProcessor {
  var processor: BatchLogRecordProcessor
  var filters = [SignalFilter<ReadableLogRecord>]()
  var attributeInterceptor: any Interceptor<[String: AttributeValue]>
  private static var globalLogProcessor: BatchLogRecordProcessor?
  internal init(
    logRecordExporter: LogRecordExporter,
    configuration: AgentConfiguration,
    scheduleDelay: TimeInterval = 5,
    exportTimeout: TimeInterval = 30,
    maxQueueSize: Int = 2048,
    maxExportBatchSize: Int = 512,
    willExportCallback: ((inout [ReadableLogRecord]) -> Void)? = nil
  ) {
    self.filters = configuration.logFilters
    self.attributeInterceptor = configuration.logRecordAttributeInterceptor
      .join { attributes in
          var newAttributes = attributes
          #if os(iOS) && !targetEnvironment(macCatalyst)
          newAttributes[SemanticAttributes.networkConnectionType.rawValue] = AttributeValue
            .string(NetworkStatusManager().status())
          #endif // os(iOS) && !targetEnvironment(macCatalyst)
          return newAttributes
        }

    processor = BatchLogRecordProcessor(
      logRecordExporter: logRecordExporter, scheduleDelay: scheduleDelay,
      exportTimeout: exportTimeout, maxQueueSize: maxQueueSize,
      maxExportBatchSize: maxExportBatchSize, willExportCallback: willExportCallback)

    Self.globalLogProcessor = processor
  }

  public func onEmit(logRecord: OpenTelemetrySdk.ReadableLogRecord) {
    // recording flag via central config removed
    var appendedLogRecord = MutableLogRecord(from: logRecord)
    appendedLogRecord.attributes = attributeInterceptor.intercept(appendedLogRecord.attributes)

    let finalLogRecord = appendedLogRecord.finish()

    for filter in filters where !filter.shouldInclude(finalLogRecord) {
        return
      }

    processor.onEmit(logRecord: finalLogRecord)

  }

  public func forceFlush(explicitTimeout: TimeInterval? = nil) -> OpenTelemetrySdk.ExportResult {
    processor.forceFlush(explicitTimeout: explicitTimeout)
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) -> OpenTelemetrySdk.ExportResult {
    processor.shutdown(explicitTimeout: explicitTimeout)
  }

  public static func forceFlushAll(explicitTimeout: TimeInterval? = 1.0) {
    _ = Self.globalLogProcessor?.forceFlush(explicitTimeout: explicitTimeout)
  }
}
