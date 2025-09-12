class LRUCache<K, V>(private val capacity: Int) {

    private inner class Node(
            val key: K,
            var value: V,
            var prev: Node? = null,
            var next: Node? = null
    )

    private val map = HashMap<K, Node>()
    private var head: Node? = null // Most recently used
    private var tail: Node? = null // Least recently used

    init {
        require(capacity > 0) { "LRUCache capacity must be greater than 0" }
    }

    @Synchronized
    fun get(key: K): V? {
        val node = map[key] ?: return null
        moveToHead(node)
        return node.value
    }

    @Synchronized
    fun put(key: K, value: V) {
        val node = map[key]
        if (node != null) {
            node.value = value
            moveToHead(node)
        } else {
            val newNode = Node(key, value)
            map[key] = newNode
            addToHead(newNode)

            if (map.size > capacity) {
                removeTail()?.let { removed -> map.remove(removed.key) }
            }
        }
    }

    // ==== Private helpers ====
    private fun moveToHead(node: Node) {
        removeNode(node)
        addToHead(node)
    }

    private fun addToHead(node: Node) {
        node.prev = null
        node.next = head
        head?.prev = node
        head = node
        if (tail == null) {
            tail = node
        }
    }

    private fun removeNode(node: Node) {
        val prev = node.prev
        val next = node.next

        if (prev != null) {
            prev.next = next
        } else {
            head = next
        }

        if (next != null) {
            next.prev = prev
        } else {
            tail = prev
        }
    }

    private fun removeTail(): Node? {
        val node = tail ?: return null
        removeNode(node)
        return node
    }
}
