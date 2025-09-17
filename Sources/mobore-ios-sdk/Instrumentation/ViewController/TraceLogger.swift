// Copyright © 2021 Moboresearch BV
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
#if os(iOS)
import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import SwiftUI
import UIKit
import os

class TraceLogger {
  private static var objectKey: UInt8 = 0
  private static var timerKey: UInt8 = 0
  private var activeSpan: Span?
  private var loadCount: Int = 0
  private let spanLock = NSRecursiveLock()
  private let logger = OSLog(subsystem: "com.mobore.viewControllerInstrumentation", category: "Instrumentation")

  // Track last emitted view name to detect navigation transitions
  private static var lastViewLock = NSLock()
  private static var lastViewName: String?

  func startTrace(tracer: Tracer, associatedObject: AnyObject, name: String, preferredName: String?) -> Span? {
    spanLock.lock()
    defer {
      spanLock.unlock()
    }
    loadCount+=1
    var activeSpan = getActiveSpan()

    if activeSpan == nil {
      let builder = tracer.spanBuilder(spanName: "\(name)")
        .setActive(true)
        .setNoParent()

      let span = builder.startSpan()
      os_log("Started trace: %@ - %@ - %@",
             log: logger,
             type: .debug,
             name,
             span.context.traceId.description,
             span.context.spanId.description)

      setActiveSpan(span)
      activeSpan = span
    }

    if let span = activeSpan {
      OpenTelemetry.instance.contextProvider.setActiveSpan(span)

    }

    if let preferredName = preferredName, activeSpan?.name != preferredName {
      activeSpan?.name = preferredName

    }
    return activeSpan
  }

  func stopTrace(associatedObject: AnyObject, preferredName: String?) {
    spanLock.lock()
    defer {
      spanLock.unlock()
    }

    if let activeSpan = getActiveSpan() {
      if let preferredName = preferredName, activeSpan.name != preferredName {
        activeSpan.name = preferredName
      }
      if !VCNameOverrideStore.shared().name.isEmpty {
        activeSpan.name = VCNameOverrideStore.shared().name
        VCNameOverrideStore.shared().name = ""
      }
      OpenTelemetry.instance.contextProvider.removeContextForSpan(activeSpan)
    }

    loadCount -= 1

    if  let associatedSpan = getActiveSpan(), loadCount == 0 {
      os_log("Stopping trace: %@ - %@ - %@",
             log: logger,
             type: .debug,
             associatedSpan.name,
             associatedSpan.context.traceId.description,
             associatedSpan.context.spanId.description)

      associatedSpan.status = .ok
      associatedSpan.end()
      setActiveSpan(nil)
    }

    // Emit view and navigation spans similar to old SDK behavior
    if let viewController = associatedObject as? UIViewController {
      let tracer = ViewControllerInstrumentation.getTracer()

      let toName = TraceLogger.computeScreenName(for: viewController, preferredName: preferredName)

      var fromName: String? = nil
      Self.lastViewLock.lock()
      fromName = Self.lastViewName
      Self.lastViewName = toName
      Self.lastViewLock.unlock()

      

      // Emit a view span for the appearing screen
      var attributes: [String: AttributeValue] = [
        "view.name": .string(toName),
        "view.url": .string(TraceLogger.buildViewUrl(for: toName))
      ]
      if let title = viewController.navigationItem.title, !title.isEmpty {
        attributes["view.title"] = .string(title)
      }
      let viewSpan = tracer.spanBuilder(spanName: "view.\(toName)").startSpan()
      viewSpan.setAttributes(attributes)
      viewSpan.end()
    }
  }

  func setActiveSpan(_ span: Span?) {
    spanLock.lock()
    defer {
      spanLock.unlock()
    }
    activeSpan = span
  }
  func getActiveSpan() -> Span? {
    spanLock.lock()
    defer {
      spanLock.unlock()
    }
    return activeSpan
  }

  private static func computeScreenName(for viewController: UIViewController, preferredName: String?) -> String {
    // Prefer explicit override set from SwiftUI via .reportName()
    let overrideName = VCNameOverrideStore.shared().name
    if !overrideName.isEmpty {
      return overrideName
    }

    if var name = preferredName, !name.isEmpty {    
      return name
    }

    // Try to resolve visible/top content VC for containers (NavigationStack, UINavigationController, etc.)
    let resolved = resolveTopContentViewController(from: viewController)
    if let title = resolved.navigationItem.title, !title.isEmpty {
      return title
    }
    return String(describing: type(of: resolved))
  }

  private static func buildViewUrl(for name: String) -> String {
    let bundleId = Bundle.main.bundleIdentifier ?? "app"
    return "ios://\(bundleId)/\(name)"
  }

  private static func resolveTopContentViewController(from viewController: UIViewController) -> UIViewController {
    // Follow UINavigationController
    if let nav = viewController as? UINavigationController {
      if let visible = nav.visibleViewController {
        return resolveTopContentViewController(from: visible)
      }
      if let top = nav.topViewController {
        return resolveTopContentViewController(from: top)
      }
    }
    // SwiftUI NavigationStackHostingController often embeds a UIHostingController child
    if let lastChild = viewController.children.last {
      return resolveTopContentViewController(from: lastChild)
    }
    // Presented view controller
    if let presented = viewController.presentedViewController {
      return resolveTopContentViewController(from: presented)
    }
    return viewController
  }
}
#endif // #if os(iOS)
