import Foundation
import OpenTelemetrySdk
import Logging

class AgentConfigManager {
    public let agent: AgentConfiguration
    public let instrumentation: InstrumentationConfiguration

    let serviceEnvironment: String?
    let serviceName: String?
    let logger: Logger
    let resource: Resource

    

    init(resource: Resource,
         config: AgentConfiguration,
         instrumentationConfig: InstrumentationConfiguration,
         logger: Logging.Logger = Logging.Logger(label: "com.mobore.centralConfigFetcher") { _ in
        SwiftLogNoOpLogHandler()
    }) {
        self.resource = resource
        self.agent = config
        self.instrumentation = instrumentationConfig
        self.logger = logger
        switch resource.attributes["environment"] {
        case let .string(value):
            serviceEnvironment = value
        default:
            serviceEnvironment = nil
        }

        switch resource.attributes[ResourceAttributes.serviceName.rawValue] {
        case let .string(value):
            serviceName = value
        default:
            serviceName = nil
        }

        
    }
}
