import Testing
import Foundation
@testable import Git2
import Cgit2

// Empirical: when `inMemoryIndex()` is called on a non-inmemory rebase,
// libgit2 returns:
//   class   == .invalid             (NOT .rebase as initially seeded)
//   code    == .unknown(-1)         (generic GIT_ERROR = -1)
//   message == "invalid argument: 'rebase->index'"
// Observed during Task 10 implementation.
extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RebaseInMemoryTests {
        @Test
        func inMemory_doesNotMoveHead() throws {
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
                let rebase = try repo.startRebase(
                    upstream: upstreamAC,
                    options: .init(inMemory: true)
                )
                _ = try rebase.next()

                // HEAD should still point at feature tip; rebase state
                // should not be recorded on disk.
                let head = try repo.head()
                #expect(try head.target == featureOID)
                #expect(repo.state == .none)
                _ = rebase
            }
        }

        @Test
        func inMemoryIndex_returnsPostOperationIndex() throws {
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
                let rebase = try repo.startRebase(
                    upstream: upstreamAC,
                    options: .init(inMemory: true)
                )
                _ = try rebase.next()

                let index = try rebase.inMemoryIndex()
                #expect(index.hasConflicts == false)
                _ = rebase
            }
        }

        @Test
        func inMemoryIndex_onOnDiskRebase_throws() throws {
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
                _ = try rebase.next()

                do {
                    _ = try rebase.inMemoryIndex()
                    Issue.record("expected throw for on-disk rebase")
                } catch let e as GitError {
                    // Observed during Task 10 — libgit2 reports
                    // class == .invalid (not .rebase) when
                    // git_rebase_inmemory_index is called on an on-disk
                    // rebase, with a generic code (.unknown(-1)).
                    #expect(e.class == .invalid)
                    #expect(e.code == .unknown(-1))
                }
                _ = rebase
            }
        }
    }
}
