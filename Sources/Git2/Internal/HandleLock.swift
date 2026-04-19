import os

internal struct HandleLock: Sendable {
    private let backing: OSAllocatedUnfairLock<Void>

    init() {
        self.backing = OSAllocatedUnfairLock()
    }

    @inline(__always)
    func withLock<T, E: Error>(_ body: () throws(E) -> T) throws(E) -> T {
        var result: Result<T, E>!
        backing.withLockUnchecked {
            do {
                result = .success(try body())
            } catch let error as E {
                result = .failure(error)
            } catch {
                fatalError("unreachable: typed throws guarantees E")
            }
        }
        switch result! {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
