#if canImport(UIKit) && !os(watchOS)
import Foundation
import UIKit
import OpenTelemetryApi
public class ApplicationLifecycleInstrumentation: NSObject {
    private static let eventName: String = "lifecycle"
    private enum State: String {
        case active
        case inactive
        case background
        case foreground
        case terminate
}
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private static let logger: Logger = OpenTelemetry
        .instance
        .loggerProvider
        .loggerBuilder(instrumentationScopeName: "ApplicationLifecycle")
        .setEventDomain("device")
        .build()

    static func getLogger() -> Logger {
        logger
    }

    public override init() {
        super.init()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(active(_:)),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(inactive(_:)),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(background(_:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(foreground(_:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(terminate(_:)),
                                               name: UIApplication.willTerminateNotification,
                                               object: nil)
    }

    @objc func active(_ notification: Notification) {
        Self.getLogger().eventBuilder(name: Self.eventName)
            .setAttributes(["lifecycle.state": AttributeValue.string(State.active.rawValue)])
            .emit()
    }

    @objc func inactive(_ notification: Notification) {
        Self.getLogger().eventBuilder(name: Self.eventName)
            .setAttributes(["lifecycle.state": AttributeValue.string(State.inactive.rawValue)])
            .emit()
    }

    @objc func background(_ notification: Notification) {
        Self.getLogger().eventBuilder(name: Self.eventName)
            .setAttributes(["lifecycle.state": AttributeValue.string(State.background.rawValue)])
            .emit()
    }

    @objc func foreground(_ notification: Notification) {
        Self.getLogger().eventBuilder(name: Self.eventName)
            .setAttributes(["lifecycle.state": AttributeValue.string(State.foreground.rawValue)])
            .emit()
    }

    @objc func terminate(_ notification: Notification) {
        Self.getLogger().eventBuilder(name: Self.eventName)
            .setAttributes(["lifecycle.state": AttributeValue.string(State.terminate.rawValue)])
            .emit()}
}

#endif
