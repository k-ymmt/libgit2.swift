import Foundation
@testable import Git2
import Cgit2

struct TestFixture {
    let repositoryURL: URL

    /// Initializes a fresh non-bare repo at `directory` and returns an open
    /// ``Repository``. Private helper for the other factories.
    private static func initAndOpen(at directory: URL) throws -> Repository {
        var repoHandle: OpaquePointer?
        let rInit: Int32 = directory.withUnsafeFileSystemRepresentation { path in
            guard let path else { return -1 }
            return git_repository_init(&repoHandle, path, 0)
        }
        guard rInit == 0, let repoHandle else { throw GitError.fromLibgit2(rInit) }
        git_repository_free(repoHandle)
        return try Repository.open(at: directory)
    }

    /// Creates a linear history in `directory`.
    ///
    /// Each entry becomes a commit whose tree contains a single `README.md`
    /// blob holding the entry's message. This was the original v0.1 fixture
    /// and is now implemented via the v0.4a public write API.
    static func makeLinearHistory(
        commits: [(message: String, author: Signature)],
        in directory: URL
    ) throws -> TestFixture {
        let repo = try initAndOpen(at: directory)

        var previous: Commit? = nil
        for entry in commits {
            let blobOID = try repo.createBlob(data: Data(entry.message.utf8))
            let tree = try repo.tree(entries: [
                .init(name: "README.md", oid: blobOID, filemode: .blob)
            ])
            let parents: [Commit] = previous.map { [$0] } ?? []
            previous = try repo.commit(
                tree: tree,
                parents: parents,
                author: entry.author,
                message: entry.message,
                updatingRef: "HEAD"
            )
        }
        return TestFixture(repositoryURL: directory)
    }
}

extension TestFixture {
    /// Creates a repo with history:
    ///     A --- B --- D
    ///      \       /
    ///       C-----/
    /// `D` has two parents (`B` and `C`).
    static func makeMergeHistory(in directory: URL) throws -> TestFixture {
        let repo = try initAndOpen(at: directory)

        func treeFrom(_ content: String) throws -> Tree {
            let blob = try repo.createBlob(data: Data(content.utf8))
            return try repo.tree(entries: [
                .init(name: "README.md", oid: blob, filemode: .blob)
            ])
        }

        let a = try repo.commit(tree: try treeFrom("A"), parents: [],       author: .test, message: "A",         updatingRef: "HEAD")
        let b = try repo.commit(tree: try treeFrom("B"), parents: [a],      author: .test, message: "B",         updatingRef: "HEAD")
        let c = try repo.commit(tree: try treeFrom("C"), parents: [a],      author: .test, message: "C",         updatingRef: "refs/heads/side")
        _     = try repo.commit(tree: try treeFrom("D"), parents: [b, c],   author: .test, message: "D (merge)", updatingRef: "HEAD")

        return TestFixture(repositoryURL: directory)
    }
}

extension TestFixture {
    /// Entry description for ``makeCommitWithTree``.
    ///
    /// `mode` is deliberately `git_filemode_t` in this slice — several test
    /// suites exercise exec / symlink / submodule modes that don't all have
    /// public `TreeEntry.FileMode` cases at the call sites. Migration to the
    /// public type is tracked in TODO.md under "Deferred from v0.4a".
    struct TreeEntryDescription {
        let path: String
        let content: Data
        let mode: git_filemode_t

        init(path: String, content: Data, mode: git_filemode_t) {
            self.path = path
            self.content = content
            self.mode = mode
        }

        init(path: String, content: String, mode: git_filemode_t) {
            self.init(path: path, content: Data(content.utf8), mode: mode)
        }
    }

    /// Creates a repository with a single commit whose tree contains the given
    /// entries. Returns (fixture, treeOID, commitOID).
    @discardableResult
    static func makeCommitWithTree(
        entries: [TreeEntryDescription],
        message: String = "initial",
        in directory: URL
    ) throws -> (fixture: TestFixture, treeOID: git_oid, commitOID: git_oid) {
        let repo = try initAndOpen(at: directory)

        var builderEntries: [TreeBuilderEntry] = []
        for entry in entries {
            let blobOID = try repo.createBlob(data: entry.content)
            let filemode = try fileMode(from: entry.mode)
            builderEntries.append(
                TreeBuilderEntry(name: entry.path, oid: blobOID, filemode: filemode)
            )
        }
        let tree = try repo.tree(entries: builderEntries)
        let commit = try repo.commit(
            tree: tree, parents: [],
            author: .test, message: message,
            updatingRef: "HEAD"
        )

        return (TestFixture(repositoryURL: directory), tree.oid.raw, commit.oid.raw)
    }

    /// Narrow conversion used only here. Rejects the internal libgit2 sentinel
    /// `GIT_FILEMODE_UNREADABLE` that public `TreeEntry.FileMode` has no case
    /// for.
    private static func fileMode(from raw: git_filemode_t) throws -> TreeEntry.FileMode {
        switch raw {
        case GIT_FILEMODE_TREE:            return .tree
        case GIT_FILEMODE_BLOB:            return .blob
        case GIT_FILEMODE_BLOB_EXECUTABLE: return .blobExecutable
        case GIT_FILEMODE_LINK:            return .link
        case GIT_FILEMODE_COMMIT:          return .commit
        default:
            throw GitError(
                code: .invalid, class: .invalid,
                message: "unsupported filemode in fixture: \(raw.rawValue)"
            )
        }
    }
}

extension TestFixture {
    /// Create additional `refs/heads/<name>` pointing at `target` on top of an
    /// existing repository.
    static func makeBranches(
        names: [String],
        pointingAt target: git_oid,
        in repositoryURL: URL
    ) throws {
        let repo = try Repository.open(at: repositoryURL)
        let commit = try repo.commit(for: OID(raw: target))
        for name in names {
            _ = try repo.createBranch(named: name, at: commit, force: false)
        }
    }
}

extension TestFixture {
    /// Populates the repository's index with a synthetic three-way conflict
    /// on `path`. Only non-nil sides are inserted, so modify/delete-style
    /// conflicts are expressible by passing `nil` for one side.
    ///
    /// Uses libgit2 directly (`git_index_add` with stage-encoded flags)
    /// because v0.4b-i does not expose a public API for writing stage 1/2/3
    /// entries. Will migrate to the public Merge API once that slice lands
    /// (tracked in TODO.md under "Deferred from v0.4b-i").
    static func makeConflictedIndex(
        at path: String,
        ancestor: Data?,
        ours: Data?,
        theirs: Data?,
        in directory: URL
    ) throws {
        let repo = try Repository.open(at: directory)
        let index = try repo.index()

        func insert(_ payload: Data, stage: UInt16) throws {
            let blob = try repo.createBlob(data: payload)
            let result: Int32 = try repo.lock.withLock { () throws(GitError) -> Int32 in
                var entry = git_index_entry()
                entry.mode = UInt32(GIT_FILEMODE_BLOB.rawValue)
                entry.id = blob.raw
                let mask = UInt16(GIT_INDEX_ENTRY_STAGEMASK)
                let shift = UInt16(GIT_INDEX_ENTRY_STAGESHIFT)
                entry.flags = (stage << shift) & mask
                let r: Int32 = path.withCString { p in
                    entry.path = p
                    return git_index_add(index.handle, &entry)
                }
                return r
            }
            try check(result)
        }

        if let ancestor { try insert(ancestor, stage: 1) }
        if let ours     { try insert(ours,     stage: 2) }
        if let theirs   { try insert(theirs,   stage: 3) }
        try index.save()
    }
}

extension TestFixture {
    /// Writes an annotated tag pointing at `target`. Returns the annotated
    /// tag's OID.
    @discardableResult
    static func makeAnnotatedTag(
        name: String,
        pointingAt target: git_oid,
        targetKind: git_object_t = GIT_OBJECT_COMMIT,
        message: String = "annotated",
        tagger: Signature = .test,
        in repositoryURL: URL
    ) throws -> git_oid {
        let repo = try Repository.open(at: repositoryURL)

        // v0.4a createAnnotatedTag accepts `target: Commit`. The legacy
        // fixture signature accepts any libgit2 object kind via `targetKind`,
        // but every current caller passes GIT_OBJECT_COMMIT. Route commits
        // through the public API; anything else still goes through the raw
        // path for parity.
        if targetKind == GIT_OBJECT_COMMIT {
            let commit = try repo.commit(for: OID(raw: target))
            let tag = try repo.createAnnotatedTag(
                named: name, target: commit,
                tagger: tagger, message: message,
                force: false
            )
            return tag.oid.raw
        }

        // Raw path for non-commit targets (no public API yet — deferred per
        // TODO.md "Deferred from v0.4a").
        return try repo.lock.withLock { () throws(GitError) -> git_oid in
            var targetHandle: OpaquePointer?
            var targetCopy = target
            try check(git_object_lookup(&targetHandle, repo.handle, &targetCopy, targetKind))
            defer { git_object_free(targetHandle) }

            let taggerHandle = try repo.signatureHandle(for: tagger)
            defer { git_signature_free(taggerHandle) }

            var tagOID = git_oid()
            let result: Int32 = name.withCString { namePtr in
                message.withCString { msgPtr in
                    git_tag_create(
                        &tagOID, repo.handle, namePtr,
                        targetHandle, taggerHandle, msgPtr,
                        /* force */ 0
                    )
                }
            }
            try check(result)
            return tagOID
        }
    }
}
