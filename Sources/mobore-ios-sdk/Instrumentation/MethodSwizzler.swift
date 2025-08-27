import Foundation

enum SwizzleError: Error {
    case targetNotFound(class: String, method: String)
}

internal class MethodSwizzler<T, U>: Instrumentor {
    typealias IMPSignature = T
    typealias BlockSignature = U
    let selector: Selector
    let klass: AnyClass
    let target: Method

    required internal init(selector: Selector, klass: AnyClass) throws {
        self.selector = selector
        self.klass = klass
         guard let method = class_getInstanceMethod(klass, selector) else {
            throw SwizzleError.targetNotFound(class: NSStringFromClass(klass), method: NSStringFromSelector(selector))
        }
        target = method
    }

    func swap(with conversion: (IMPSignature) -> BlockSignature) {
        sync {
            // Debug-time validation: Check method type encoding when available
            if let methodSignature = method_getTypeEncoding(target) {
                let signatureString = String(cString: methodSignature)
                // Basic validation - type encoding should not be empty
                assert(!signatureString.isEmpty, "Method signature validation failed: empty type encoding for \(NSStringFromSelector(selector)) on \(NSStringFromClass(klass))")
            }
            // Note: method_getTypeEncoding can return nil for methods without type info, which is valid

            let implementation = method_getImplementation(target)
            let currentObjCImp = unsafeBitCast(implementation, to: IMPSignature.self)
            let newBlock: BlockSignature = conversion(currentObjCImp)
            let newIMP: IMP = imp_implementationWithBlock(newBlock)
            method_setImplementation(target, newIMP)
        }
    }

    @discardableResult
    private func sync<V>(block: () -> V) -> V {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        return block()
    }

}
