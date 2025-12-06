import Foundation
import OpenTelemetrySdk

class MoboreAgentConfigManager {
    public let agent: MoboreAgentConfiguration
    public let instrumentation: MoboreInstrumentationConfiguration

    let serviceEnvironment: String?
    let serviceName: String?
    let resource: Resource

    

    init(resource: Resource,
         config: MoboreAgentConfiguration,
         instrumentationConfig: MoboreInstrumentationConfiguration) {
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
