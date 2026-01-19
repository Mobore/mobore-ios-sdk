import Foundation
import OpenTelemetrySdk
import OpenTelemetryApi

extension ReadableSpan {
    func isHttpSpan() -> Bool {
        self.toSpanData().attributes.contains { key, _ in
            key == SemanticAttributes.httpUrl.rawValue
        }
    }
}
