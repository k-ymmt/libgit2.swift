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

extension Repository {
    /// Reads the repository's pending operation message (typically
    /// `.git/MERGE_MSG`). Wraps `git_repository_message`.
    ///
    /// - Throws: ``GitError/Code/notFound`` when there is no pending message
    ///   (the standard state on a freshly-opened repo).
    public func message() throws(GitError) -> String {
        try lock.withLock { () throws(GitError) -> String in
            var buf = git_buf()
            try check(git_repository_message(&buf, handle))
            defer { git_buf_dispose(&buf) }
            guard let cStr = buf.ptr else { return "" }
            return String(cString: cStr)
        }
    }

    /// Removes the repository's pending operation message. Wraps
    /// `git_repository_message_remove`.
    ///
    /// - Throws: ``GitError/Code/notFound`` when there is no pending message.
    public func removeMessage() throws(GitError) {
        try lock.withLock { () throws(GitError) in
            try check(git_repository_message_remove(handle))
        }
    }
}
