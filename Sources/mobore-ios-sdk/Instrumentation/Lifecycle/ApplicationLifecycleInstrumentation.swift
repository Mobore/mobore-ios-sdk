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

    private static let tracer: Tracer = OpenTelemetry
        .instance
        .tracerProvider
        .get(instrumentationName: "ApplicationLifecycle", instrumentationVersion: "0.0.1")

    static func getTracer() -> Tracer {
        tracer
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
        let span = Self.getTracer()
            .spanBuilder(spanName: Self.eventName)
            .setAttribute(key: "lifecycle.state", value: .string(State.active.rawValue))
            .startSpan()
        span.end()
    }

    @objc func inactive(_ notification: Notification) {
        let span = Self.getTracer()
            .spanBuilder(spanName: Self.eventName)
            .setAttribute(key: "lifecycle.state", value: .string(State.inactive.rawValue))
            .startSpan()
        span.end()
    }

    @objc func background(_ notification: Notification) {
        let span = Self.getTracer()
            .spanBuilder(spanName: Self.eventName)
            .setAttribute(key: "lifecycle.state", value: .string(State.background.rawValue))
            .startSpan()
        span.end()
    }

    @objc func foreground(_ notification: Notification) {
        let span = Self.getTracer()
            .spanBuilder(spanName: Self.eventName)
            .setAttribute(key: "lifecycle.state", value: .string(State.foreground.rawValue))
            .startSpan()
        span.end()
    }

    @objc func terminate(_ notification: Notification) {
        let span = Self.getTracer()
            .spanBuilder(spanName: Self.eventName)
            .setAttribute(key: "lifecycle.state", value: .string(State.terminate.rawValue))
            .startSpan()
        span.end()
    }
}

#endif
