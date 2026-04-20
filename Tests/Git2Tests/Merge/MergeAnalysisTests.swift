import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct MergeAnalysisTests {
        @Test
        func upToDate_whenHeadEqualsTarget() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let ac = try repo.annotatedCommit(for: head)

                let (analysis, _) = try repo.mergeAnalysis(against: [ac])
                #expect(analysis.contains(.upToDate))
            }
        }

        @Test
        func fastForward_whenBranchIsAhead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, aheadOID) = try TestFixture.makeFastForwardable(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                let ac = try repo.annotatedCommit(for: aheadOID)

                let (analysis, _) = try repo.mergeAnalysis(against: [ac])
                #expect(analysis.contains(.fastForward))
            }
        }

        @Test
        func normal_whenBranchesHaveDiverged() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, theirsOID) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                let ac = try repo.annotatedCommit(for: theirsOID)

                let (analysis, _) = try repo.mergeAnalysis(against: [ac])
                #expect(analysis.contains(.normal))
                #expect(!analysis.contains(.fastForward))
            }
        }

        @Test
        func unborn_whenHeadIsUnborn() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                // Create a branch with one commit that HEAD does not point at.
                let b = try repo.createBlob(data: Data("x".utf8))
                let t = try repo.tree(entries: [.init(name: "f.txt", oid: b, filemode: .blob)])
                let c = try repo.commit(
                    tree: t, parents: [],
                    author: .test, message: "x",
                    updatingRef: "refs/heads/side"
                )
                // HEAD still points at refs/heads/main (unborn — default branch
                // has no commits).
                guard let ref = try repo.reference(named: "refs/heads/side") else {
                    Issue.record("expected refs/heads/side to exist")
                    return
                }
                let ac = try repo.annotatedCommit(for: ref)

                let (analysis, _) = try repo.mergeAnalysis(against: [ac])
                #expect(analysis.contains(.unborn))
                _ = c // silence unused warning
            }
        }
    }
}
