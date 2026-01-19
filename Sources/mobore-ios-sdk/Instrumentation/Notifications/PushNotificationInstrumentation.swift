import Foundation
import OpenTelemetryApi
#if canImport(UserNotifications) && !os(watchOS)
@preconcurrency import UserNotifications
import ObjectiveC

final class PushNotificationInstrumentation: NSObject {
    private let tracer: Tracer

    override init() {
        tracer = OpenTelemetry.instance
            .tracerProvider
            .get(instrumentationName: "PushNotifications", instrumentationVersion: "0.0.1")
        super.init()
    }

    @MainActor func start() {
        UNUserNotificationCenter.mb_installPushDelegateHookIfNeeded()
        UNUserNotificationCenter.current().mb_wrapCurrentDelegate(with: self)
    }

    func stop() {
        // no-op for now; un-swizzling safely at runtime is not required
    }

    func recordPushReceived(notification: UNNotification) {
        let content = notification.request.content
        let attributes = Self.buildAttributes(from: content, trigger: notification.request.trigger)
        let span = tracer.spanBuilder(spanName: "push.received").startSpan()
        attributes.forEach { span.setAttribute(key: $0.key, value: $0.value) }
        span.end()
    }

    func recordPushTapped(response: UNNotificationResponse) {
        let content = response.notification.request.content
        var attributes = Self.buildAttributes(from: content, trigger: response.notification.request.trigger)
        let actionId = response.actionIdentifier
        if !actionId.isEmpty { attributes["push.actionIdentifier"] = .string(actionId) }
        let span = tracer.spanBuilder(spanName: "push.tapped").startSpan()
        attributes.forEach { span.setAttribute(key: $0.key, value: $0.value) }
        span.end()
    }

    private static func buildAttributes(from content: UNNotificationContent, trigger: UNNotificationTrigger?) -> [String: AttributeValue] {
        var attributes: [String: AttributeValue] = [:]
        if !content.title.isEmpty { attributes["push.title"] = .string(content.title) }
        if !content.subtitle.isEmpty { attributes["push.subtitle"] = .string(content.subtitle) }
        if !content.body.isEmpty { attributes["push.body"] = .string(content.body) }
        if !content.categoryIdentifier.isEmpty { attributes["push.category"] = .string(content.categoryIdentifier) }
        if !content.threadIdentifier.isEmpty { attributes["push.thread"] = .string(content.threadIdentifier) }
        #if os(iOS)
        if let badge = content.badge { attributes["push.badge"] = .string(badge.stringValue) }
        #endif
        if let userInfo = content.userInfo as? [String: Any], let aps = userInfo["aps"] as? [String: Any] {
            if let alert = aps["alert"] as? [String: Any] {
                if let body = alert["body"] as? String, !body.isEmpty { attributes["push.body"] = .string(body) }
                if let title = alert["title"] as? String, !title.isEmpty { attributes["push.title"] = .string(title) }
            }
            if let category = aps["category"] as? String, !category.isEmpty { attributes["push.category"] = .string(category) }
        }
        if let trigger = trigger {
            let source = (trigger is UNPushNotificationTrigger) ? "remote" : "local"
            attributes["push.source"] = .string(source)
        }
        return attributes
    }
}

// MARK: - Delegate proxy & swizzling

final class MoborePushDelegateProxy: NSObject, UNUserNotificationCenterDelegate {
    weak var externalDelegate: UNUserNotificationCenterDelegate?
    weak var instrumentation: PushNotificationInstrumentation?

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            instrumentation?.recordPushReceived(notification: notification)

            if let externalDelegate,
               externalDelegate.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
                externalDelegate.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
            } else {
                #if os(iOS)
                completionHandler([.banner, .sound, .badge])
                #else
                completionHandler([.alert, .sound, .badge])
                #endif
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            instrumentation?.recordPushTapped(response: response)

            if let externalDelegate,
               externalDelegate.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
                externalDelegate.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
            } else {
                completionHandler()
            }
        }
    }
}

@MainActor private var mbProxyKey: UInt8 = 0
@MainActor private var mbInstrumentationKey: UInt8 = 0
@MainActor private var mbHookInstalledKey: UInt8 = 0

@MainActor
extension UNUserNotificationCenter {
    private var mb_proxy: MoborePushDelegateProxy {
        if let proxy = objc_getAssociatedObject(self, &mbProxyKey) as? MoborePushDelegateProxy { return proxy }
        let proxy = MoborePushDelegateProxy()
        objc_setAssociatedObject(self, &mbProxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return proxy
    }

    private var mb_instrumentation: PushNotificationInstrumentation? {
        get { objc_getAssociatedObject(self, &mbInstrumentationKey) as? PushNotificationInstrumentation }
        set { objc_setAssociatedObject(self, &mbInstrumentationKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
    }

    private static var mb_hookInstalled: Bool {
        get { (objc_getAssociatedObject(self, &mbHookInstalledKey) as? NSNumber)?.boolValue ?? false }
        set { objc_setAssociatedObject(self, &mbHookInstalledKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    static func mb_installPushDelegateHookIfNeeded() {
        guard !mb_hookInstalled else { return }
        mb_hookInstalled = true

        let originalSelector = NSSelectorFromString("setDelegate:")
        let swizzledSelector = #selector(UNUserNotificationCenter.mb_setDelegate(_:))

        if let originalMethod = class_getInstanceMethod(UNUserNotificationCenter.self, originalSelector),
           let swizzledMethod = class_getInstanceMethod(UNUserNotificationCenter.self, swizzledSelector) {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }

    @objc func mb_setDelegate(_ delegate: UNUserNotificationCenterDelegate?) {
        let proxy = mb_proxy
        proxy.externalDelegate = delegate
        proxy.instrumentation = mb_instrumentation

        self.mb_setDelegate(proxy)
    }

    func mb_wrapCurrentDelegate(with instrumentation: PushNotificationInstrumentation) {
        self.mb_instrumentation = instrumentation
        self.delegate = self.delegate
    }
}

#endif


