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
