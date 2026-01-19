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
public extension SwiftUI.View {
  func reportName(_ name: String) -> Self {
    MoboreVCNameOverrideStore.shared().name = name
    return self
  }
}

internal class MoboreVCNameOverrideStore {
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
  static var instance = MoboreVCNameOverrideStore()
  private init() {
  }

  static func shared() -> MoboreVCNameOverrideStore {
    return instance
  }
}

internal class MoboreViewControllerInstrumentation {
  static let logger = OSLog(subsystem: "com.mobore.viewControllerInstrumentation", category: "Instrumentation")
  var activeSpan: Span?
  static let traceLogger = MoboreTraceLogger()
  let viewDidLoad: ViewDidLoad
  let viewWillAppear: ViewWillAppear
  let viewDidAppear: ViewDidAppear

  init() throws {
    viewDidLoad = try ViewDidLoad.build()
    viewWillAppear = try ViewWillAppear.build()
    viewDidAppear = try ViewDidAppear.build()
  }

  deinit {
    NotificationCenter.default.removeObserver(MoboreTraceLogger.self)
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
    if !MoboreVCNameOverrideStore.shared().name.isEmpty {
      return MoboreVCNameOverrideStore.shared().name
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
        _ = MoboreViewControllerInstrumentation
          .traceLogger
          .startTrace(tracer: MoboreViewControllerInstrumentation.getTracer(),
                      associatedObject: viewController,
                      name: name,
                      preferredName: MoboreViewControllerInstrumentation.getViewControllerName(viewController))

        previousImplementation(viewController, self.selector)
        MoboreViewControllerInstrumentation
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

        _ = MoboreViewControllerInstrumentation
          .traceLogger
          .startTrace(tracer: MoboreViewControllerInstrumentation.getTracer(),
                      associatedObject: viewController,
                      name: name,
                      preferredName: MoboreViewControllerInstrumentation.getViewControllerName(viewController))
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
        MoboreViewControllerInstrumentation
          .traceLogger
          .stopTrace(associatedObject: viewController,
                     preferredName: getViewControllerName(viewController))
        // Ensure status is OK on the tracked view span
        if let span = MoboreViewControllerInstrumentation.traceLogger.getActiveSpan() {
          span.status = .ok
        }
      }}
    }
  }
}

#endif // #if os(iOS)
