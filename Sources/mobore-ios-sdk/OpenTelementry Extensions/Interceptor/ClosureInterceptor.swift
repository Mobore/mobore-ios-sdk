public struct ClosureInterceptor<T>: Interceptor {
  let interceptor: (T) -> T
  public init(_ interceptor: @escaping (T) -> T) {
    self.interceptor = interceptor
  }
  public func intercept(_ item: T) -> T {
    return interceptor(item)
  }
}
