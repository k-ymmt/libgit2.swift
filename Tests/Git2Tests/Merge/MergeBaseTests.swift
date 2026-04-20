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

        @Test
        func among_threeOIDs_returnsOctopusBase() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)

                func commit(_ msg: String, parents: [Commit], ref: String) throws -> Commit {
                    let b = try repo.createBlob(data: Data(msg.utf8))
                    let t = try repo.tree(entries: [.init(name: "f.txt", oid: b, filemode: .blob)])
                    return try repo.commit(tree: t, parents: parents, author: .test, message: msg, updatingRef: ref)
                }

                let a   = try commit("A",   parents: [],    ref: "HEAD")
                let b   = try commit("B",   parents: [a],   ref: "HEAD")
                let c1  = try commit("C1",  parents: [b],   ref: "refs/heads/c1")
                let c2  = try commit("C2",  parents: [b],   ref: "refs/heads/c2")
                let c3  = try commit("C3",  parents: [b],   ref: "refs/heads/c3")

                let base = try repo.mergeBase(among: [c1.oid, c2.oid, c3.oid])
                #expect(base == b.oid)
            }
        }

        @Test
        func among_singleOID_throwsUnknown() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head().target

                do {
                    _ = try repo.mergeBase(among: [head])
                    Issue.record("expected throw for single OID")
                } catch let e as GitError {
                    // Empirical: libgit2 1.9.x returns GIT_ERROR (-1) for
                    // single-OID input ("at least two commits are required").
                    #expect(e.code == .unknown(-1))
                }
            }
        }

        @Test
        func among_emptyArrayThrows() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                do {
                    _ = try repo.mergeBase(among: [])
                    Issue.record("expected throw for empty OID list")
                } catch let e as GitError {
                    // Empirical: libgit2 1.9.x returns GIT_ERROR (-1) for empty oid list.
                    #expect(e.code == .unknown(-1))
                }
            }
        }
    }
}
