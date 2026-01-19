public protocol Interceptor<Item> {
  associatedtype Item
  func intercept(_ item: Item) -> Item
}

extension Interceptor {
  func join(_ other: any Interceptor<Item>) -> any Interceptor<Item> {
    if self is NoopInterceptor<Item> { return other }
    if other is NoopInterceptor<Item> { return self }
    return MultiInterceptor([self, other])
  }
  func join(_ closure: @escaping (Item) -> (Item)) -> any Interceptor<Item> {
    return self.join(ClosureInterceptor<Item>(closure))
  }
}
