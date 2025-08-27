import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

class SessionSampler: NSObject, Sampler {

  private struct SimpleDecision: Decision {
    let decision: Bool

    /// Creates sampling decision without attributes.
    /// - Parameter decision: sampling decision
    init(decision: Bool) {
      self.decision = decision
    }

    public var isSampled: Bool {
      return decision
    }

    public var attributes: [String: AttributeValue] {
      return [String: AttributeValue]()
    }
  }

  private let accessQueue = DispatchQueue(
    label: "SessionSampler.accessor", qos: .default, attributes: .concurrent)

  private let sampleRateResolver: () -> Double

  private var _shouldSample: Bool = true

  public private(set) var shouldSample: Bool {
    get {
      var shouldSample = true
      accessQueue.sync {
        shouldSample = _shouldSample
      }
      return shouldSample
    }
    set {
      accessQueue.async(flags: .barrier) {
        self._shouldSample = newValue
      }
    }
  }

  private override init() {
    self.sampleRateResolver = { return 1.0 }
    super.init()
  }

  init(_ sampleRateResolver: @escaping () -> Double) {
    self.sampleRateResolver = sampleRateResolver

    super.init()
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleSessionChange), name: .moboreSessionManagerDidRefreshSession,
      object: nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc
  func handleSessionChange(_ notification: NSNotification) {
    let sampleRate = sampleRateResolver()
    shouldSample = Double.random(in: 0...1) <= sampleRate
  }
  // swiftlint:disable:next function_parameter_count
  func shouldSample(
    parentContext: SpanContext?,
    traceId: TraceId,
    name: String,
    kind: SpanKind,
    attributes: [String: AttributeValue],
    parentLinks: [SpanData.Link]
  ) -> Decision {
    return SimpleDecision(decision: shouldSample)

  }
}
