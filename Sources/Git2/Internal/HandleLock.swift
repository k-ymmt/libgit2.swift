import os

internal struct HandleLock: Sendable {
    private let backing: OSAllocatedUnfairLock<Void>

    init() {
        self.backing = OSAllocatedUnfairLock()
    }

    func withLock<T, E: Error>(_ body: () throws(E) -> T) throws(E) -> T {
        // `OSAllocatedUnfairLock.withLock` requires `@Sendable` body and `rethrows`,
        // which can't forward typed throws. We route through `withLockUnchecked`
        // and carry the outcome across the lock boundary as a `Result<T, E>`.
        let result: Result<T, E> = backing.withLockUnchecked {
            do {
                return .success(try body())
            } catch let error as E {
                return .failure(error)
            } catch {
                fatalError("unreachable: typed throws guarantees E")
            }
        }
        return try result.get()
    }
}
