import Foundation
import URLSession
import NetworkStatus
import OpenTelemetryApi

class InstrumentationWrapper {

    var appMetrics: Any?
    var hangInstrumentation: HangInstrumentation?
    var lowPowerModeInstrumentation: LowPowerModeInstrumentation?
    var tapInstrumentation: TapInstrumentation?
    var exitInstrumentation: ExitInstrumentation?
    #if canImport(UserNotifications) && !os(watchOS)
    var pushNotificationInstrumentation: PushNotificationInstrumentation?
    #endif
    #if canImport(WebKit) && !os(watchOS)
    var webViewInstrumentation: WebViewInstrumentation?
    #endif

    #if os(iOS)
      var vcInstrumentation: ViewControllerInstrumentation?
      var applicationLifecycleInstrumentation: ApplicationLifecycleInstrumentation?
      var sessionUsageInstrumentation: SessionUsageInstrumentation?
    #endif
    #if os(iOS) && !targetEnvironment(macCatalyst)
      var netstatInjector: NetworkStatusInjector?
    #endif
  
    var urlSessionInstrumentation: URLSessionInstrumentation?
    let config: AgentConfigManager

    init(config: AgentConfigManager) {
        self.config = config

#if os(iOS)
        if config.instrumentation.enableLifecycleEvents {
            applicationLifecycleInstrumentation = ApplicationLifecycleInstrumentation()
        }
        do {
            if self.config.instrumentation.enableViewControllerInstrumentation {
                vcInstrumentation = try ViewControllerInstrumentation()
            }
        } catch {
            print("failed to initalize view controller instrumentation: \(error)")
        }
#endif // os(iOS)
    }

    @MainActor func initalize() {
      #if os(iOS)
        if #available(iOS 13.0, *) {
            if config.instrumentation.enableSystemMetrics {
                _ = MemorySampler()
                _ = CPUSampler()
            }
            if config.instrumentation.enableAppMetricInstrumentation {
                appMetrics = AppMetrics()
                if let metrics = appMetrics as? AppMetrics {
                    metrics.receiveReports()
                }
            }
        }
      #endif
      if config.instrumentation.enableURLSessionInstrumentation {
          initializeNetworkInstrumentation()
      }
      if config.instrumentation.enableHangInstrumentation {
          hangInstrumentation = HangInstrumentation()
          hangInstrumentation?.start()
      }
      if config.instrumentation.enableLowPowerModeInstrumentation {
          lowPowerModeInstrumentation = LowPowerModeInstrumentation()
          lowPowerModeInstrumentation?.start()
      }
      if config.instrumentation.enableTapInstrumentation {
          tapInstrumentation = TapInstrumentation()
          tapInstrumentation?.start()
      }
      if config.instrumentation.enableExitInstrumentation {
          exitInstrumentation = ExitInstrumentation()
          exitInstrumentation?.start()
      }
      #if canImport(UserNotifications) && !os(watchOS)
      if config.instrumentation.enablePushNotificationInstrumentation {
          pushNotificationInstrumentation = PushNotificationInstrumentation()
          pushNotificationInstrumentation?.start()
      }
      #endif
      #if canImport(WebKit) && !os(watchOS)
      if config.instrumentation.enableWebViewInstrumentation {
          webViewInstrumentation = WebViewInstrumentation()
          webViewInstrumentation?.start()
      }
      #endif
      #if os(iOS)
        if config.instrumentation.enableSessionUsageInstrumentation {
            let threshold = max(0.0, config.instrumentation.sessionInactivityThresholdSeconds)
            sessionUsageInstrumentation = SessionUsageInstrumentation(inactivityThreshold: threshold)
            sessionUsageInstrumentation?.start()
        }
        vcInstrumentation?.swizzle()
      #endif // os(iOS)
    }

    private func initializeNetworkInstrumentation() {
      #if os(iOS) && !targetEnvironment(macCatalyst)
        do {
            let netstats =  try NetworkStatus()
            netstatInjector = NetworkStatusInjector(netstat: netstats)
        } catch {
            print("failed to initialize network connection status \(error)")
        }
      #endif

      // Build ignore list (prefix and regex) and default-exporter exclusions
      let instrConfig = self.config.instrumentation
      let exporterBase = OpenTelemetryHelper.getURL(with: self.config.agent)?.absoluteString
      var exporterIgnorePrefixes: [String] = []
      if instrConfig.ignoreExporterURLsByDefault, let base = exporterBase {
        exporterIgnorePrefixes.append(contentsOf: ["/v1/traces", "/v1/metrics", "/v1/logs"].map { base + $0 })
      }
      let configuredIgnorePrefixes = instrConfig.urlSessionIgnoreSubstrings
      let compiledIgnoreRegexes: [NSRegularExpression] = instrConfig.urlSessionIgnoreRegexes.compactMap { pattern in
        try? NSRegularExpression(pattern: pattern)
      }

      var config = URLSessionInstrumentationConfiguration(shouldRecordPayload: nil,
                                                          shouldInstrument:  { [weak self] request in
          guard let self else { return true }
          let urlString = request.url?.absoluteString ?? ""

          // Default exporter URL ignores
          if exporterIgnorePrefixes.contains(where: { urlString.hasPrefix($0) }) {
            return false
          }
          // Configured prefix ignores
          if configuredIgnorePrefixes.contains(where: { urlString.hasPrefix($0) }) {
            return false
          }
          // Configured regex ignores
          for regex in compiledIgnoreRegexes {
            let range = NSRange(location: 0, length: (urlString as NSString).length)
            if regex.firstMatch(in: urlString, options: [], range: range) != nil {
              return false
            }
          }

          // Fallback/custom logic
          if let shouldInstrument = self.config.instrumentation.urlSessionShouldInstrument {
            return shouldInstrument(request)
          }
          return true
      },
                                                          nameSpan: { request in
          if let host = request.url?.host, let method = request.httpMethod {
            return "\(method) \(host)"
          }
          return nil
      },
                                                          shouldInjectTracingHeaders: nil,
                                                          createdRequest: { _, span in
      #if os(iOS) && !targetEnvironment(macCatalyst)
        if let injector = self.netstatInjector {
          injector.inject(span: span)
        }
      #endif
        },
                                                            receivedResponse: { response, _, span in
            if let httpResponse = response as? HTTPURLResponse {

                if httpResponse.statusCode >= 400 && httpResponse.statusCode <= 599 {
                  // swiftlint:disable line_length

                    span.addEvent(name: SemanticAttributes.exception.rawValue,
                                  attributes: [SemanticAttributes.exceptionType.rawValue: AttributeValue.string("\(httpResponse.statusCode)"),
                                               SemanticAttributes.exceptionEscaped.rawValue: AttributeValue.bool(false),
                                               SemanticAttributes.exceptionMessage.rawValue: AttributeValue.string(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
                                              ])
                  // swiftlint:enable line_length

                }
            }

        },
                                                            receivedError: { error, _, _, span in
          // swiftlint:disable line_length
            span.addEvent(name: SemanticAttributes.exception.rawValue,
                          attributes: [SemanticAttributes.exceptionType.rawValue: AttributeValue.string(String(describing: type(of: error))),
                                       SemanticAttributes.exceptionEscaped.rawValue: AttributeValue.bool(false),
                                       SemanticAttributes.exceptionMessage.rawValue: AttributeValue.string(error.localizedDescription)])
          // swiftlint:enable line_length
        })

        urlSessionInstrumentation = URLSessionInstrumentation(configuration: config)
    }
}
