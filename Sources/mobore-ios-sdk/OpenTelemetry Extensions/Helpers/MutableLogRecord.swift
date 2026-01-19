import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public struct MutableLogRecord {
  private var logRecord: ReadableLogRecord
  public var attributes: [String: AttributeValue]

  public var resource: Resource {
    get {
      logRecord.resource
    }
  }

  public var instrumentationScopeInfo: InstrumentationScopeInfo {
    get {
      logRecord.instrumentationScopeInfo
    }
  }

  public var timestamp: Date {
    get {
      logRecord.timestamp
    }
  }

  public var observedTimestamp: Date? {
    get {
      logRecord.observedTimestamp
    }
  }

  public var spanContext: SpanContext? {
    get {
      logRecord.spanContext
    }
  }

  public var severity: Severity? {
    get {
      logRecord.severity
    }
  }

  public var body: AttributeValue? {
    get {
      logRecord.body
    }
  }

  public init(from logRecord: ReadableLogRecord) {
    self.logRecord = logRecord
    self.attributes = logRecord.attributes
  }


  public func finish() -> ReadableLogRecord {
    return ReadableLogRecord(resource: logRecord.resource,
                             instrumentationScopeInfo: logRecord.instrumentationScopeInfo,
                             timestamp: logRecord.timestamp,
                             observedTimestamp: logRecord.observedTimestamp,
                             spanContext: logRecord.spanContext,
                             severity: logRecord.severity,
                             body: logRecord.body,
                             attributes: attributes)
  }
}
