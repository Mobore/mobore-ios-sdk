import Foundation
#if canImport(UIKit)
import UIKit
#endif
import OpenTelemetryApi

final class MoboreExitInstrumentation {
    #if canImport(UIKit)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
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
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        #endif
    }

    deinit {
        stop()
    }

    @objc private func appWillTerminate(_ notification: Notification) {
        handleExit(reason: "terminate")
    }

    @objc private func appEnteredBackground(_ notification: Notification) {
        handleExit(reason: "background")
    }

    private func handleExit(reason: String) {
        #if canImport(UIKit)
        // Ensure we get time to flush before suspension.
        var shouldEndTask = false
        if backgroundTask == .invalid {
            backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "mobore-exit-flush") { [weak self] in
                guard let self = self else { return }
                if self.backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(self.backgroundTask)
                    self.backgroundTask = .invalid
                }
            }
            shouldEndTask = backgroundTask != .invalid
        }
        #endif
        // 1) End root session span first to ensure it gets exported
        MoboreIosSdkAgent.endRootSessionNow()
        // Then end any remaining active spans
        MoboreSpanProcessor.endAllActiveSpans()

        // 2) Record exit event
        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "ExitInstrumentation", instrumentationVersion: "0.0.1")
        let span = tracer.spanBuilder(spanName: "app.exit").startSpan()
        span.setAttribute(key: "app.exit.reason", value: .string(reason))
        span.end()

        // 3) End the session (rotate so new app start uses new session)
        MoboreSessionManager.instance.endSession()

        // 4) Force flush traces and logs immediately
        MoboreSpanProcessor.forceFlushAll(timeout: 2.0)
        MoboreLogRecordProcessor.forceFlushAll(explicitTimeout: 2.0)

        #if canImport(UIKit)
        if shouldEndTask && backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        #endif
    }
}


