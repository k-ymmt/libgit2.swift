import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RebaseMetadataTests {
        @Test
        func operationCount_matchesFeatureCommits() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1, featureAhead: 3, in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)
                #expect(rebase.operationCount == 3)
                _ = rebase
            }
        }

        @Test
        func currentOperationIndex_advancesThroughLoop() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1, featureAhead: 3, in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)

                // Before the first next(), the index is GIT_REBASE_NO_OPERATION.
                #expect(rebase.currentOperationIndex == nil)

                var seen: [Int] = []
                while let _ = try rebase.next() {
                    if let idx = rebase.currentOperationIndex {
                        seen.append(idx)
                    }
                    _ = try rebase.commit(committer: .test)
                }
                #expect(seen == [0, 1, 2])
                _ = rebase
            }
        }

        @Test
        func operationAtIndex_returnsPick_outOfBoundsReturnsNil() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1, featureAhead: 2, in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)

                let op0 = rebase.operation(at: 0)
                #expect(op0?.kind == .pick)

                let op99 = rebase.operation(at: 99)
                #expect(op99 == nil)
                _ = rebase
            }
        }

        @Test
        func origAndOntoNames_populated() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1, featureAhead: 1, in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                // Create annotated commit from the ref so provenance is recorded.
                guard let mainRef = try repo.reference(named: "refs/heads/main") else {
                    Issue.record("refs/heads/main missing")
                    return
                }
                let upstreamAC = try repo.annotatedCommit(for: mainRef)
                let rebase = try repo.startRebase(upstream: upstreamAC)

                // Empirical: libgit2 records `origHeadName` as the full
                // canonical ref path ("refs/heads/feature") but strips
                // "refs/heads/" from `ontoName` when the upstream is a local
                // branch (see `rebase_onto_name` in libgit2/src/libgit2/rebase.c).
                #expect(rebase.origHeadName == "refs/heads/feature")
                #expect(rebase.ontoName == "main")
                #expect(rebase.origHeadOid != nil)
                #expect(rebase.ontoOid == upstreamOID)
                _ = rebase
            }
        }

        @Test
        func origHeadName_isNil_whenDetached() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, featureOID, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1, featureAhead: 1, in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                // Detach HEAD at feature's tip so the rebase has no branch
                // ref to record as its "orig" side.
                try repo.setHead(detachedAt: featureOID)
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)

                // With HEAD detached at start, origHeadName should be empty
                // → Swift translates to nil.
                #expect(rebase.origHeadName == nil)
                #expect(rebase.origHeadOid == featureOID)
                _ = rebase
            }
        }
    }
}
