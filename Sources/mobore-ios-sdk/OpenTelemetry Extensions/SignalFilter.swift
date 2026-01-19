import Foundation

public struct SignalFilter<Signal> {
    public private(set) var shouldInclude: (Signal) -> Bool

    init(_ shouldInclude: @escaping (Signal) -> Bool) {
        self.shouldInclude = shouldInclude
    }
}
