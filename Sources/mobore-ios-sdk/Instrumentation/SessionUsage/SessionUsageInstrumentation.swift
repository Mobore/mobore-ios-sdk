import Foundation
import OpenTelemetryApi

#if canImport(UIKit)
import UIKit
import ObjectiveC

final class SessionUsageInstrumentation: NSObject {
  private var timer: Timer?
  private var isAppActive = false
  private var lastActivityAt: Date = Date()
  private var lastTickAt: Date = Date()
  private var totalActiveMs: Double = 0
  private let inactivityThreshold: TimeInterval

  private let meter: any Meter = OpenTelemetry.instance.meterProvider
    .meterBuilder(name: "SessionUsage")
    .build()
  private lazy var counter: any Counter = meter
    .counterBuilder(name: MoboreMetrics.sessionActiveUsageSeconds.rawValue)
    .build()

  init(inactivityThreshold: TimeInterval) {
    self.inactivityThreshold = inactivityThreshold
    super.init()
  }

  @MainActor func start() {
    UIApplication.mb_installSendEventHookIfNeeded()
    UIApplication.shared.mb_setSessionUsageInstrumentation(self)
    observeLifecycle()
    observeSessionRotation()
    startTimer()
  }

  @MainActor func stop() {
    removeObservers()
    timer?.invalidate()
    timer = nil
    UIApplication.shared.mb_setSessionUsageInstrumentation(nil)
  }

  fileprivate func onUserActivity() {
    lastActivityAt = Date()
  }

  private func startTimer() {
    lastTickAt = Date()
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      self?.tick()
    }
    RunLoop.main.add(timer!, forMode: .common)
  }

  private func tick() {
    let now = Date()
    defer { lastTickAt = now }

    guard isAppActive else { return }
    if now.timeIntervalSince(lastActivityAt) > inactivityThreshold { return }

    let deltaSec = now.timeIntervalSince(lastTickAt)
    if deltaSec <= 0 { return }
    accumulate(seconds: deltaSec)
  }

  private func accumulate(seconds: Double) {
    totalActiveMs += seconds * 1000.0
    let sessionId = SessionManager.instance.session(false)
    counter.add(value: seconds, attributes: [MoboreAttributes.sessionId.rawValue: .string(sessionId)])
    MoboreIosSdkAgent.setSessionAttribute(key: MoboreAttributes.sessionActiveDurationMs.rawValue, valueMs: totalActiveMs)
  }

  private func observeLifecycle() {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(didBecomeActive(_:)),
                                           name: UIApplication.didBecomeActiveNotification,
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(willResignActive(_:)),
                                           name: UIApplication.willResignActiveNotification,
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(didEnterBackground(_:)),
                                           name: UIApplication.didEnterBackgroundNotification,
                                           object: nil)
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(willTerminate(_:)),
                                           name: UIApplication.willTerminateNotification,
                                           object: nil)
  }

  private func observeSessionRotation() {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(sessionDidRotate(_:)),
                                           name: .moboreSessionManagerDidRefreshSession,
                                           object: nil)
  }

  private func removeObservers() {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func didBecomeActive(_ note: Notification) {
    isAppActive = true
    lastActivityAt = Date()
    lastTickAt = Date()
  }

  @objc private func willResignActive(_ note: Notification) {
    isAppActive = false
    // Ensure latest value is persisted on session span
    MoboreIosSdkAgent.setSessionAttribute(key: MoboreAttributes.sessionActiveDurationMs.rawValue, valueMs: totalActiveMs)
  }

  @objc private func didEnterBackground(_ note: Notification) {
    // Flush current value before background
    MoboreIosSdkAgent.setSessionAttribute(key: MoboreAttributes.sessionActiveDurationMs.rawValue, valueMs: totalActiveMs)
  }

  @objc private func willTerminate(_ note: Notification) {
    // Final flush on terminate
    MoboreIosSdkAgent.setSessionAttribute(key: MoboreAttributes.sessionActiveDurationMs.rawValue, valueMs: totalActiveMs)
  }

  @objc private func sessionDidRotate(_ note: Notification) {
    // Persist last value on the old session span, then reset for the new session
    MoboreIosSdkAgent.setSessionAttribute(key: MoboreAttributes.sessionActiveDurationMs.rawValue, valueMs: totalActiveMs)
    totalActiveMs = 0
    lastTickAt = Date()
    lastActivityAt = Date()
  }
}

// MARK: - UIApplication swizzling for user activity

@MainActor private var mbUsageHookInstalledKey: UInt8 = 0
@MainActor private var mbUsageInstrumentationKey: UInt8 = 0

@MainActor
extension UIApplication {
  private static var mb_usageHookInstalled: Bool {
    get { (objc_getAssociatedObject(self, &mbUsageHookInstalledKey) as? NSNumber)?.boolValue ?? false }
    set { objc_setAssociatedObject(self, &mbUsageHookInstalledKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
  }

  private var mb_sessionUsageInstrumentation: SessionUsageInstrumentation? {
    get { objc_getAssociatedObject(self, &mbUsageInstrumentationKey) as? SessionUsageInstrumentation }
    set { objc_setAssociatedObject(self, &mbUsageInstrumentationKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
  }

  static func mb_installSendEventHookIfNeeded() {
    guard !mb_usageHookInstalled else { return }
    mb_usageHookInstalled = true
    let originalSelector = #selector(UIApplication.sendEvent(_:))
    let swizzledSelector = #selector(UIApplication.mb_sendEvent(_:))
    if let originalMethod = class_getInstanceMethod(UIApplication.self, originalSelector),
       let swizzledMethod = class_getInstanceMethod(UIApplication.self, swizzledSelector) {
      method_exchangeImplementations(originalMethod, swizzledMethod)
    }
  }

  func mb_setSessionUsageInstrumentation(_ inst: SessionUsageInstrumentation?) {
    self.mb_sessionUsageInstrumentation = inst
  }

  @objc func mb_sendEvent(_ event: UIEvent) {
    if event.type == .touches, let touches = event.allTouches, !touches.isEmpty {
      self.mb_sessionUsageInstrumentation?.onUserActivity()
    }
    self.mb_sendEvent(event)
  }
}

#endif


