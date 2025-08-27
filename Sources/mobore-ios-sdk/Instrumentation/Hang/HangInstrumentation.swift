import Foundation
import OpenTelemetryApi

final class HangInstrumentation {
    private var monitorThread: Thread?
    private var mainTimer: Timer?
    private var lastPingDate = Date()

    private let heartbeatInterval: TimeInterval = 0.5
    private let hangThreshold: TimeInterval = 2.0

    func start() {
        mainTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.lastPingDate = Date()
        }

        let thread = Thread { [weak self] in
            guard let self else { return }
            while !Thread.current.isCancelled {
                let elapsed = Date().timeIntervalSince(self.lastPingDate)
                if elapsed > self.hangThreshold {
                    self.reportHang(duration: elapsed)
                    self.lastPingDate = Date()
                }
                Thread.sleep(forTimeInterval: self.heartbeatInterval)
            }
        }
        thread.name = "mobore-hang-monitor"
        thread.start()
        monitorThread = thread
    }

    func stop() {
        mainTimer?.invalidate()
        mainTimer = nil
        monitorThread?.cancel()
        monitorThread = nil
    }

    private func reportHang(duration: TimeInterval) {
        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "HangInstrumentation", instrumentationVersion: "0.0.1")
        let span = tracer.spanBuilder(spanName: "app.hang")
            .setAttribute(key: "hang.duration", value: .double(duration))
            .startSpan()
        span.end()
    }
}


