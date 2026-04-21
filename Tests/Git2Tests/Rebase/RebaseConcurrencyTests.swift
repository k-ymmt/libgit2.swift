import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RebaseConcurrencyTests {
        @Test
        func parallelMetadataReads_doNotCrash() async throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try await withTemporaryDirectoryAsync { dir in
                let (fx, _, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1, featureAhead: 3, in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)

                await withTaskGroup(of: Int.self) { group in
                    for _ in 0..<32 {
                        group.addTask {
                            var sum = 0
                            for _ in 0..<100 {
                                sum &+= rebase.operationCount
                                sum &+= rebase.currentOperationIndex ?? -1
                            }
                            return sum
                        }
                    }
                    var total = 0
                    for await partial in group {
                        total &+= partial
                    }
                    // 32 tasks * 100 iters — exact value is unimportant;
                    // what matters is no crash/race.
                    _ = total
                }
                _ = rebase
            }
        }
    }
}
