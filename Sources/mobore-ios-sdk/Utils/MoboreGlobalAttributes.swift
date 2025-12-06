import Foundation
import OpenTelemetryApi

public class MoboreGlobalAttributesStore {
  public static let shared = MoboreGlobalAttributesStore()
  private let lock = NSLock()
  private var attributes: [String: AttributeValue] = [:]

  private init() {}

  public func set(key: String, value: AttributeValue) {
    lock.lock(); defer { lock.unlock() }
    attributes[key] = value
  }

  public func setMany(_ newAttrs: [String: AttributeValue]) {
    lock.lock(); defer { lock.unlock() }
    for (k, v) in newAttrs { attributes[k] = v }
  }

  public func remove(key: String) {
    lock.lock(); defer { lock.unlock() }
    attributes.removeValue(forKey: key)
  }

  public func getAll() -> [String: AttributeValue] {
    lock.lock(); defer { lock.unlock() }
    return attributes
  }
}


