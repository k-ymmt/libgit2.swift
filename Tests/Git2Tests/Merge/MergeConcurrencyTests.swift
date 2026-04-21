import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct MergeConcurrencyTests {
        @Test
        func parallelMergeAnalysisCalls_serializeCleanly() async throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try await withTemporaryDirectoryAsync { dir in
                let (fx, _, theirsOID) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                let ac = try repo.annotatedCommit(for: theirsOID)

                // Fire many analysis calls in parallel; the point is that
                // none should crash or corrupt libgit2 state.
                await withTaskGroup(of: Void.self) { group in
                    for _ in 0 ..< 32 {
                        group.addTask {
                            _ = try? repo.mergeAnalysis(against: [ac])
                        }
                    }
                }

                // Sanity: a single call still succeeds afterward.
                let (analysis, _) = try repo.mergeAnalysis(against: [ac])
                #expect(analysis.contains(.normal))
            }
        }

        @Test
        func parallelCherrypickAndCleanup_serializesCleanly() async throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try await withTemporaryDirectoryAsync { dir in
                let (fx, _, theirsOID) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.checkoutHead(options: .init(strategy: [.force]))
                let theirs = try repo.commit(for: theirsOID)

                // Cherry-pick then clean up repeatedly under parallel
                // pressure — exercises git_cherrypick + git_repository_state
                // + git_repository_state_cleanup under the lock.
                await withTaskGroup(of: Void.self) { group in
                    for _ in 0 ..< 16 {
                        group.addTask {
                            _ = try? repo.cherrypick(theirs)
                            _ = try? repo.cleanupState()
                        }
                    }
                }

                // Sanity: should end in .none state.
                _ = try repo.cleanupState()
                #expect(repo.state == .none)
            }
        }
    }
}
