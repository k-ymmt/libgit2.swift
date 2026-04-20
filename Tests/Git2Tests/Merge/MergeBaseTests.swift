import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct MergeBaseTests {
        @Test
        func linearHistory_baseIsAncestor() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "A\n", author: .test),
                        (message: "B\n", author: .test),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let headTarget = try repo.head().target
                let headCommit = try repo.commit(for: headTarget)
                let commits = Array(try repo.log(from: headCommit))
                let a = commits.last!.oid
                let b = commits.first!.oid

                let base = try repo.mergeBase(of: a, and: b)
                #expect(base == a)
            }
        }

        @Test
        func divergedBranches_baseIsCommonAncestor() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, oursOID, theirsOID) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)

                let base = try repo.mergeBase(of: oursOID, and: theirsOID)
                let oursCommit = try repo.commit(for: oursOID)
                let theirsCommit = try repo.commit(for: theirsOID)
                let oursParent = try oursCommit.parents().first!.oid
                let theirsParent = try theirsCommit.parents().first!.oid
                #expect(base == oursParent)
                #expect(base == theirsParent)
            }
        }

        @Test
        func unrelatedHistories_throwsNotFound() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)

                let a = try repo.createBlob(data: Data("A".utf8))
                let b = try repo.createBlob(data: Data("B".utf8))
                let treeA = try repo.tree(entries: [.init(name: "x", oid: a, filemode: .blob)])
                let treeB = try repo.tree(entries: [.init(name: "x", oid: b, filemode: .blob)])
                let cA = try repo.commit(tree: treeA, parents: [], author: .test, message: "A", updatingRef: "refs/heads/a")
                let cB = try repo.commit(tree: treeB, parents: [], author: .test, message: "B", updatingRef: "refs/heads/b")

                do {
                    _ = try repo.mergeBase(of: cA.oid, and: cB.oid)
                    Issue.record("expected throw for unrelated histories")
                } catch let e as GitError {
                    // Empirical: libgit2 1.9.x returns GIT_ENOTFOUND.
                    #expect(e.code == .notFound)
                }
            }
        }
    }
}
