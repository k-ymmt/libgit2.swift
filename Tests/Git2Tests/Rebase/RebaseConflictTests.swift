import Testing
import Foundation
@testable import Git2
import Cgit2

// Empirical: libgit2 1.9.x raises:
// - GIT_EUNMERGED (mapped to .unmerged) from git_rebase_commit when
//   the index has conflicts from the most recent git_rebase_next.
// - GIT_EAPPLIED (mapped to .applied) from git_rebase_commit when the
//   commit's tree matches the parent's tree after rebase.
// Confirm both during Task 11 implementation.
extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RebaseConflictTests {
        @Test
        func commit_onConflictingIndex_throwsUnmerged() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, upstreamOID) = try TestFixture.makeConflictingRebase(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)
                _ = try rebase.next()

                let index = try repo.index()
                #expect(index.hasConflicts == true)

                do {
                    _ = try rebase.commit(committer: .test)
                    Issue.record("expected commit to throw on conflicting index")
                } catch let e as GitError {
                    #expect(e.code == .unmerged)
                }
                _ = rebase
            }
        }

        @Test
        func commit_onAlreadyApplied_throwsApplied() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, upstreamOID) = try TestFixture.makeAlreadyApplied(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)
                _ = try rebase.next()

                do {
                    _ = try rebase.commit(committer: .test)
                    Issue.record("expected commit to throw on already-applied patch")
                } catch let e as GitError {
                    #expect(e.code == .applied)
                }
                _ = rebase
            }
        }
    }
}
