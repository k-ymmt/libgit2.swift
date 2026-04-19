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
