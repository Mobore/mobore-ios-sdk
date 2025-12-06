import Foundation
import os.activity

struct MoboreActivityStack {

    private var items: [AnyObject] = []

    func peek() -> AnyObject? {
        return items.last
    }

    mutating func pop() -> AnyObject? {
        return items.popLast()
    }

    mutating func push(_ element: AnyObject) {
        items.append(element)
    }

    mutating func remove(_ element: AnyObject) {
        items.removeAll(where: {$0 === element})
    }
}
