import Foundation
#if canImport(UIKit)
import UIKit
#endif
import OpenTelemetryApi

final class ExitInstrumentation {
    func start() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appEnteredBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        #endif
    }

    func stop() {
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        #endif
    }

    deinit {
        stop()
    }

    @objc private func appWillTerminate() {
        handleExit(reason: "terminate")
    }

    @objc private func appEnteredBackground() {
        handleExit(reason: "background")
    }

    private func handleExit(reason: String) {
        // 1) End all spans
        MoboreSpanProcessor.endAllActiveSpans()

        // 2) Record exit event
        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ExitInstrumentation", instrumentationVersion: "0.0.1")
        let span = tracer.spanBuilder(spanName: "app.exit").startSpan()
        span.setAttribute(key: "app.exit.reason", value: .string(reason))
        span.end()

        // 3) End the session (rotate so new app start uses new session)
        SessionManager.instance.endSession()

        // 4) Force flush traces and logs immediately
        MoboreSpanProcessor.forceFlushAll(timeout: 2.0)
        MoboreLogRecordProcessor.forceFlushAll(explicitTimeout: 2.0)
    }
}


