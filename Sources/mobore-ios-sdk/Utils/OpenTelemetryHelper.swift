import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import ResourceExtension
 

public class OpenTelemetryHelper {
    struct Headers {
        static let userAgent = "User-Agent"
        static let authorization = "Authorization"
    }

    public static func generateExporterHeaders(_ auth: String?) -> [(String, String)]? {
        var headers = [(String, String)]()
        if let auth = auth {
            headers.append((Headers.authorization, "\(auth)"))
        }
        headers.append((Headers.userAgent, generateExporterUserAgent()))

        return headers
    }

    public static func generateExporterUserAgent() -> String {
        var userAgent: String = "\(MoboreIosSdkAgent.name)/\(MoboreIosSdkAgent.moboreSwiftAgentVersion)"
        let appInfo = ApplicationDataSource()
        if let appName = appInfo.name {
            var appIdent = appName
            if let appVersion = appInfo.version {
                appIdent += " \(appVersion)"
            }
            userAgent += " (\(appIdent))"
        }
        return userAgent
    }

  public static func getURL(with config: AgentConfiguration) -> URL? {

    var port = "\(config.collectorPort)"
    if config.collectorPort == 80 || config.collectorPort == 443 {
      port = ""
    }

    return URL(string: "\(config.collectorTLS ? "https://" : "http://")\(config.collectorHost)\( port.isEmpty ? "" : ":\(port)")")

  }

}
