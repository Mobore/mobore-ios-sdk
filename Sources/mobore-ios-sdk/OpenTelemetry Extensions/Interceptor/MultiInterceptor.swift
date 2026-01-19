public struct MultiInterceptor<T>: Interceptor {
  var interceptors: [any Interceptor<T>] = []

  public init(_ interceptors: [any Interceptor<T>]) {
    interceptors.filter { $0 is MultiInterceptor<T> }.forEach {
      if let multiInterceptor = $0 as? MultiInterceptor<T> {
        self.interceptors.append(contentsOf: multiInterceptor.interceptors)
      }
    }
    interceptors
      .filter { !($0 is MultiInterceptor<T> || $0 is NoopInterceptor<T>) }
      .forEach {
        self.interceptors.append($0)
    }
  }

  public func intercept(_ item: T) -> T {
    var result: T = item
    interceptors.forEach {
      result = $0.intercept(result)
    }
    return result
  }
}
