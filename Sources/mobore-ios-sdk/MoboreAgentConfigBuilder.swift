import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public class MoboreAgentConfigBuilder {
  private var enableAgent: Bool?
  private var exportUrl: URL?
  private var environment: String?
  
  private var auth: String?
  private var sampleRate = 1.0

  private var spanFilters = [SignalFilter<ReadableSpan>]()
  private var logFilters = [SignalFilter<ReadableLogRecord>]()

  private var spanAttributeInterceptors: [any Interceptor<[String: AttributeValue]>] = []
  private var logRecordAttributeInterceptors: [any Interceptor<[String: AttributeValue]>] = []
  public init() {}

  public func disableAgent() -> Self {
    enableAgent = false
    return self
  }

  public func withExportUrl(_ url: URL) -> Self {
    self.exportUrl = url
    return self
  }

  public func withEnvironment(_ env: String) -> Self {
    self.environment = env
    return self
  }

  public func withClientToken(_ token: String) -> Self {
    self.auth = token
    return self
  }

  public func withSessionSampleRate(_ rate: Double) -> Self {
    sampleRate = min(max(rate, 0.0), 1.0)
    return self
  }

  

  public func addSpanFilter(_ shouldInclude: @escaping (any ReadableSpan) -> Bool) -> Self {
    spanFilters.append(SignalFilter<ReadableSpan>(shouldInclude))
    return self
  }

  public func addLogFilter(_ shouldInclude: @escaping (ReadableLogRecord) -> Bool) -> Self {
    logFilters.append(SignalFilter<ReadableLogRecord>(shouldInclude))
    return self
  }

  public func addSpanAttributeInterceptor(_ interceptor: any Interceptor<[String: AttributeValue]>) -> Self {
    self.spanAttributeInterceptors.append(interceptor)
    return self
  }

  public func addLogRecordAttributeInterceptor(_ interceptor: any Interceptor<[String: AttributeValue]>) -> Self {
    self.logRecordAttributeInterceptors.append(interceptor)
    return self
  }

  public func build() -> MoboreAgentConfiguration {

    var config = MoboreAgentConfiguration()
    config.sampleRate = sampleRate
    config.logFilters = logFilters
    config.spanFilters = spanFilters
    
    

    if !self.spanAttributeInterceptors.isEmpty {
      if self.spanAttributeInterceptors.count > 1 {
        config.spanAttributeInterceptor = MultiInterceptor(self.spanAttributeInterceptors)
      } else {
        config.spanAttributeInterceptor = self.spanAttributeInterceptors[0]
      }
    }

    if !self.logRecordAttributeInterceptors.isEmpty {
      if self.logRecordAttributeInterceptors.count > 1 {
        config.logRecordAttributeInterceptor = MultiInterceptor(self.logRecordAttributeInterceptors)
      } else {
        config.logRecordAttributeInterceptor = self.logRecordAttributeInterceptors[0]
      }
    }

    let url = self.exportUrl
    if let url {
      if let proto = url.scheme, proto == "https" {
        config.collectorTLS = true
      }
      if let host = url.host {
        config.collectorHost = host
      }
      if let port = url.port {
        config.collectorPort = port
      }
     
    }

    if let auth = self.auth {
      config.auth = auth
    }

    if let enableAgent = enableAgent {
      config.enableAgent = enableAgent
    }
    
    if let environment = environment {
      config.environment = environment
    }
    return config
  }
}
