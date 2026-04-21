import Foundation
@testable import Git2
import Cgit2

/// Two-repo fixture for testing `file://` fetch.
///
/// - `upstream.git` is bare and seeded with `seedCommitCount` linear
///   commits on `main`.
/// - `downstream` is a non-bare repo with no remote configured.
///
/// Callers create `origin` pointing at `fixture.upstreamURLString` and
/// fetch.
struct LocalRemoteFixture {
    /// File-system path to the bare upstream repo.
    let upstreamURL: URL
    /// File-system path to the non-bare downstream repo.
    let downstreamURL: URL
    /// `file://...` URL string suitable for `createRemote(named:url:)`.
    let upstreamURLString: String
    /// OIDs of the seed commits, ordered oldest → newest.
    let seedOIDs: [OID]

    static func make(
        in parentDir: URL,
        seedCommitCount: Int = 3,
        author: Signature = Signature(name: "A", email: "a@example.com", date: Date(timeIntervalSince1970: 1700000000), timeZone: TimeZone(identifier: "UTC")!)
    ) throws -> LocalRemoteFixture {
        let upstream   = parentDir.appendingPathComponent("upstream.git")
        let downstream = parentDir.appendingPathComponent("downstream")

        // 1. Init a bare upstream + seed it with commits.
        var upRaw: OpaquePointer?
        let upRC: Int32 = upstream.withUnsafeFileSystemRepresentation { p in
            guard let p else { return -1 }
            return git_repository_init(&upRaw, p, 1)  // is_bare = 1
        }
        guard upRC == 0, let upRaw else { throw GitError.fromLibgit2(upRC) }
        git_repository_free(upRaw)

        let upRepo = try Repository.open(at: upstream)
        var oids: [OID] = []
        var previous: Commit? = nil
        for i in 0..<seedCommitCount {
            let data = Data("commit \(i)\n".utf8)
            let blobOID = try upRepo.createBlob(data: data)
            let tree = try upRepo.tree(entries: [
                .init(name: "README.md", oid: blobOID, filemode: .blob)
            ])
            let parents: [Commit] = previous.map { [$0] } ?? []
            let commit = try upRepo.commit(
                tree: tree,
                parents: parents,
                author: author,
                message: "commit \(i)",
                updatingRef: "HEAD"
            )
            oids.append(commit.oid)
            previous = commit
        }

        // 2. Init an empty non-bare downstream.
        var downRaw: OpaquePointer?
        let downRC: Int32 = downstream.withUnsafeFileSystemRepresentation { p in
            guard let p else { return -1 }
            return git_repository_init(&downRaw, p, 0)
        }
        guard downRC == 0, let downRaw else { throw GitError.fromLibgit2(downRC) }
        git_repository_free(downRaw)

        return LocalRemoteFixture(
            upstreamURL: upstream,
            downstreamURL: downstream,
            upstreamURLString: "file://" + upstream.path,
            seedOIDs: oids
        )
    }
}
