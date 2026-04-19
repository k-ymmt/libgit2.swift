import Cgit2
import os

internal final class GitRuntime: @unchecked Sendable {
    static let shared = GitRuntime()

    private let lock = OSAllocatedUnfairLock<Int>(initialState: 0)

    private init() {}

    func bootstrap() throws(GitError) {
        // `OSAllocatedUnfairLock.withLock` requires `@Sendable` body and `rethrows`,
        // which can't forward typed throws. We route through `withLockUnchecked`
        // and carry the outcome across the lock boundary as a `Result<Void, GitError>`.
        let outcome: Result<Void, GitError> = lock.withLockUnchecked { state -> Result<Void, GitError> in
            do {
                if state == 0 {
                    try check(git_libgit2_init())
                    // Note: `GIT_OPT_ENABLE_THREADS` was removed in libgit2 1.9; threading is
                    // controlled at compile time via `GIT_FEATURE_THREADS` and is always
                    // enabled when libgit2 is built with threading support. No runtime
                    // opt-in is required (or possible).
                }
                state += 1
                return .success(())
            } catch let error as GitError {
                return .failure(error)
            } catch {
                fatalError("unreachable: typed throws guarantees GitError")
            }
        }
        try outcome.get()
    }

    func shutdown() throws(GitError) {
        let outcome: Result<Void, GitError> = lock.withLockUnchecked { state -> Result<Void, GitError> in
            guard state > 0 else { return .success(()) }
            do {
                // Symmetric with bootstrap: we only actually call libgit2 init on
                // the 0 -> 1 transition, so we should only call libgit2 shutdown
                // on the 1 -> 0 transition.
                if state == 1 {
                    try check(git_libgit2_shutdown())
                }
                state -= 1
                return .success(())
            } catch let error as GitError {
                return .failure(error)
            } catch {
                fatalError("unreachable: typed throws guarantees GitError")
            }
        }
        try outcome.get()
    }

    var isBootstrapped: Bool {
        lock.withLockUnchecked { $0 > 0 }
    }

    func requireBootstrapped(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        precondition(
            isBootstrapped,
            "Git.bootstrap() must be called before using \(function).",
            file: file,
            line: line
        )
    }
}
