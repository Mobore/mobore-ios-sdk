import Foundation

/// Provides current device time information.
internal protocol DateProvider {
    /// Current device time.
    func currentDate() -> Date
}

internal struct SystemDateProvider: DateProvider {
    @inlinable
    func currentDate() -> Date { return Date() }
}
