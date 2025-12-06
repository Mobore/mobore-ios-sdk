import Foundation

extension Notification.Name {
  public static let moboreSessionManagerDidRefreshSession = Notification.Name.init(
    "moboreSessionManagerDidRefreshSession")
}

public class MoboreSessionManager {

  static let sessionIdKey = "mobore.session.id"
  static let sessionTimerKey = "mobore.session.timer"
  static let sessionTimeout: TimeInterval = 30 * 60
  public static var instance = MoboreSessionManager()
  private var currentId: UUID {
    get {
      UUID(uuidString: UserDefaults.standard.object(forKey: Self.sessionIdKey) as? String ?? "")
        ?? UUID()
    }
    set(uuid) {
      UserDefaults.standard.setValue(uuid.uuidString, forKey: Self.sessionIdKey)
    }
  }

  private var lastUpdated: Date {
    get {
      Date(
        timeIntervalSince1970: UserDefaults.standard.object(forKey: Self.sessionTimerKey)
          as? TimeInterval ?? Date.distantPast.timeIntervalSince1970)
    }
    set(date) {
      UserDefaults.standard.setValue(date.timeIntervalSince1970, forKey: Self.sessionTimerKey)
    }
  }

  private init() {
    if !isValid() {
      refreshSession()
    }
  }

    public func session(_ update: Bool = true) -> String {
        if update {
            if isValid() {
                updateTimeout()
            } else {
                refreshSession()
            }
        }
        return currentId.uuidString
    }

  public func updateTimeout() {
    lastUpdated = Date()
  }

  func refreshSession() {
    currentId = UUID()
    lastUpdated = Date()
    NotificationCenter.default.post(
      name: .moboreSessionManagerDidRefreshSession, object: self,
      userInfo: ["id": currentId, "lastUpdated": lastUpdated])
  }

  func isValid() -> Bool {
    lastUpdated.timeIntervalSinceNow.magnitude < Self.sessionTimeout
  }

  public func endSession() {
    refreshSession()
  }
}
