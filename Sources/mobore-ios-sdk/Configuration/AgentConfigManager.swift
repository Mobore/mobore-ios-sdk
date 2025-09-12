import Foundation
import OpenTelemetrySdk

class AgentConfigManager {
    public let agent: AgentConfiguration
    public let instrumentation: InstrumentationConfiguration

    let serviceEnvironment: String?
    let serviceName: String?
    let resource: Resource

    

    init(resource: Resource,
         config: AgentConfiguration,
         instrumentationConfig: InstrumentationConfiguration) {
        self.resource = resource
        self.agent = config
        self.instrumentation = instrumentationConfig
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
