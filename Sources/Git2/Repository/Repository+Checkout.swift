import Cgit2

extension Repository {
    /// Updates the working tree and index to match the commit HEAD points at.
    /// Equivalent to `git_checkout_head`.
    ///
    /// - Parameter options: Defaults to safe + no path filter.
    /// - Throws: ``GitError`` —
    ///   - ``GitError/Code/unbornBranch`` when HEAD is unborn.
    ///   - On a bare repository, libgit2 fails during HEAD resolution
    ///     before reaching the checkout engine; in practice this surfaces
    ///     as ``GitError/Code/unbornBranch`` with
    ///     ``GitError/Class/reference``. The exact class may change across
    ///     libgit2 versions.
    ///   - Checkout conflict errors (class ``GitError/Class/checkout``) when
    ///     `options.strategy` is safe and the working tree has divergent
    ///     changes.
    public func checkoutHead(
        options: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            try options.withCOptions { optsPtr throws(GitError) in
                try check(git_checkout_head(handle, optsPtr))
            }
        }
    }
}

extension Repository {
    /// Updates the working tree (and, by default, the index) to match `tree`.
    /// Equivalent to `git_checkout_tree`.
    ///
    /// Does **not** move HEAD. Pair with ``setHead(to:)`` (the `Commit`
    /// overload) or use ``checkout(branch:options:)`` when switching
    /// branches.
    public func checkoutTree(
        _ tree: Tree,
        options: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            try options.withCOptions { optsPtr throws(GitError) in
                try check(git_checkout_tree(handle, tree.handle, optsPtr))
            }
        }
    }

    /// Updates the working tree to match the tree pointed at by `commit`.
    /// Equivalent to `git_checkout_tree` with a commit treeish.
    ///
    /// Does **not** move HEAD. See the `Tree` overload of
    /// ``checkoutTree(_:options:)``.
    public func checkoutTree(
        _ commit: Commit,
        options: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            try options.withCOptions { optsPtr throws(GitError) in
                try check(git_checkout_tree(handle, commit.handle, optsPtr))
            }
        }
    }
}

extension Repository {
    /// Updates the working tree to match `index`. Pass `nil` (the default)
    /// to use the repository's current index. Equivalent to
    /// `git_checkout_index` — where a `NULL` `index` argument means "use the
    /// repo's cached index".
    public func checkoutIndex(
        _ index: Index? = nil,
        options: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            try options.withCOptions { optsPtr throws(GitError) in
                try check(git_checkout_index(handle, index?.handle, optsPtr))
            }
        }
    }
}

extension Repository {
    /// Shared body for `checkout(branch:)` and `checkout(branchNamed:)`.
    ///
    /// Preconditions:
    /// - The lock is already held.
    /// - `branchHandle` is a valid `git_reference *`. Ownership stays with
    ///   the caller (this helper does **not** free it).
    ///
    /// Steps:
    /// 1. `git_reference_is_branch` — else throw `.invalidSpec` /
    ///    `.reference` **before** touching the working tree.
    /// 2. Peel to commit.
    /// 3. `git_checkout_tree`.
    /// 4. `git_repository_set_head` to the branch's canonical name.
    private func performCheckout(
        branchHandle: OpaquePointer,
        options: CheckoutOptions
    ) throws(GitError) {
        if git_reference_is_branch(branchHandle) == 0 {
            throw GitError(
                code: .invalidSpec,
                class: .reference,
                message: "checkout(branch:) requires a local branch reference"
            )
        }

        var commitHandle: OpaquePointer?
        try check(git_reference_peel(&commitHandle, branchHandle, GIT_OBJECT_COMMIT))
        defer { git_object_free(commitHandle) }

        try options.withCOptions { optsPtr throws(GitError) in
            try check(git_checkout_tree(handle, commitHandle, optsPtr))
        }

        // libgit2 contract: git_reference_name is non-NULL for a valid handle.
        let namePtr = git_reference_name(branchHandle)!
        try check(git_repository_set_head(handle, namePtr))
    }
}

extension Repository {
    /// Switches to `branch`: updates the working tree to its tree, then
    /// moves HEAD to point at it.
    ///
    /// Both steps run inside a single critical section. Another task cannot
    /// observe a state where the working tree matches the new branch but
    /// HEAD still points at the old one.
    ///
    /// If the first step succeeds but libgit2's `git_repository_set_head`
    /// then fails, the working tree is switched while HEAD is not. libgit2
    /// does not roll back, and neither does this wrapper. Check errors from
    /// this call and resolve manually if you hit that window.
    ///
    /// Rejects references that are not local branches up-front (before
    /// touching the working tree). Passing a tag, remote branch, or other
    /// non-branch reference throws ``GitError/Code/invalidSpec`` with
    /// ``GitError/Class/reference``.
    ///
    /// - Parameters:
    ///   - branch: A local branch reference.
    ///   - options: Defaults to safe + no path filter.
    /// - Throws: ``GitError``.
    public func checkout(
        branch: Reference,
        options: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            try performCheckout(branchHandle: branch.handle, options: options)
        }
    }
}

extension Repository {
    /// Switches to the local branch with the given short name. Sugar for
    /// `git_branch_lookup(GIT_BRANCH_LOCAL)` + ``checkout(branch:options:)``.
    ///
    /// - Parameter name: Short branch name (e.g. `"feature"`), no
    ///   `refs/heads/` prefix.
    /// - Throws: ``GitError`` — ``GitError/Code/notFound`` when the branch
    ///   does not exist, or any error surfaced by
    ///   ``checkout(branch:options:)``.
    public func checkout(
        branchNamed name: String,
        options: CheckoutOptions = CheckoutOptions()
    ) throws(GitError) {
        try lock.withLock { () throws(GitError) in
            var refHandle: OpaquePointer?
            let lookup: Int32 = name.withCString { namePtr in
                git_branch_lookup(&refHandle, handle, namePtr, GIT_BRANCH_LOCAL)
            }
            try check(lookup)
            defer { git_reference_free(refHandle) }

            try performCheckout(branchHandle: refHandle!, options: options)
        }
    }
}
