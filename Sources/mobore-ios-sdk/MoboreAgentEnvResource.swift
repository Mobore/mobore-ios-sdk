import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

public struct MoboreAgentEnvResource {
    public static let otelResourceAttributesEnv = "OTEL_RESOURCE_ATTRIBUTES"
    private static let labelListSplitter = Character(",")
    private static let labelKeyValueSplitter = Character("=")

    ///  This resource information is loaded from the OTEL_RESOURCE_ATTRIBUTES
    ///  environment variable.
    public static func get(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Resource {
        let envAttr = parseResourceAttributes(rawEnvAttributes: env[otelResourceAttributesEnv] ?? "")

        var bundleAttr = parseResourceAttributes(
            rawEnvAttributes: Bundle.main.infoDictionary?[otelResourceAttributesEnv] as? String ?? "")
        bundleAttr.merge(envAttr) { _, value in
            value
        }
        return Resource(attributes: bundleAttr)

    }

    private init() {}

    /// Creates a label map from the OTEL_RESOURCE_ATTRIBUTES environment variable.
    /// OTEL_RESOURCE_ATTRIBUTES: A comma-separated list of labels describing the source in more detail,
    /// e.g. “key1=val1,key2=val2”. Domain names and paths are accepted as label keys. Values may be
    /// quoted or unquoted in general. If a value contains whitespaces, =, or " characters, it must
    /// always be quoted.
    /// - Parameter rawEnvAttributes: the comma-separated list of labels
    private static func parseResourceAttributes(rawEnvAttributes: String?) -> [String: AttributeValue] {
        guard let raw = rawEnvAttributes, !raw.isEmpty else { return [:] }

        var labels = [String: AttributeValue]()

        for entry in raw.split(separator: labelListSplitter) {
            guard let eqIndex = entry.firstIndex(of: labelKeyValueSplitter) else { continue }
            let rawKey = entry[..<eqIndex].trimmingCharacters(in: .whitespaces)
            let rawValue = entry[entry.index(after: eqIndex)...].trimmingCharacters(in: .whitespaces)
            let unquotedValue = stripSurroundingQuotes(String(rawValue))
            labels[String(rawKey)] = .string(unquotedValue)
        }
        return labels
    }

    private static func stripSurroundingQuotes(_ value: String) -> String {
        guard value.count >= 2, value.first == "\"", value.last == "\"" else { return value }
        return String(value.dropFirst().dropLast())
    }
}
