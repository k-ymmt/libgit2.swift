import Cgit2

extension Repository {
    /// Current operational state (``State``). Wraps `git_repository_state`.
    ///
    /// ``State/none`` means no pending merge / cherry-pick / rebase / bisect.
    public var state: State {
        lock.withLock {
            State(git_repository_state(handle))
        }
    }
}
