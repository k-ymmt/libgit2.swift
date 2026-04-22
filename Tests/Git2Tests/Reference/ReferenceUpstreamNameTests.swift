import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct ReferenceUpstreamNameTests {
        @Test
        func upstreamName_onLocalBranchWithTracking_returnsRef() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fx = try LocalRemoteFixture.make(in: dir)
                let repo = try Repository.open(at: fx.downstreamURL)
                _ = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
                try repo.fetch(remoteNamed: "origin")

                // Create local 'main' tracking origin/main.
                let tipCommit = try repo.commit(for: fx.seedOIDs.last!)
                _ = try repo.createBranch(named: "main", at: tipCommit, force: false)

                // Write branch.main.remote / branch.main.merge.
                //
                // Direct Cgit2 use because the wrapper has no public
                // config-set API yet (v0.5c-ii does not add one; this
                // is test-only plumbing).
                var configPtr: OpaquePointer?
                try check(git_repository_config(&configPtr, repo.handle))
                defer { git_config_free(configPtr) }
                try check(git_config_set_string(configPtr, "branch.main.remote", "origin"))
                try check(git_config_set_string(configPtr, "branch.main.merge", "refs/heads/main"))

                let mainRef = try #require(try repo.reference(named: "refs/heads/main"))
                let upstream = try mainRef.upstreamName()
                #expect(upstream == "refs/remotes/origin/main")
            }
        }

        @Test
        func upstreamName_onLocalBranchWithoutTracking_returnsNil() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                // HEAD resolves to refs/heads/main (or whatever default);
                // no tracking config is set by the fixture.
                #expect(try head.upstreamName() == nil)
            }
        }

        @Test
        func upstreamName_onRemoteTrackingRef_returnsNil() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fx = try LocalRemoteFixture.make(in: dir)
                let repo = try Repository.open(at: fx.downstreamURL)
                _ = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
                try repo.fetch(remoteNamed: "origin")

                let trackingRef = try #require(
                    try repo.reference(named: "refs/remotes/origin/main")
                )
                #expect(try trackingRef.upstreamName() == nil)
            }
        }

        @Test
        func upstreamName_onTagRef_returnsNil() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let tipCommit = try head.resolveToCommit()
                _ = try repo.createLightweightTag(named: "v1", target: tipCommit, force: false)

                let tagRef = try #require(try repo.reference(named: "refs/tags/v1"))
                #expect(try tagRef.upstreamName() == nil)
            }
        }

        @Test
        func upstreamName_onDetachedHead_returnsNil() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "A\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tipOID = try repo.head().target
                try repo.setHead(detachedAt: tipOID)

                let head = try repo.head()
                #expect(try head.upstreamName() == nil)
            }
        }
    }
}
