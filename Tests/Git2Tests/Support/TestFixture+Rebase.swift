import Foundation
@testable import Git2
import Cgit2

extension TestFixture {
    /// Creates a repository with:
    ///   - `refs/heads/main`     (upstream, `upstreamAhead` non-conflicting commits)
    ///   - `refs/heads/feature`  (feature, `featureAhead` non-conflicting commits off the shared ancestor)
    ///
    /// Writes distinct file names per commit so `git_rebase_next` never
    /// encounters a conflict on the linear path.
    ///
    /// HEAD is left pointing at `refs/heads/feature`. The working tree is
    /// **not** materialized — tests must call
    /// `checkoutHead(options: .init(strategy: [.force]))` if they need the
    /// working tree on disk.
    ///
    /// Returns the fixture plus the OIDs of the `feature` and `upstream` tip
    /// commits.
    @discardableResult
    static func makeLinearRebase(
        upstreamAhead: Int = 2,
        featureAhead: Int = 3,
        in directory: URL
    ) throws -> (fixture: TestFixture, featureOID: OID, upstreamOID: OID) {
        let repo = try initRepo(at: directory)

        func blob(_ text: String) throws -> OID { try repo.createBlob(data: Data(text.utf8)) }
        func tree(_ entries: [(String, OID)]) throws -> Tree {
            try repo.tree(entries: entries.map {
                .init(name: $0.0, oid: $0.1, filemode: .blob)
            })
        }

        // base (A)
        let baseBlob = try blob("base\n")
        let baseEntries = [("README.md", baseBlob)]
        let base = try repo.commit(
            tree: try tree(baseEntries), parents: [],
            author: .test, message: "base",
            updatingRef: "HEAD"
        )

        // upstream (main): add u-1.txt, u-2.txt, …
        var upstreamTip: Commit = base
        var upstreamEntries = baseEntries
        for i in 1...upstreamAhead {
            let name = "u-\(i).txt"
            let content = "upstream \(i)\n"
            let b = try blob(content)
            upstreamEntries.append((name, b))
            upstreamTip = try repo.commit(
                tree: try tree(upstreamEntries), parents: [upstreamTip],
                author: .test, message: "upstream \(i)",
                updatingRef: "refs/heads/main"
            )
        }

        // Point HEAD at main (so feature is created relative to base, not upstream tip).
        try repo.setHead(referenceName: "refs/heads/main")

        // feature: add f-1.txt, f-2.txt, … starting from base tree
        var featureTip: Commit = base
        var featureEntries = baseEntries
        for i in 1...featureAhead {
            let name = "f-\(i).txt"
            let content = "feature \(i)\n"
            let b = try blob(content)
            featureEntries.append((name, b))
            featureTip = try repo.commit(
                tree: try tree(featureEntries), parents: [featureTip],
                author: .test, message: "feature \(i)",
                updatingRef: "refs/heads/feature"
            )
        }

        // Leave HEAD pointing at feature (matches the typical rebase call site).
        try repo.setHead(referenceName: "refs/heads/feature")

        return (TestFixture(repositoryURL: directory), featureTip.oid, upstreamTip.oid)
    }

    /// Creates a repository where `main` and `feature` both modify the same
    /// line of the same file — rebasing `feature` onto `main` yields a
    /// conflict on the first operation.
    ///
    /// HEAD is left pointing at `refs/heads/feature`.
    /// Returns the fixture plus the OIDs of the `feature` and `main` tip
    /// commits.
    @discardableResult
    static func makeConflictingRebase(
        in directory: URL
    ) throws -> (fixture: TestFixture, featureOID: OID, upstreamOID: OID) {
        let repo = try initRepo(at: directory)

        func blob(_ text: String) throws -> OID { try repo.createBlob(data: Data(text.utf8)) }
        func tree(_ blobOID: OID) throws -> Tree {
            try repo.tree(entries: [.init(name: "file.txt", oid: blobOID, filemode: .blob)])
        }

        let baseBlob = try blob("shared\n")
        let base = try repo.commit(
            tree: try tree(baseBlob), parents: [],
            author: .test, message: "base",
            updatingRef: "HEAD"
        )

        let mainBlob = try blob("main-side\n")
        let mainTip = try repo.commit(
            tree: try tree(mainBlob), parents: [base],
            author: .test, message: "main touches file.txt",
            updatingRef: "refs/heads/main"
        )

        try repo.setHead(referenceName: "refs/heads/main")

        let featureBlob = try blob("feature-side\n")
        let featureTip = try repo.commit(
            tree: try tree(featureBlob), parents: [base],
            author: .test, message: "feature touches file.txt",
            updatingRef: "refs/heads/feature"
        )

        try repo.setHead(referenceName: "refs/heads/feature")

        return (TestFixture(repositoryURL: directory), featureTip.oid, mainTip.oid)
    }

    /// Creates a repository where `feature`'s only commit has the same tree
    /// as `main`'s tip — rebasing `feature` onto `main` produces one
    /// operation whose commit is already applied.
    ///
    /// HEAD is left pointing at `refs/heads/feature`.
    /// Returns the fixture plus the OIDs of the `feature` and `main` tip
    /// commits.
    @discardableResult
    static func makeAlreadyApplied(
        in directory: URL
    ) throws -> (fixture: TestFixture, featureOID: OID, upstreamOID: OID) {
        let repo = try initRepo(at: directory)

        func blob(_ text: String) throws -> OID { try repo.createBlob(data: Data(text.utf8)) }
        func tree(_ blobOID: OID) throws -> Tree {
            try repo.tree(entries: [.init(name: "file.txt", oid: blobOID, filemode: .blob)])
        }

        let baseBlob = try blob("start\n")
        let base = try repo.commit(
            tree: try tree(baseBlob), parents: [],
            author: .test, message: "base",
            updatingRef: "HEAD"
        )

        let sharedBlob = try blob("shared-change\n")
        let sharedTree = try tree(sharedBlob)

        // main: base → sharedTree
        let mainTip = try repo.commit(
            tree: sharedTree, parents: [base],
            author: .test, message: "shared change on main",
            updatingRef: "refs/heads/main"
        )

        try repo.setHead(referenceName: "refs/heads/main")

        // feature branches off base and makes the same change under a
        // different message/author time — the tree is identical, so the
        // commit is "already applied".
        let featureTip = try repo.commit(
            tree: sharedTree, parents: [base],
            author: .test, message: "same shared change on feature",
            updatingRef: "refs/heads/feature"
        )

        try repo.setHead(referenceName: "refs/heads/feature")

        return (TestFixture(repositoryURL: directory), featureTip.oid, mainTip.oid)
    }
}
