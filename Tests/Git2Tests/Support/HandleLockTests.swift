import Testing
@testable import Git2

@Test
func handleLockSerializesIncrements() async {
    final class Counter: @unchecked Sendable {
        var value = 0
    }
    let lock = HandleLock()
    let counter = Counter()

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<1_000 {
            group.addTask {
                lock.withLock { counter.value += 1 }
            }
        }
    }

    #expect(counter.value == 1_000)
}

@Test
func handleLockPropagatesTypedThrow() {
    struct Boom: Error, Equatable {}
    let lock = HandleLock()

    #expect(throws: Boom.self) {
        try lock.withLock { () throws(Boom) -> Void in
            throw Boom()
        }
    }
}
