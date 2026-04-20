import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RebaseCommitTests {
        @Test
        func nextCommitLoop_producesRebasedTip() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, featureOID, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1,
                    featureAhead: 2,
                    in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)

                var newOids: [OID] = []
                while let _ = try rebase.next() {
                    let newOid = try rebase.commit(committer: .test)
                    newOids.append(newOid)
                }

                #expect(newOids.count == 2)
                // Each rebased commit's OID must differ from the source —
                // parent chain changed, so content hash changes.
                #expect(!newOids.contains(featureOID))
                _ = upstreamOID
                _ = rebase
            }
        }

        @Test
        func commit_preservesAuthor_whenAuthorIsNil() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, featureOID, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1,
                    featureAhead: 1,
                    in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let originalAuthor = try repo.commit(for: featureOID).author

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)
                _ = try rebase.next()
                let newOid = try rebase.commit(
                    author: nil,  // keep original
                    committer: .test
                )

                let rebased = try repo.commit(for: newOid)
                #expect(rebased.author.name == originalAuthor.name)
                #expect(rebased.author.email == originalAuthor.email)
                _ = rebase
            }
        }

        @Test
        func commit_preservesMessage_whenMessageIsNil() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, featureOID, upstreamOID) = try TestFixture.makeLinearRebase(
                    upstreamAhead: 1,
                    featureAhead: 1,
                    in: dir
                )
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.setHead(referenceName: "refs/heads/feature")
                try repo.checkoutHead(options: .init(strategy: [.force]))

                let originalMessage = try repo.commit(for: featureOID).message

                let upstreamAC = try repo.annotatedCommit(for: upstreamOID)
                let rebase = try repo.startRebase(upstream: upstreamAC)
                _ = try rebase.next()
                let newOid = try rebase.commit(
                    author: nil,
                    committer: .test,
                    message: nil       // keep original
                )

                let rebased = try repo.commit(for: newOid)
                #expect(rebased.message == originalMessage)
                _ = rebase
            }
        }
    }
}
