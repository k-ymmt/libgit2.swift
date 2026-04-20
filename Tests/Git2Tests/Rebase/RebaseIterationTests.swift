import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RebaseIterationTests {
        @Test
        func next_returnsEveryPickThenNil() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1,
                    featureAhead: 2,
                    in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                // Note: OID overload — not via Commit (plan typo fixed).
                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                // Use inMemory for this test. On-disk rebase requires pairing
                // `next()` with `commit()` between iterations — otherwise
                // libgit2's `git_merge__check_result` sees the first pick's
                // file staged against HEAD and rejects the second `next()`
                // with "uncommitted change would be overwritten by merge".
                // That's the documented contract, not a quirk. T7's commit
                // test exercises the real next→commit loop on-disk; this
                // test only covers the iteration-terminator contract, so
                // inMemory isolates it cleanly.
                let rebase = try repo.startRebase(
                    upstream: upstreamAC,
                    options: .init(inMemory: true)
                )

                let op1 = try rebase.next()
                #expect(op1 != nil)
                #expect(op1?.kind == .pick)

                let op2 = try rebase.next()
                #expect(op2 != nil)
                #expect(op2?.kind == .pick)

                // After both feature commits are applied, next() returns nil.
                let op3 = try rebase.next()
                #expect(op3 == nil)

                _ = rebase
            }
        }
    }
}
