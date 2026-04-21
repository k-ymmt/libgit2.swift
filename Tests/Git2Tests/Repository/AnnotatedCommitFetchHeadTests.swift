import Testing
import Foundation
@testable import Git2

struct AnnotatedCommitFetchHeadTests {
    @Test func annotatedCommit_fromFetchHead_carriesOID() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            _ = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            try repo.fetch(remoteNamed: "origin")

            let ac = try repo.annotatedCommit(
                fromFetchHead: "main",
                remoteURL: fx.upstreamURLString,
                oid: fx.seedOIDs.last!
            )
            #expect(ac.oid == fx.seedOIDs.last!)
        }
    }
}
