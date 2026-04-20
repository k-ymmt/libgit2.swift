import Testing
import Foundation
@testable import Git2
import Cgit2

// Empirical: observed values from libgit2 1.9.x during Task 8 implementation:
// - git_rebase_finish after successful completion → 0 (no error).
// - git_rebase_abort on an active rebase → 0.
// - git_rebase_next after git_rebase_finish: returns GIT_ITEROVER, which we
//   translate to Optional.none — it does NOT throw. The rebase handle's
//   internal cursor already sits at end-of-operations, so another
//   `rebase_movenext` simply reports the iterator is exhausted.
// - git_rebase_abort after a successful abort: returns 0 — idempotent.
//   libgit2 recreates the HEAD ref to `orig_head_id` and re-runs
//   `git_reset --hard`. The .git/rebase-merge/ directory has already been
//   cleaned, but the in-memory `git_rebase` still holds `orig_head_id` /
//   `orig_head_name`, so a second abort completes without error.
// Consequence: the `secondCall_*` tests below assert the observed no-throw,
// no-error behavior instead of the originally-hypothesized throws.
extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RebaseFinishAbortTests {
        @Test
        func finish_returnsStateToNone_andMovesHeadToRebasedTip() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, featureOID, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1, featureAhead: 1, in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)

                var finalCommitOID: OID?
                while let _ = try rebase.next() {
                    finalCommitOID = try rebase.commit(committer: .test)
                }
                try rebase.finish()

                #expect(repo.state == .none)
                let head = try repo.head()
                let headTarget = try head.target
                #expect(head.name == "refs/heads/feature")
                #expect(headTarget == finalCommitOID)
                #expect(headTarget != featureOID)
                _ = rebase
            }
        }

        @Test
        func abort_restoresOriginalHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, featureOID, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1, featureAhead: 1, in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)
                _ = try rebase.next()
                try rebase.abort()

                #expect(repo.state == .none)
                let head = try repo.head()
                let headTarget = try head.target
                #expect(headTarget == featureOID)
                _ = rebase
            }
        }

        @Test
        func next_afterFinish_returnsNil() throws {
            // Empirical: libgit2 does NOT throw on `git_rebase_next` after
            // `git_rebase_finish`. The operation array iterator is already
            // at end, so it returns GIT_ITEROVER → we surface `nil`.
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1, featureAhead: 1, in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)
                while let _ = try rebase.next() {
                    _ = try rebase.commit(committer: .test)
                }
                try rebase.finish()

                let op = try rebase.next()
                #expect(op == nil)
                _ = rebase
            }
        }

        @Test
        func abort_afterAbort_isIdempotent() throws {
            // Empirical: libgit2 does NOT throw on `git_rebase_abort` after
            // a prior successful abort. The in-memory rebase struct still
            // holds `orig_head_id` / `orig_head_name`, so libgit2 simply
            // re-recreates HEAD and re-runs `git_reset --hard`, returning 0.
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, featureOID, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1, featureAhead: 1, in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)
                _ = try rebase.next()
                try rebase.abort()
                try rebase.abort()

                #expect(repo.state == .none)
                let head = try repo.head()
                let headTarget = try head.target
                #expect(headTarget == featureOID)
                _ = rebase
            }
        }
    }
}
