import Foundation

final class LRUCache<Key: Hashable, Value> {
    
    private class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    private let capacity: Int
    private var dict: [Key: Node] = [:]
    private var head: Node?  // Most recently used
    private var tail: Node?  // Least recently used
    private let lock = NSLock()
    
    init(capacity: Int) {
        precondition(capacity > 0, "LRUCache capacity must be greater than 0")
        self.capacity = capacity
    }
    
    func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let node = dict[key] else { return nil }
        moveToHead(node)
        return node.value
    }
    
    func put(_ key: Key, value: Value) {
        lock.lock()
        defer { lock.unlock() }
        
        if let node = dict[key] {
            node.value = value
            moveToHead(node)
        } else {
            let newNode = Node(key: key, value: value)
            dict[key] = newNode
            addToHead(newNode)
            
            if dict.count > capacity {
                if let tail = removeTail() {
                    dict.removeValue(forKey: tail.key)
                }
            }
        }
    }
    
    // MARK: - Private helpers
    
    private func moveToHead(_ node: Node) {
        removeNode(node)
        addToHead(node)
    }
    
    private func addToHead(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil {
            tail = node
        }
    }
    
    private func removeNode(_ node: Node) {
        let prev = node.prev
        let next = node.next
        
        if let prev = prev {
            prev.next = next
        } else {
            head = next
        }
        
        if let next = next {
            next.prev = prev
        } else {
            tail = prev
        }
    }
    
    private func removeTail() -> Node? {
        guard let tail = tail else { return nil }
        removeNode(tail)
        return tail
    }
}