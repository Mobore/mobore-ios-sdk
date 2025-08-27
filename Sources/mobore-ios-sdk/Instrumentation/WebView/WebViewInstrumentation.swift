import Foundation
import OpenTelemetryApi
#if canImport(WebKit) && !os(watchOS)
import WebKit
import ObjectiveC
#if canImport(CoreGraphics)
import CoreGraphics
#endif

final class WebViewInstrumentation: NSObject {
  private let tracer: Tracer

  override init() {
    tracer = OpenTelemetry.instance
      .tracerProvider
      .get(instrumentationName: "WebView", instrumentationVersion: "0.0.1")
    super.init()
  }

  @MainActor func start() {
    WKWebView.mb_installNavigationDelegateHookIfNeeded()
    WKWebView.mb_setGlobalInstrumentation(self)
    // Ensure currently-set delegates (if any) are wrapped for new instances that call start after setting delegate.
    // For each webview created after start, the swizzled setter will wrap automatically.
  }

  func recordRequest(navigationAction: WKNavigationAction) {
    let urlString = navigationAction.request.url?.absoluteString ?? "unknown"
    var attributes: [String: AttributeValue] = [
      "webview.url": .string(urlString),
      "webview.method": .string(navigationAction.request.httpMethod ?? "GET")
    ]
    if let host = navigationAction.request.url?.host {
      attributes["webview.host"] = .string(host)
    }
    let span = tracer.spanBuilder(spanName: "webview.navigation.request").startSpan()
    attributes.forEach { span.setAttribute(key: $0.key, value: $0.value) }
    span.end()
  }

  func recordStart(webView: WKWebView) {
    let urlString = webView.url?.absoluteString
      ?? webView.backForwardList.currentItem?.url.absoluteString
      ?? "unknown"
    var attributes: [String: AttributeValue] = [
      "webview.url": .string(urlString)
    ]
    if let host = webView.url?.host {
      attributes["webview.host"] = .string(host)
    }
    let span = tracer.spanBuilder(spanName: "webview.navigation.start").startSpan()
    attributes.forEach { span.setAttribute(key: $0.key, value: $0.value) }
    span.end()
  }

  func recordFinish(webView: WKWebView) {
    let urlString = webView.url?.absoluteString
      ?? webView.backForwardList.currentItem?.url.absoluteString
      ?? "unknown"
    var attributes: [String: AttributeValue] = [
      "webview.url": .string(urlString)
    ]
    if let host = webView.url?.host {
      attributes["webview.host"] = .string(host)
    }
    let span = tracer.spanBuilder(spanName: "webview.navigation.finish").startSpan()
    attributes.forEach { span.setAttribute(key: $0.key, value: $0.value) }
    span.end()
  }

  func recordError(webView: WKWebView, error: Error) {
    let urlString = webView.url?.absoluteString
      ?? webView.backForwardList.currentItem?.url.absoluteString
      ?? "unknown"
    var attributes: [String: AttributeValue] = [
      "webview.url": .string(urlString),
      "error.message": .string(error.localizedDescription)
    ]
    if let host = webView.url?.host {
      attributes["webview.host"] = .string(host)
    }
    let span = tracer.spanBuilder(spanName: "webview.navigation.error").startSpan()
    attributes.forEach { span.setAttribute(key: $0.key, value: $0.value) }
    span.status = .error(description: error.localizedDescription)
    span.end()
  }
}

// MARK: - Delegate proxy & swizzling

@MainActor
final class MoboreWebViewNavigationDelegateProxy: NSObject, WKNavigationDelegate {
  weak var externalDelegate: WKNavigationDelegate?
  weak var instrumentation: WebViewInstrumentation?

  func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    instrumentation?.recordRequest(navigationAction: navigationAction)

    if let externalDelegate,
       externalDelegate.responds(to: NSSelectorFromString("webView:decidePolicyForNavigationAction:decisionHandler:")) {
      externalDelegate.webView?(webView, decidePolicyFor: navigationAction, decisionHandler: decisionHandler)
    } else {
      decisionHandler(.allow)
    }
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    instrumentation?.recordStart(webView: webView)
    if let externalDelegate,
       externalDelegate.responds(to: #selector(WKNavigationDelegate.webView(_:didStartProvisionalNavigation:))) {
      externalDelegate.webView?(webView, didStartProvisionalNavigation: navigation)
    }
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    instrumentation?.recordFinish(webView: webView)
    if let externalDelegate,
       externalDelegate.responds(to: #selector(WKNavigationDelegate.webView(_:didFinish:))) {
      externalDelegate.webView?(webView, didFinish: navigation)
    }
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    instrumentation?.recordError(webView: webView, error: error)
    if let externalDelegate,
       externalDelegate.responds(to: #selector(WKNavigationDelegate.webView(_:didFail:withError:))) {
      externalDelegate.webView?(webView, didFail: navigation, withError: error)
    }
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    instrumentation?.recordError(webView: webView, error: error)
    if let externalDelegate,
       externalDelegate.responds(to: #selector(WKNavigationDelegate.webView(_:didFailProvisionalNavigation:withError:))) {
      externalDelegate.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
    }
  }
}

@MainActor private var mbWebViewProxyKey: UInt8 = 0
@MainActor private var mbWebViewInstrumentationKey: UInt8 = 0
@MainActor private var mbWebViewHookInstalledKey: UInt8 = 0
@MainActor private var mbWebViewGlobalInstrumentationKey: UInt8 = 0

@MainActor
extension WKWebView {
  private var mb_proxy: MoboreWebViewNavigationDelegateProxy {
    if let proxy = objc_getAssociatedObject(self, &mbWebViewProxyKey) as? MoboreWebViewNavigationDelegateProxy { return proxy }
    let proxy = MoboreWebViewNavigationDelegateProxy()
    objc_setAssociatedObject(self, &mbWebViewProxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    return proxy
  }

  private var mb_instrumentation: WebViewInstrumentation? {
    get { objc_getAssociatedObject(self, &mbWebViewInstrumentationKey) as? WebViewInstrumentation }
    set { objc_setAssociatedObject(self, &mbWebViewInstrumentationKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
  }

  private static var mb_hookInstalled: Bool {
    get { (objc_getAssociatedObject(self, &mbWebViewHookInstalledKey) as? NSNumber)?.boolValue ?? false }
    set { objc_setAssociatedObject(self, &mbWebViewHookInstalledKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
  }

  static func mb_installNavigationDelegateHookIfNeeded() {
    guard !mb_hookInstalled else { return }
    mb_hookInstalled = true

    let originalSelector = NSSelectorFromString("setNavigationDelegate:")
    let swizzledSelector = #selector(WKWebView.mb_setNavigationDelegate(_:))

    if let originalMethod = class_getInstanceMethod(WKWebView.self, originalSelector),
       let swizzledMethod = class_getInstanceMethod(WKWebView.self, swizzledSelector) {
      method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    // Swizzle initializers to auto-assign proxy if no delegate is set
    let initSelector = NSSelectorFromString("initWithFrame:configuration:")
    let swizzledInitSelector = #selector(WKWebView.mb_initWithFrame(_:configuration:))
    if let originalInit = class_getInstanceMethod(WKWebView.self, initSelector),
       let swizzledInit = class_getInstanceMethod(WKWebView.self, swizzledInitSelector) {
      method_exchangeImplementations(originalInit, swizzledInit)
    }

    let initCoderSelector = NSSelectorFromString("initWithCoder:")
    let swizzledInitCoderSelector = #selector(WKWebView.mb_initWithCoder(_:))
    if let originalInitCoder = class_getInstanceMethod(WKWebView.self, initCoderSelector),
       let swizzledInitCoder = class_getInstanceMethod(WKWebView.self, swizzledInitCoderSelector) {
      method_exchangeImplementations(originalInitCoder, swizzledInitCoder)
    }
  }

  @objc func mb_setNavigationDelegate(_ delegate: WKNavigationDelegate?) {
    let proxy = mb_proxy
    proxy.externalDelegate = delegate
    proxy.instrumentation = mb_instrumentation
    self.mb_setNavigationDelegate(proxy)
  }

  func mb_wrapCurrentDelegate(with instrumentation: WebViewInstrumentation) {
    self.mb_instrumentation = instrumentation
    self.navigationDelegate = self.navigationDelegate
  }

  private static var mb_globalInstrumentation: WebViewInstrumentation? {
    get { objc_getAssociatedObject(self, &mbWebViewGlobalInstrumentationKey) as? WebViewInstrumentation }
    set { objc_setAssociatedObject(self, &mbWebViewGlobalInstrumentationKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
  }

  static func mb_setGlobalInstrumentation(_ instrumentation: WebViewInstrumentation) {
    self.mb_globalInstrumentation = instrumentation
  }

  @objc func mb_initWithFrame(_ frame: CGRect, configuration: WKWebViewConfiguration) -> WKWebView {
    let webView = self.mb_initWithFrame(frame, configuration: configuration)
    webView.mb_instrumentation = WKWebView.mb_globalInstrumentation
    webView.navigationDelegate = webView.navigationDelegate
    return webView
  }

  @objc func mb_initWithCoder(_ coder: NSCoder) -> WKWebView? {
    if let webView = self.mb_initWithCoder(coder) {
      webView.mb_instrumentation = WKWebView.mb_globalInstrumentation
      webView.navigationDelegate = webView.navigationDelegate
      return webView
    }
    return nil
  }
}

#endif


