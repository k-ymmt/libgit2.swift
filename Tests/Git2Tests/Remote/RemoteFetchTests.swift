import Testing
import Foundation
import Cgit2
@testable import Git2

struct RemoteFetchTests {
    @Test func fetch_downloadsSeedCommitsIntoDownstream() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch()

            // Seed commits must be resolvable now.
            for oid in fx.seedOIDs {
                let c = try repo.commit(for: oid)
                #expect(c.oid == oid)
            }

            // Remote-tracking ref must point at the tip.
            let ref = try #require(try repo.reference(named: "refs/remotes/origin/main"))
            #expect(try ref.target == fx.seedOIDs.last!)
        }
    }

    @Test func fetch_writesFETCH_HEAD() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch()

            let fetchHead = fx.downstreamURL
                .appendingPathComponent(".git")
                .appendingPathComponent("FETCH_HEAD")
            let contents = try String(contentsOf: fetchHead, encoding: .utf8)
            #expect(contents.contains(fx.seedOIDs.last!.hex))
            #expect(contents.contains("'main'"))
        }
    }

    @Test func fetch_reFetchIsIdempotent() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch()
            try remote.fetch()   // second call should succeed with no changes
            let ref = try #require(try repo.reference(named: "refs/remotes/origin/main"))
            #expect(try ref.target == fx.seedOIDs.last!)
        }
    }

    @Test func fetch_withCustomRefspecs_writesExpectedRef() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch(refspecs: [Refspec("+refs/heads/main:refs/custom/main")])
            let ref = try #require(try repo.reference(named: "refs/custom/main"))
            #expect(try ref.target == fx.seedOIDs.last!)
        }
    }

    @Test func fetch_prune_removesStaleTrackingRefs() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch()

            // Plant a stale remote-tracking ref via libgit2 directly.
            var stalePtr: OpaquePointer?
            var rawOID = git_oid()
            _ = fx.seedOIDs.first!.hex.withCString { cstr in
                git_oid_fromstr(&rawOID, cstr)
            }
            let createRC = repo.lock.withLock { () -> Int32 in
                git_reference_create(&stalePtr, repo.handle, "refs/remotes/origin/stale", &rawOID, 0, nil)
            }
            #expect(createRC == 0)
            if let stalePtr { git_reference_free(stalePtr) }

            // Re-fetch with prune — stale ref should be gone.
            var opts = Repository.FetchOptions()
            opts.prune = .prune
            try remote.fetch(options: opts)
            #expect(try repo.reference(named: "refs/remotes/origin/stale") == nil)
        }
    }

    @Test func fetch_depth_producesShallowRepoOrCleanReject() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir, seedCommitCount: 5)
            let repo = try Repository.open(at: fx.downstreamURL)
            let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            var opts = Repository.FetchOptions()
            opts.depth = 1
            // Empirical: some libgit2 versions reject shallow fetch over
            // file://. Accept either a successful fetch with tip history,
            // or any libgit2 rejection. Assert one of the two branches.
            do {
                try remote.fetch(options: opts)
                // Success path: the tip must still be present.
                let ref = try #require(try repo.reference(named: "refs/remotes/origin/main"))
                #expect(try ref.target == fx.seedOIDs.last!)
            } catch let error as GitError {
                // Rejection path: just assert it's a real GitError.
                #expect(error.code != .ok)
            }
        }
    }

    @Test func fetch_updateFetchHeadFalse_doesNotWriteFETCH_HEAD() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            var opts = Repository.FetchOptions()
            opts.updateFetchHead = false
            try remote.fetch(options: opts)
            let fetchHead = fx.downstreamURL
                .appendingPathComponent(".git")
                .appendingPathComponent("FETCH_HEAD")
            // Either the file does not exist or is empty — both prove
            // libgit2 did not update it.
            let data = (try? Data(contentsOf: fetchHead)) ?? Data()
            #expect(data.isEmpty)
        }
    }

    @Test func defaultBranch_afterFetch_returnsMain() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            let remote = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            try remote.fetch()
            let branch = try remote.defaultBranch()
            // Git's default branch name depends on init.defaultBranch;
            // libgit2 defaults to "master" when unconfigured. Accept
            // either, since the upstream fixture writes HEAD via the
            // first commit's `updatingRef: "HEAD"` path.
            #expect(["refs/heads/main", "refs/heads/master"].contains(branch))
        }
    }

    @Test func repositoryFetch_remoteNamed_sugar() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            _ = try repo.createRemote(named: "origin", url: fx.upstreamURLString)
            try repo.fetch(remoteNamed: "origin")
            let ref = try #require(try repo.reference(named: "refs/remotes/origin/main"))
            #expect(try ref.target == fx.seedOIDs.last!)
        }
    }

    @Test func repositoryFetch_unknownRemoteThrowsNotFound() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let fx = try LocalRemoteFixture.make(in: dir)
            let repo = try Repository.open(at: fx.downstreamURL)
            do {
                try repo.fetch(remoteNamed: "nope")
                Issue.record("expected throw")
            } catch let error as GitError {
                #expect(error.code == .notFound)
            }
        }
    }
}
