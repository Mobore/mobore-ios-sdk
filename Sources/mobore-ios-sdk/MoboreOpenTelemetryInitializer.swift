import Foundation
import OpenTelemetryApi
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk
import PersistenceExporter
import os


class MoboreOpenTelemetryInitializer {
  static let logLabel = "Mobore-OTLP-Exporter"

  let sessionSampler: MoboreSessionSampler

  static func createPersistenceFolder() -> URL? {
    do {
      let cachesDir = try FileManager.default.url(
        for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      let persistentDir = cachesDir.appendingPathComponent("mobore")
      try FileManager.default.createDirectory(at: persistentDir, withIntermediateDirectories: true)
      return persistentDir
    } catch {
      return nil
    }
  }



  init(sessionSampler: MoboreSessionSampler) {
    self.sessionSampler = sessionSampler
  }




  func initializeWithHttp(_ configuration: MoboreAgentConfigManager) -> LogRecordExporter {
    guard let endpoint =  MoboreOpenTelemetryHelper.getURL(with: configuration.agent) else {
      os_log("Failed to start Mobore agent: invalid collector url.")
      return NoopLogRecordExporter.instance
    }

    var traceSampleFilter: [SignalFilter<any ReadableSpan>] = [
      SignalFilter<any ReadableSpan>({ [self] _ in
        self.sessionSampler.shouldSample
      })
    ]

    var logSampleFliter: [SignalFilter<ReadableLogRecord>] = [
      SignalFilter<ReadableLogRecord>({ [self] _ in
        self.sessionSampler.shouldSample
      })
    ]

    traceSampleFilter.append(contentsOf: configuration.agent.spanFilters)
    logSampleFliter.append(contentsOf: configuration.agent.logFilters)

    let headers = MoboreOpenTelemetryHelper.generateExporterHeaders(configuration.agent.auth)
    let otlpConfiguration = OtlpConfiguration(
      timeout: OtlpConfiguration.DefaultTimeoutInterval,
      headers: headers)

    let resources = MoboreAgentResource.get(environment: configuration.agent.environment).merging(other: MoboreAgentEnvResource.get())
    let metricExporter = {
      let metricEndpoint = URL(string: endpoint.absoluteString + "/v1/metrics")
      let defaultExporter = OtlpHttpMetricExporter(endpoint: metricEndpoint ?? endpoint, config: otlpConfiguration)
      do {
        if let path = Self.createPersistenceFolder() {
          return try PersistenceMetricExporterDecorator(
            metricExporter: defaultExporter, storageURL: path, exportCondition: { true },
            performancePreset: PersistencePerformancePreset.balanced) as MetricExporter
        }
      } catch {}
      return defaultExporter as MetricExporter
    }()

    let traceExporter = {
      let traceEndpoint = URL(string: endpoint.absoluteString + "/v1/traces")
      let defaultExporter = OtlpHttpTraceExporter(endpoint: traceEndpoint ?? endpoint, config:otlpConfiguration)
      do {
        if let path = Self.createPersistenceFolder() {
          return try PersistenceSpanExporterDecorator(
            spanExporter: defaultExporter,
            storageURL: path, exportCondition: { true },
            performancePreset: PersistencePerformancePreset.balanced) as SpanExporter
        }
      } catch {}
      return defaultExporter as SpanExporter
    }()

    let logExporter = {
      let logsEndpoint = URL(string: endpoint.absoluteString + "/v1/logs")
      let defaultExporter = OtlpHttpLogExporter(endpoint: logsEndpoint ?? endpoint, config: otlpConfiguration)
        do {
          if let path = Self.createPersistenceFolder() {
            return try PersistenceLogExporterDecorator(
                logRecordExporter: defaultExporter,
              storageURL: path, exportCondition: { true },
              performancePreset: PersistencePerformancePreset.balanced) as LogRecordExporter
          }
        } catch {}
      return defaultExporter as LogRecordExporter
    }()

    let meterProviderBuilder = MeterProviderSdk.builder()
      .registerView(
        selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
        view: View.builder().build()
      )
      .setResource(resource: resources)
      .setClock(clock: MoboreNTPClock())
      .registerMetricReader(
        reader: PeriodicMetricReaderBuilder(
          exporter: metricExporter
        )
        .build()
      )
    OpenTelemetry.registerMeterProvider(
      meterProvider: meterProviderBuilder.build()
    )

    // initialize trace provider
    OpenTelemetry.registerTracerProvider(
      tracerProvider: TracerProviderBuilder()
        .add(
          spanProcessor: MoboreSpanProcessor(
            spanExporter: traceExporter, agentConfiguration: configuration.agent)
        )
        .with(sampler: sessionSampler as Sampler)
        .with(resource: resources)
        .with(clock: MoboreNTPClock())
        .build())

    OpenTelemetry.registerLoggerProvider(
      loggerProvider: LoggerProviderBuilder()
        .with(clock: MoboreNTPClock())
        .with(resource: resources)
        .with(processors: [
          MoboreLogRecordProcessor(
            logRecordExporter: logExporter,
            configuration: configuration.agent)
        ])
        .build())
    return logExporter
  }
}

extension PersistencePerformancePreset {
   /// A custom preset offering a balance between performance and timely data delivery.
   static let balanced = PersistencePerformancePreset(
       // Storage settings
       maxFileSize: 10 * 1_024 * 1_024, 
       maxDirectorySize: 256 * 1_024 * 1_024, 
       maxFileAgeForWrite: 4.75,
       minFileAgeForRead: 4.75 + 0.5,
       maxFileAgeForRead: 24 * 60 * 60, // 24h
       maxObjectsInFile: 500,
       maxObjectSize: 5 * 1_024 * 1_024, 
       synchronousWrite: false,

       // Export settings
       initialExportDelay: 5, // postpone to not impact app launch time
       defaultExportDelay: 5,
       minExportDelay: 1,
       maxExportDelay: 20,
       exportDelayChangeRate: 0.1
   )
}
