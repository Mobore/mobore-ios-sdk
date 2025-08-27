import Foundation
import OpenTelemetryApi
#if canImport(UIKit)
import UIKit
#endif

final class LowPowerModeInstrumentation {
    func start() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChange), name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        #endif
        reportState()
    }

    func stop() {
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        #endif
    }

    @objc private func handleChange() {
        reportState()
    }

    private func reportState() {
        let tracer = OpenTelemetry.instance.tracerProvider.get(instrumentationName: "LowPowerModeInstrumentation", instrumentationVersion: "0.0.1")
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let span = tracer.spanBuilder(spanName: "device.low_power_mode")
            .setAttribute(key: "device.low_power", value: .bool(isLowPower))
            .startSpan()
        span.end()
    }
}


