import Foundation
@testable import Git2
import Cgit2

extension TestFixture {
    /// Creates a repository with two branches diverging from a shared
    /// ancestor, **without** conflicting edits.
    ///
    ///     base ─┬─> ours   (adds ours.txt)
    ///           └─> theirs (adds theirs.txt)
    ///
    /// `ours` is left on HEAD (as `refs/heads/main` or whatever the host
    /// default is); `theirs` lives at `refs/heads/<theirsBranch>`.
    ///
    /// Returns the fixture and the OIDs of the `ours` and `theirs` tip
    /// commits.
    @discardableResult
    static func makeDivergedBranches(
        theirsBranch: String = "theirs",
        in directory: URL
    ) throws -> (fixture: TestFixture, oursOID: OID, theirsOID: OID) {
        let repo = try initRepo(at: directory)

        func blob(_ text: String) throws -> OID { try repo.createBlob(data: Data(text.utf8)) }
        func tree(_ entries: [(String, OID)]) throws -> Tree {
            try repo.tree(entries: entries.map { .init(name: $0.0, oid: $0.1, filemode: .blob) })
        }

        // base (A)
        let baseBlob = try blob("base\n")
        let baseTree = try tree([("README.md", baseBlob)])
        let base = try repo.commit(
            tree: baseTree, parents: [],
            author: .test, message: "base",
            updatingRef: "HEAD"
        )

        // ours
        let ours1 = try blob("ours\n")
        let oursTree = try tree([("README.md", baseBlob), ("ours.txt", ours1)])
        let ours = try repo.commit(
            tree: oursTree, parents: [base],
            author: .test, message: "ours",
            updatingRef: "HEAD"
        )

        // theirs
        let theirs1 = try blob("theirs\n")
        let theirsTree = try tree([("README.md", baseBlob), ("theirs.txt", theirs1)])
        let theirs = try repo.commit(
            tree: theirsTree, parents: [base],
            author: .test, message: "theirs",
            updatingRef: "refs/heads/\(theirsBranch)"
        )

        return (TestFixture(repositoryURL: directory), ours.oid, theirs.oid)
    }

    /// Creates a repository with two branches that edit the same line of the
    /// same file incompatibly. Used to exercise conflict paths.
    ///
    /// Returns the fixture and the OIDs of the `ours` and `theirs` tip
    /// commits.
    @discardableResult
    static func makeConflictingBranches(
        theirsBranch: String = "theirs",
        in directory: URL
    ) throws -> (fixture: TestFixture, oursOID: OID, theirsOID: OID) {
        let repo = try initRepo(at: directory)

        func blob(_ text: String) throws -> OID { try repo.createBlob(data: Data(text.utf8)) }

        let baseBlob = try blob("shared\n")
        let baseTree = try repo.tree(entries: [
            .init(name: "file.txt", oid: baseBlob, filemode: .blob)
        ])
        let base = try repo.commit(
            tree: baseTree, parents: [],
            author: .test, message: "base",
            updatingRef: "HEAD"
        )

        let oursBlob = try blob("ours\n")
        let oursTree = try repo.tree(entries: [
            .init(name: "file.txt", oid: oursBlob, filemode: .blob)
        ])
        let ours = try repo.commit(
            tree: oursTree, parents: [base],
            author: .test, message: "ours",
            updatingRef: "HEAD"
        )

        let theirsBlob = try blob("theirs\n")
        let theirsTree = try repo.tree(entries: [
            .init(name: "file.txt", oid: theirsBlob, filemode: .blob)
        ])
        let theirs = try repo.commit(
            tree: theirsTree, parents: [base],
            author: .test, message: "theirs",
            updatingRef: "refs/heads/\(theirsBranch)"
        )

        return (TestFixture(repositoryURL: directory), ours.oid, theirs.oid)
    }

    /// Creates a repository where `refs/heads/<aheadBranch>` is strictly ahead
    /// of `HEAD` — no divergence, no conflicts. Useful for fast-forward paths.
    ///
    /// Returns the fixture, the HEAD OID, and the ahead-branch tip OID.
    @discardableResult
    static func makeFastForwardable(
        aheadBranch: String = "ahead",
        in directory: URL
    ) throws -> (fixture: TestFixture, headOID: OID, aheadOID: OID) {
        let repo = try initRepo(at: directory)

        func blob(_ text: String) throws -> OID { try repo.createBlob(data: Data(text.utf8)) }
        func tree(_ name: String, _ oid: OID) throws -> Tree {
            try repo.tree(entries: [.init(name: name, oid: oid, filemode: .blob)])
        }

        let b1 = try blob("one\n")
        let c1 = try repo.commit(
            tree: try tree("README.md", b1),
            parents: [], author: .test, message: "1",
            updatingRef: "HEAD"
        )

        let b2 = try blob("two\n")
        let c2 = try repo.commit(
            tree: try tree("README.md", b2),
            parents: [c1], author: .test, message: "2",
            updatingRef: "refs/heads/\(aheadBranch)"
        )

        return (TestFixture(repositoryURL: directory), c1.oid, c2.oid)
    }
}
