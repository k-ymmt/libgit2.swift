import Cgit2

extension Repository {
    /// Allocates a libgit2 `git_signature *` from a Swift ``Signature`` value.
    ///
    /// Caller owns the returned pointer and is responsible for
    /// `git_signature_free`. Caller must already hold `repository.lock`.
    internal func signatureHandle(
        for sig: Signature
    ) throws(GitError) -> UnsafeMutablePointer<git_signature> {
        var out: UnsafeMutablePointer<git_signature>?
        try check(
            git_signature_new(
                &out,
                sig.name, sig.email,
                git_time_t(sig.date.timeIntervalSince1970),
                Int32(sig.timeZone.secondsFromGMT() / 60)
            )
        )
        return out!
    }

    /// Writes a new commit to the ODB and optionally advances a reference to it.
    ///
    /// - Parameters:
    ///   - tree: The tree that represents the commit's file snapshot.
    ///   - parents: The parent commits in the order Git should record them.
    ///     Empty for an initial commit, one for a regular commit, two or more
    ///     for a merge commit.
    ///   - author: The author signature.
    ///   - committer: The committer signature. Defaults to `author`.
    ///   - message: The commit message. libgit2 does not append a trailing
    ///     newline — the caller should include one if desired.
    ///   - updatingRef: If non-nil, the reference to advance atomically to the
    ///     new commit. Examples: `"HEAD"`, `"refs/heads/main"`. The ref need
    ///     not exist yet (supports initial commit on an unborn HEAD). If nil,
    ///     the commit is created but no reference points at it.
    /// - Returns: The created ``Commit`` handle.
    public func commit(
        tree: Tree,
        parents: [Commit],
        author: Signature,
        committer: Signature? = nil,
        message: String,
        updatingRef: String? = nil
    ) throws(GitError) -> Commit {
        let effectiveCommitter = committer ?? author

        return try lock.withLock { () throws(GitError) -> Commit in
            let authorSig = try signatureHandle(for: author)
            defer { git_signature_free(authorSig) }
            let committerSig = try signatureHandle(for: effectiveCommitter)
            defer { git_signature_free(committerSig) }

            var parentHandles: [OpaquePointer?] = parents.map { $0.handle }

            var newOID = git_oid()
            let result: Int32 = parentHandles.withUnsafeMutableBufferPointer { buf in
                message.withCString { msg in
                    if let ref = updatingRef {
                        return ref.withCString { refPtr in
                            git_commit_create(
                                &newOID, handle, refPtr,
                                authorSig, committerSig,
                                /* message_encoding */ nil, msg,
                                tree.handle,
                                parents.count, buf.baseAddress
                            )
                        }
                    } else {
                        return git_commit_create(
                            &newOID, handle, /* update_ref */ nil,
                            authorSig, committerSig,
                            nil, msg,
                            tree.handle,
                            parents.count, buf.baseAddress
                        )
                    }
                }
            }
            try check(result)

            var commitHandle: OpaquePointer?
            try check(git_commit_lookup(&commitHandle, handle, &newOID))
            return Commit(handle: commitHandle!, repository: self)
        }
    }
}
