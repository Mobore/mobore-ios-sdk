import Foundation

public enum MoboreAttributes: String {
    /**
    Timestamp applied to all spans at time of export. To help with clock drift.
     */
    case exportTimestamp = "telemetry.sdk.mobore_export_timestamp"

    /**
    The id of the device
     */
    case deviceIdentifier = "device.unique.id"

    case sessionId = "session.id"

    case serviceBuild = "service.build"

    // Session active usage duration (milliseconds)
    case sessionActiveDurationMs = "session.active_duration_ms"
}

public enum MoboreMetrics: String {
    case appLaunchTime = "application.launch.time"
    case appHangtime = "application.responsiveness.hangtime"
    case appExits = "application.exits"
    case sessionActiveUsageSeconds = "session.active_usage.seconds"
}
