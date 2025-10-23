import Foundation
#if os(watchOS)
import WatchKit
#elseif os(macOS)
import AppKit
#else
import UIKit
#endif
import ResourceExtension
import OpenTelemetryApi
import OpenTelemetrySdk

public class AgentResource {
  public static func get(environment: String? = nil) -> Resource {
    let defaultResource = DefaultResources().get()
    var overridingAttributes = [
      ResourceAttributes.telemetrySdkName.rawValue: AttributeValue.string("ios")
    ]

    let osDataSource = OperatingSystemDataSource()
    overridingAttributes[ResourceAttributes.telemetrySdkVersion.rawValue] =
      AttributeValue.string("semver:\(MoboreIosSdkAgent.moboreSwiftAgentVersion)")
    overridingAttributes[ResourceAttributes.processRuntimeName.rawValue] = AttributeValue.string(osDataSource.name)
    overridingAttributes[ResourceAttributes.processRuntimeVersion.rawValue] =
      AttributeValue.string(osDataSource.version)
    if let deviceId = defaultResource.attributes[ResourceAttributes.deviceId.rawValue] {
      overridingAttributes[MoboreAttributes.deviceIdentifier.rawValue] = deviceId
    }
    // Attach current session id as a resource attribute
    overridingAttributes[MoboreAttributes.sessionId.rawValue] = AttributeValue.string(
      SessionManager.instance.session(false)
    )
    let appDataSource = ApplicationDataSource()

    if let build = appDataSource.build {
      if let version = appDataSource.version {
        overridingAttributes[ResourceAttributes.serviceVersion.rawValue] = AttributeValue.string(version)
        overridingAttributes[MoboreAttributes.serviceBuild.rawValue] = AttributeValue.string(build)
      } else {
        overridingAttributes[ResourceAttributes.serviceVersion.rawValue] = AttributeValue.string(build)
      }
    } else if let version = appDataSource.version {
      overridingAttributes[ResourceAttributes.serviceVersion.rawValue] = AttributeValue.string(version)

    }

    let envName = environment ?? nil
    // preserve deployment env key; use provided environment if available, else default
    overridingAttributes["environment"] = AttributeValue.string(envName ?? "default")

    // Additional attributes migrated from old SDK
    let countryCode: String = {
      if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
        return Locale.current.region?.identifier ?? "unknown"
      } else {
        return Locale.current.regionCode ?? "unknown"
      }
    }()
    overridingAttributes["country.code"] = AttributeValue.string(countryCode)
#if os(iOS) || os(tvOS)
#if targetEnvironment(simulator)
    overridingAttributes["device.is.emulator"] = AttributeValue.bool(true)
#else
    overridingAttributes["device.is.emulator"] = AttributeValue.bool(false)
#endif
#else
    overridingAttributes["device.is.emulator"] = AttributeValue.bool(false)
#endif

    // app.* convenience attributes
    overridingAttributes["app.version"] = AttributeValue.string(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")
    overridingAttributes["app.version.readable"] = AttributeValue.string(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
    overridingAttributes["app.bundle.id"] = AttributeValue.string(Bundle.main.bundleIdentifier ?? "unknown")
    overridingAttributes["app.name"] = AttributeValue.string(Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "unknown")

    // device.* attributes
#if os(iOS) || os(tvOS) || os(watchOS)
    overridingAttributes["device.model.name"] = AttributeValue.string(UIDevice.current.name)
#else
    overridingAttributes["device.model.name"] = AttributeValue.string("unknown")
#endif

    // network.* attributes - get current network connection type
#if os(iOS) && !targetEnvironment(macCatalyst)
    let networkStatus = (try? NetworkStatus())?.status().0 ?? "unavailable"
    overridingAttributes["network.connection.type"] = AttributeValue.string(networkStatus)
#else
    overridingAttributes["network.connection.type"] = AttributeValue.string("unknown")
#endif

    return defaultResource.merging(other: Resource.init(attributes: overridingAttributes))
  }

}
