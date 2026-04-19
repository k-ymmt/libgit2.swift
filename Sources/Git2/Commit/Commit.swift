import Cgit2

/// A single commit in the repository's object database.
///
/// ``Commit`` owns a libgit2 commit handle and holds a strong reference to its
/// parent ``Repository``. All access is serialized through the parent repository's
/// internal lock.
///
/// Most properties are cheap reads of data already in the commit object. The one
/// exception is ``parents()``, which looks up each parent commit in the object
/// database and is therefore a method rather than a property.
public final class Commit: @unchecked Sendable {
    internal let handle: OpaquePointer

    /// The repository this commit belongs to.
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_commit_free(handle)
    }

    /// This commit's OID.
    public var oid: OID {
        repository.lock.withLock {
            // libgit2 contract: git_commit_id is non-NULL for a valid commit handle.
            OID(raw: git_commit_id(handle)!.pointee)
        }
    }

    /// The commit message, including the trailing newline.
    public var message: String {
        repository.lock.withLock {
            // libgit2 contract: git_commit_message is non-NULL for a valid commit handle.
            String(cString: git_commit_message(handle)!)
        }
    }

    /// The first line of ``message``.
    public var summary: String {
        repository.lock.withLock {
            // libgit2 contract: git_commit_summary is non-NULL for commits with a message.
            String(cString: git_commit_summary(handle)!)
        }
    }

    /// The commit message body — everything after ``summary`` — or `nil` if the
    /// commit has only a summary line.
    public var body: String? {
        repository.lock.withLock {
            guard let cstr = git_commit_body(handle) else { return nil }
            return String(cString: cstr)
        }
    }

    /// The commit's author signature.
    public var author: Signature {
        repository.lock.withLock {
            Signature(copyingFrom: git_commit_author(handle))
        }
    }

    /// The commit's committer signature.
    ///
    /// This usually matches ``author`` but may differ (e.g. on `git commit
    /// --amend` after a rebase).
    public var committer: Signature {
        repository.lock.withLock {
            Signature(copyingFrom: git_commit_committer(handle))
        }
    }

    /// The number of parents this commit has.
    ///
    /// Zero for an initial commit, one for a regular commit, two or more for a
    /// merge commit. This is a cheap read that does not touch the object database.
    public var parentCount: Int {
        repository.lock.withLock {
            Int(git_commit_parentcount(handle))
        }
    }

    /// Resolves this commit's parents, looking each one up in the object database.
    ///
    /// Exposed as a method (not a property) because each call performs up to
    /// ``parentCount`` object database lookups.
    ///
    /// - Returns: The parent commits in the order Git records them. Empty for
    ///   an initial commit.
    /// - Throws: ``GitError`` if any parent lookup fails.
    public func parents() throws(GitError) -> [Commit] {
        try repository.lock.withLock { () throws(GitError) -> [Commit] in
            let count = git_commit_parentcount(handle)
            var out: [Commit] = []
            out.reserveCapacity(Int(count))
            for index: UInt32 in 0..<count {
                var raw: OpaquePointer?
                try check(git_commit_parent(&raw, handle, index))
                out.append(Commit(handle: raw!, repository: repository))
            }
            return out
        }
    }
}
