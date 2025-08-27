import Foundation
import OpenTelemetryApi
#if canImport(UIKit)
import UIKit
import ObjectiveC
#endif

final class TapInstrumentation: NSObject {
    override init() { super.init() }
    @MainActor func start() {
        #if canImport(UIKit)
        Self.installTapHook()
        NotificationCenter.default.addObserver(self, selector: #selector(handleTap(_:)), name: .moboreTapAction, object: nil)
        #endif
    }

    func stop() {
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self, name: .moboreTapAction, object: nil)
        #endif
    }

    @objc private func handleTap(_ note: Notification) {
        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "TapInstrumentation", instrumentationVersion: "0.0.1")
        let userInfo = note.userInfo ?? [:]
        let targetName = userInfo["target"] as? String ?? "unknown"
        let actionName = userInfo["action"] as? String ?? "unknown"

        var attributes: [String: AttributeValue] = [
            "action.target": .string(targetName),
            "action.name": .string(actionName)
        ]

        if let elementType = userInfo["element.type"] as? String { attributes["resource.element.type"] = .string(elementType) }
        if let elementLabel = userInfo["element.label"] as? String { attributes["resource.element.label"] = .string(elementLabel) }
        if let elementId = userInfo["element.identifier"] as? String { attributes["resource.element.identifier"] = .string(elementId) }
        if let elementTitle = userInfo["element.title"] as? String { attributes["resource.element.title"] = .string(elementTitle) }
        if let x = userInfo["tap.x"] as? Double { attributes["resource.tap.x"] = .double(x) }
        if let y = userInfo["tap.y"] as? Double { attributes["resource.tap.y"] = .double(y) }

        let builder = tracer.spanBuilder(spanName: "tap.\(targetName).\(actionName)")
        attributes.forEach { builder.setAttribute(key: $0.key, value: $0.value) }
        let span = builder.startSpan()
        span.end()
    }

    #if canImport(UIKit)
    private static func installTapHook() {
        guard UIApplication.self == UIApplication.self else { return }
        let originalSelector = #selector(UIApplication.sendAction(_:to:from:for:))
        let swizzledSelector = #selector(UIApplication.mb_sendAction(_:to:from:for:))
        if let originalMethod = class_getInstanceMethod(UIApplication.self, originalSelector),
           let swizzledMethod = class_getInstanceMethod(UIApplication.self, swizzledSelector) {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    #endif
}

#if canImport(UIKit)
extension UIApplication {
    @objc func mb_sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        let targetName = String(describing: type(of: target as Any))
        let actionName = NSStringFromSelector(action)

        var userInfo: [String: Any] = [
            "target": targetName,
            "action": actionName
        ]

        if let view = sender as? UIView {
            userInfo["element.type"] = String(describing: type(of: view))
            if let label = view.accessibilityLabel { userInfo["element.label"] = label }
            if let identifier = view.accessibilityIdentifier { userInfo["element.identifier"] = identifier }
            if let button = view as? UIButton { userInfo["element.title"] = button.currentTitle ?? "" }

            if let window = view.window {
                let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
                let pointInWindow = view.convert(center, to: window)
                userInfo["tap.x"] = Double(pointInWindow.x)
                userInfo["tap.y"] = Double(pointInWindow.y)
            }
        }

        if let touch = event?.allTouches?.first, let window = touch.window {
            let location = touch.location(in: window)
            userInfo["tap.x"] = Double(location.x)
            userInfo["tap.y"] = Double(location.y)
        }

        NotificationCenter.default.post(name: .moboreTapAction, object: sender, userInfo: userInfo)
        return mb_sendAction(action, to: target, from: sender, for: event)
    }
}

extension Notification.Name {
    static let moboreTapAction = Notification.Name("mobore.tap.action")
}
#endif


