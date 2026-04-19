import Foundation
@testable import Git2
import Cgit2

struct TestFixture {
    let repositoryURL: URL

    /// Creates a linear history in `directory`. Uses libgit2 directly because
    /// the Git2 wrapper does not yet expose commit creation.
    static func makeLinearHistory(
        commits: [(message: String, author: Signature)],
        in directory: URL
    ) throws -> TestFixture {
        // Init repo
        var repoHandle: OpaquePointer?
        let rInit: Int32 = directory.withUnsafeFileSystemRepresentation { path in
            guard let path else { return -1 }
            return git_repository_init(&repoHandle, path, 0)
        }
        guard rInit == 0, let repo = repoHandle else {
            throw GitError.fromLibgit2(rInit)
        }
        defer { git_repository_free(repo) }

        var previousOID: git_oid?

        for entry in commits {
            // Write blob
            var blobID = git_oid()
            try entry.message.withCString { bytes in
                let r = git_blob_create_from_buffer(&blobID, repo, UnsafeRawPointer(bytes), strlen(bytes))
                guard r == 0 else { throw GitError.fromLibgit2(r) }
            }

            // Build tree
            var builder: OpaquePointer?
            let rB = git_treebuilder_new(&builder, repo, nil)
            guard rB == 0, let tb = builder else { throw GitError.fromLibgit2(rB) }
            defer { git_treebuilder_free(tb) }
            let rIns = git_treebuilder_insert(nil, tb, "README.md", &blobID, GIT_FILEMODE_BLOB)
            guard rIns == 0 else { throw GitError.fromLibgit2(rIns) }
            var treeID = git_oid()
            let rW = git_treebuilder_write(&treeID, tb)
            guard rW == 0 else { throw GitError.fromLibgit2(rW) }
            var tree: OpaquePointer?
            let rT = git_tree_lookup(&tree, repo, &treeID)
            guard rT == 0, let treeH = tree else { throw GitError.fromLibgit2(rT) }
            defer { git_tree_free(treeH) }

            // Signature
            var sigPtr: UnsafeMutablePointer<git_signature>?
            let rSig = git_signature_new(
                &sigPtr,
                entry.author.name,
                entry.author.email,
                git_time_t(entry.author.date.timeIntervalSince1970),
                Int32(entry.author.timeZone.secondsFromGMT() / 60)
            )
            guard rSig == 0, let signature = sigPtr else { throw GitError.fromLibgit2(rSig) }
            defer { git_signature_free(signature) }

            // Parent commit (may be nil for the first commit)
            var parentHandle: OpaquePointer?
            defer { if let parentHandle { git_commit_free(parentHandle) } }
            if var pid = previousOID {
                let rLookup = git_commit_lookup(&parentHandle, repo, &pid)
                guard rLookup == 0, parentHandle != nil else { throw GitError.fromLibgit2(rLookup) }
            }

            // Create commit
            var commitID = git_oid()
            let r: Int32 = entry.message.withCString { msg in
                if let parent = parentHandle {
                    var parents: [OpaquePointer?] = [parent]
                    return parents.withUnsafeMutableBufferPointer { buf in
                        git_commit_create(
                            &commitID, repo, "HEAD",
                            signature, signature, "UTF-8", msg, treeH,
                            1, buf.baseAddress
                        )
                    }
                } else {
                    return git_commit_create(
                        &commitID, repo, "HEAD",
                        signature, signature, "UTF-8", msg, treeH,
                        0, nil
                    )
                }
            }
            guard r == 0 else { throw GitError.fromLibgit2(r) }
            previousOID = commitID
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
        var repoHandle: OpaquePointer?
        let rInit: Int32 = directory.withUnsafeFileSystemRepresentation { path in
            guard let path else { return -1 }
            return git_repository_init(&repoHandle, path, 0)
        }
        guard rInit == 0, let repo = repoHandle else { throw GitError.fromLibgit2(rInit) }
        defer { git_repository_free(repo) }

        var sigPtr: UnsafeMutablePointer<git_signature>?
        let rSig = git_signature_new(
            &sigPtr, "Tester", "tester@example.com",
            git_time_t(1_700_000_000), 0
        )
        guard rSig == 0, let signature = sigPtr else { throw GitError.fromLibgit2(rSig) }
        defer { git_signature_free(signature) }

        func writeTree(content: String) throws -> git_oid {
            var blobID = git_oid()
            try content.withCString { bytes in
                let r = git_blob_create_from_buffer(&blobID, repo, UnsafeRawPointer(bytes), strlen(bytes))
                guard r == 0 else { throw GitError.fromLibgit2(r) }
            }
            var builder: OpaquePointer?
            let rB = git_treebuilder_new(&builder, repo, nil)
            guard rB == 0, let tb = builder else { throw GitError.fromLibgit2(rB) }
            defer { git_treebuilder_free(tb) }
            let rI = git_treebuilder_insert(nil, tb, "README.md", &blobID, GIT_FILEMODE_BLOB)
            guard rI == 0 else { throw GitError.fromLibgit2(rI) }
            var treeID = git_oid()
            let rW = git_treebuilder_write(&treeID, tb)
            guard rW == 0 else { throw GitError.fromLibgit2(rW) }
            return treeID
        }

        func commit(tree treeID: git_oid, message: String, parents: [git_oid], updateRef: String?) throws -> git_oid {
            var tree: OpaquePointer?
            var treeIDCopy = treeID
            let rT = git_tree_lookup(&tree, repo, &treeIDCopy)
            guard rT == 0, let treeH = tree else { throw GitError.fromLibgit2(rT) }
            defer { git_tree_free(treeH) }

            var parentHandles: [OpaquePointer?] = []
            defer { for p in parentHandles { if let p { git_commit_free(p) } } }
            for var pid in parents {
                var parent: OpaquePointer?
                let r = git_commit_lookup(&parent, repo, &pid)
                guard r == 0, let ph = parent else { throw GitError.fromLibgit2(r) }
                parentHandles.append(ph)
            }

            var out = git_oid()
            let parentCount = parentHandles.count
            let r: Int32 = message.withCString { msg in
                parentHandles.withUnsafeMutableBufferPointer { buf in
                    git_commit_create(
                        &out, repo,
                        updateRef,
                        signature, signature,
                        "UTF-8", msg,
                        treeH,
                        parentCount,
                        buf.baseAddress
                    )
                }
            }
            guard r == 0 else { throw GitError.fromLibgit2(r) }
            return out
        }

        // A on main
        let treeA = try writeTree(content: "A")
        let oidA = try commit(tree: treeA, message: "A", parents: [], updateRef: "HEAD")

        // B on main
        let treeB = try writeTree(content: "B")
        let oidB = try commit(tree: treeB, message: "B", parents: [oidA], updateRef: "HEAD")

        // C on a side branch (refs/heads/side)
        let treeC = try writeTree(content: "C")
        let oidC = try commit(tree: treeC, message: "C", parents: [oidA], updateRef: "refs/heads/side")

        // D on main with B and C as parents (merge commit)
        let treeD = try writeTree(content: "D")
        _ = try commit(tree: treeD, message: "D (merge)", parents: [oidB, oidC], updateRef: "HEAD")

        return TestFixture(repositoryURL: directory)
    }
}

extension TestFixture {
    /// Entry description for ``makeCommitWithTree``.
    struct TreeEntryDescription {
        let path: String
        let content: Data
        let mode: git_filemode_t

        init(path: String, content: Data, mode: git_filemode_t) {
            self.path = path
            self.content = content
            self.mode = mode
        }

        /// Convenience initializer that encodes the string as UTF-8.
        init(path: String, content: String, mode: git_filemode_t) {
            self.init(path: path, content: Data(content.utf8), mode: mode)
        }
    }

    /// Creates a repository with a single commit whose tree contains the given
    /// entries. Executable / symlink / submodule modes are supported via
    /// `git_filemode_t`. Returns (fixture, treeOID, commitOID).
    @discardableResult
    static func makeCommitWithTree(
        entries: [TreeEntryDescription],
        message: String = "initial",
        in directory: URL
    ) throws -> (fixture: TestFixture, treeOID: git_oid, commitOID: git_oid) {
        var repoHandle: OpaquePointer?
        let rInit: Int32 = directory.withUnsafeFileSystemRepresentation { path in
            guard let path else { return -1 }
            return git_repository_init(&repoHandle, path, 0)
        }
        guard rInit == 0, let repo = repoHandle else { throw GitError.fromLibgit2(rInit) }
        defer { git_repository_free(repo) }

        // Build tree.
        var builder: OpaquePointer?
        let rB = git_treebuilder_new(&builder, repo, nil)
        guard rB == 0, let tb = builder else { throw GitError.fromLibgit2(rB) }
        defer { git_treebuilder_free(tb) }

        for entry in entries {
            var blobID = git_oid()
            let rBlob = entry.content.withUnsafeBytes { buf -> Int32 in
                // buf.baseAddress may be nil only when count == 0; libgit2's
                // git_blob_create_from_buffer accepts a NULL pointer when len == 0,
                // but to be safe we pass a valid non-nil pointer.
                let ptr = buf.baseAddress ?? UnsafeRawPointer(bitPattern: 1)!
                return git_blob_create_from_buffer(&blobID, repo, ptr, buf.count)
            }
            guard rBlob == 0 else { throw GitError.fromLibgit2(rBlob) }
            let rIns = git_treebuilder_insert(nil, tb, entry.path, &blobID, entry.mode)
            guard rIns == 0 else { throw GitError.fromLibgit2(rIns) }
        }

        var treeID = git_oid()
        let rW = git_treebuilder_write(&treeID, tb)
        guard rW == 0 else { throw GitError.fromLibgit2(rW) }

        var tree: OpaquePointer?
        let rT = git_tree_lookup(&tree, repo, &treeID)
        guard rT == 0, let treeH = tree else { throw GitError.fromLibgit2(rT) }
        defer { git_tree_free(treeH) }

        var sigPtr: UnsafeMutablePointer<git_signature>?
        let rSig = git_signature_new(
            &sigPtr, "Tester", "tester@example.com",
            git_time_t(1_700_000_000), 0
        )
        guard rSig == 0, let signature = sigPtr else { throw GitError.fromLibgit2(rSig) }
        defer { git_signature_free(signature) }

        var commitID = git_oid()
        let rC: Int32 = message.withCString { msg in
            git_commit_create(
                &commitID, repo, "HEAD",
                signature, signature, "UTF-8", msg, treeH,
                0, nil
            )
        }
        guard rC == 0 else { throw GitError.fromLibgit2(rC) }

        return (TestFixture(repositoryURL: directory), treeID, commitID)
    }
}

extension TestFixture {
    /// Writes an annotated tag pointing at `target` and installs the
    /// `refs/tags/<name>` reference. Returns the annotated tag's OID.
    @discardableResult
    static func makeAnnotatedTag(
        name: String,
        pointingAt target: git_oid,
        targetKind: git_object_t = GIT_OBJECT_COMMIT,
        message: String = "annotated",
        tagger: Signature = .test,
        in repositoryURL: URL
    ) throws -> git_oid {
        var repoHandle: OpaquePointer?
        let rOpen: Int32 = repositoryURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { return -1 }
            return git_repository_open(&repoHandle, path)
        }
        guard rOpen == 0, let repo = repoHandle else { throw GitError.fromLibgit2(rOpen) }
        defer { git_repository_free(repo) }

        var targetHandle: OpaquePointer?
        var targetCopy = target
        let rTL = git_object_lookup(&targetHandle, repo, &targetCopy, targetKind)
        guard rTL == 0, let th = targetHandle else { throw GitError.fromLibgit2(rTL) }
        defer { git_object_free(th) }

        var sigPtr: UnsafeMutablePointer<git_signature>?
        let rSig = git_signature_new(
            &sigPtr,
            tagger.name, tagger.email,
            git_time_t(tagger.date.timeIntervalSince1970),
            Int32(tagger.timeZone.secondsFromGMT() / 60)
        )
        guard rSig == 0, let sig = sigPtr else { throw GitError.fromLibgit2(rSig) }
        defer { git_signature_free(sig) }

        var tagOID = git_oid()
        let rCreate: Int32 = name.withCString { namePtr in
            message.withCString { messagePtr in
                git_tag_create(&tagOID, repo, namePtr, th, sig, messagePtr, /* force */ 0)
            }
        }
        guard rCreate == 0 else { throw GitError.fromLibgit2(rCreate) }
        return tagOID
    }
}
