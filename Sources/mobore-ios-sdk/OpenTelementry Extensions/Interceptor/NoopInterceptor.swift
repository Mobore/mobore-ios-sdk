public struct NoopInterceptor<Item>: Interceptor {
  public func intercept(_ item: Item) -> Item { return item }
}
