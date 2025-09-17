#if os(iOS)
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI
import UIKit
import os

private extension NSLock {
  func withLockVoid(_ body: () -> Void) {
    lock()
    defer { unlock() }
    body()
  }
}

@available(iOS 13.0, *)
public extension SwiftUICore.View {
  func reportName(_ name: String) -> Self {
    VCNameOverrideStore.shared().name = name
    return self
  }
}

internal class VCNameOverrideStore {
  let nameLock = NSLock()
  private var _name = ""
  public var name: String {
    get {
      var newValue = ""
      nameLock.withLockVoid {
        newValue = self._name
      }
      return newValue
    }
    set {
      nameLock.withLockVoid {
        self._name = newValue
      }
    }
  }
  static var instance = VCNameOverrideStore()
  private init() {
  }

  static func shared() -> VCNameOverrideStore {
    return instance
  }
}

internal class ViewControllerInstrumentation {
  static let logger = OSLog(subsystem: "com.mobore.viewControllerInstrumentation", category: "Instrumentation")
  var activeSpan: Span?
  static let traceLogger = TraceLogger()
  let viewDidLoad: ViewDidLoad
  let viewWillAppear: ViewWillAppear
  let viewDidAppear: ViewDidAppear

  init() throws {
    viewDidLoad = try ViewDidLoad.build()
    viewWillAppear = try ViewWillAppear.build()
    viewDidAppear = try ViewDidAppear.build()
  }

  deinit {
    NotificationCenter.default.removeObserver(TraceLogger.self)
  }

  func swizzle() {
    //            viewDidLoad.swizzle()
    viewWillAppear.swizzle()
    viewDidAppear.swizzle()
  }

  static func getTracer() -> Tracer {
    OpenTelemetry.instance.tracerProvider.get(instrumentationName: "UIViewController",
                                              instrumentationVersion: "0.0.3")
  }

  static func getViewControllerName(_ viewController: UIViewController) -> String? {
    if !VCNameOverrideStore.shared().name.isEmpty {
      return VCNameOverrideStore.shared().name
    }
    var title = viewController.navigationItem.title

    if let accessibiltyLabel = viewController.accessibilityLabel, !accessibiltyLabel.isEmpty {
      title = "\(accessibiltyLabel)"
    } else if let navTitle = title {
      title = "\(navTitle)"
    } else {
      // Fallback to class name to ensure SwiftUI container controllers are named
      title = String(describing: type(of: viewController))
    }
    return "view.\(title)"
  }

  class ViewDidLoad: MethodSwizzler<
  @convention(c) (UIViewController, Selector) -> Void, // IMPSignature
  @convention(block) (UIViewController) -> Void // BlockSignature
  > {
    static func build() throws -> ViewDidLoad {
      try ViewDidLoad(selector: #selector(UIViewController.viewDidLoad), klass: UIViewController.self)
    }

    func swizzle() {
      swap { previousImplementation -> BlockSignature in { viewController in

        let name = "view.\(type(of: viewController))"
        _ = ViewControllerInstrumentation
          .traceLogger
          .startTrace(tracer: ViewControllerInstrumentation.getTracer(),
                      associatedObject: viewController,
                      name: name,
                      preferredName: ViewControllerInstrumentation.getViewControllerName(viewController))

        previousImplementation(viewController, self.selector)
        ViewControllerInstrumentation
          .traceLogger
          .stopTrace(associatedObject: viewController,
                     preferredName: name)
      }}
    }
  }

  class ViewWillAppear: MethodSwizzler<
  @convention(c) (UIViewController, Selector, Bool) -> Void,
  @convention(block) (UIViewController, Bool) -> Void
  > {
    static func build() throws -> ViewWillAppear {
      try ViewWillAppear(selector: #selector(UIViewController.viewWillAppear), klass: UIViewController.self)
    }

    func swizzle() {
      swap { previousImplementation -> BlockSignature in { viewController, animated in

        let name = "view.\(type(of: viewController))"

        _ = ViewControllerInstrumentation
          .traceLogger
          .startTrace(tracer: ViewControllerInstrumentation.getTracer(),
                      associatedObject: viewController,
                      name: name,
                      preferredName: ViewControllerInstrumentation.getViewControllerName(viewController))
        previousImplementation(viewController, self.selector, animated)

      }}
    }
  }

  class ViewDidAppear: MethodSwizzler<
  @convention(c) (UIViewController, Selector, Bool) -> Void, // IMPSignature
  @convention(block) (UIViewController, Bool) -> Void // BlockSignature
  > {
    static func build() throws -> ViewDidAppear {
      try ViewDidAppear(selector: #selector(UIViewController.viewDidAppear), klass: UIViewController.self)
    }
    func swizzle() {
      swap { previousImplementation -> BlockSignature in { viewController, animated in
        previousImplementation(viewController, self.selector, animated)
        ViewControllerInstrumentation
          .traceLogger
          .stopTrace(associatedObject: viewController,
                     preferredName: getViewControllerName(viewController))
        // Ensure status is OK on view spans
        if let span = OpenTelemetry.instance.contextProvider.activeSpan {
          span.status = .ok
        }
      }}
    }
  }
}

#endif // #if os(iOS)
