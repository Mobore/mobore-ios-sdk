import Foundation

/// A unit capable of instrumenting a method via swizzling or interception.
protocol Instrumentor {
    /// The method selector to instrument.
    var selector: Selector { get }
    /// The class whose method will be instrumented.
    var klass: AnyClass { get }
    /// Initialize with a selector and class. Implementations may throw on invalid inputs.
    /// - Parameters:
    ///   - selector: The Objective-C selector to instrument
    ///   - klass: The class containing the method to instrument
    /// - Throws: Implementation-specific errors, typically when the method doesn't exist
    init(selector: Selector, klass: AnyClass) throws
}
