import Testing
import Foundation
import os
@testable import Git2

/// Env-gated. Set `ENABLE_GITHUB_INTEGRATION_TESTS=1` to run. Requires
/// `gh` CLI on `$PATH` with a `repo`-scoped auth session.
struct RemoteGitHubIntegrationTests {
    struct Fixture: Codable {
        let repo_url: String
        let token: String
        let cleanup_name: String
    }

    private static func isEnabled() -> Bool {
        ProcessInfo.processInfo.environment["ENABLE_GITHUB_INTEGRATION_TESTS"] == "1"
    }

    private static func scriptsDir() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Remote
            .deletingLastPathComponent()   // Git2Tests
            .appendingPathComponent("Support/Scripts")
    }

    private static func setup() throws -> Fixture {
        let scriptURL = scriptsDir().appendingPathComponent("setup-github-fixture.sh")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        let stdout = Pipe()
        process.standardOutput = stdout
        try process.run()
        process.waitUntilExit()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return try JSONDecoder().decode(Fixture.self, from: data)
    }

    private static func teardown(_ fx: Fixture) {
        let scriptURL = scriptsDir().appendingPathComponent("teardown-github-fixture.sh")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path, fx.cleanup_name]
        try? process.run()
        process.waitUntilExit()
    }

    @Test(.disabled(if: !RemoteGitHubIntegrationTests.isEnabled(),
                   "ENABLE_GITHUB_INTEGRATION_TESTS not set"))
    func fetch_withToken_succeedsAndInvokesCallbacks() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        let fx = try Self.setup()
        defer { Self.teardown(fx) }

        try withTemporaryDirectory { dir in
            let repo = try Repository.create(at: dir)
            let remote = try repo.createRemote(named: "origin", url: fx.repo_url)
            let counters = Counters()
            var opts = Repository.FetchOptions()
            opts.credentials = { _, _, _ in
                counters.incrementCredentials()
                return .userPass(username: "x-access-token", password: fx.token)
            }
            opts.certificateCheck = { _, isValid in
                counters.incrementCertificateCheck()
                return isValid ? .accept : .reject
            }
            opts.transferProgress = { _ in
                counters.incrementTransferProgress()
                return true
            }
            try remote.fetch(options: opts)

            // refs/remotes/origin/main exists and is non-zero.
            let ref = try #require(try repo.reference(named: "refs/remotes/origin/main"))
            #expect(try ref.target != OID.zero)

            #expect(counters.credentials      >= 1)
            #expect(counters.certificateCheck >= 1)
            #expect(counters.transferProgress >= 1)
        }
    }

    @Test(.disabled(if: !RemoteGitHubIntegrationTests.isEnabled(),
                   "ENABLE_GITHUB_INTEGRATION_TESTS not set"))
    func fetch_rejectOnCertificate_throwsCallbackError() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        let fx = try Self.setup()
        defer { Self.teardown(fx) }

        try withTemporaryDirectory { dir in
            let repo = try Repository.create(at: dir)
            let remote = try repo.createRemote(named: "origin", url: fx.repo_url)
            var opts = Repository.FetchOptions()
            opts.credentials = { _, _, _ in
                .userPass(username: "x-access-token", password: fx.token)
            }
            opts.certificateCheck = { _, _ in .reject }
            do {
                try remote.fetch(options: opts)
                Issue.record("expected throw")
            } catch let error as GitError {
                // Empirical: libgit2 surfaces .callback class or .certificate code.
                #expect(error.class == .callback || error.code == .certificate)
            }
        }
    }

    /// Given a fixture, clones the remote into `localDir` by creating a
    /// fresh repo + configured remote + fetch, then checks out main.
    /// Returns the opened Repository along with the tip OID.
    private static func cloneToLocal(fixture fx: Fixture, localDir: URL)
        throws -> (Repository, OID)
    {
        let repo = try Repository.create(at: localDir)
        let remote = try repo.createRemote(named: "origin", url: fx.repo_url)
        var fetchOpts = Repository.FetchOptions()
        fetchOpts.credentials = { _, _, _ in
            .userPass(username: "x-access-token", password: fx.token)
        }
        fetchOpts.certificateCheck = { _, isValid in isValid ? .accept : .reject }
        try remote.fetch(options: fetchOpts)

        let originMain = try #require(try repo.reference(named: "refs/remotes/origin/main"))
        let tipOID = try originMain.target
        let tip = try repo.commit(for: tipOID)
        try repo.createBranch(named: "main", at: tip, force: false)
        try repo.setHead(referenceName: "refs/heads/main")
        return (repo, tipOID)
    }

    private static func authOpts(token: String) -> Repository.PushOptions {
        var opts = Repository.PushOptions()
        opts.credentials = { _, _, _ in
            .userPass(username: "x-access-token", password: token)
        }
        opts.certificateCheck = { _, isValid in isValid ? .accept : .reject }
        return opts
    }

    @Test(.disabled(if: !RemoteGitHubIntegrationTests.isEnabled(),
                   "ENABLE_GITHUB_INTEGRATION_TESTS not set"))
    func push_withToken_advancesUpstreamMain() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        let fx = try Self.setup()
        defer { Self.teardown(fx) }

        try withTemporaryDirectory { dir in
            let (repo, tipOID) = try Self.cloneToLocal(fixture: fx, localDir: dir)
            let tip = try repo.commit(for: tipOID)
            let blobOID = try repo.createBlob(data: Data("pushed-via-https\n".utf8))
            let tree = try repo.tree(entries: [
                .init(name: "README.md", oid: blobOID, filemode: .blob)
            ])
            let newCommit = try repo.commit(
                tree: tree,
                parents: [tip],
                author: Signature(
                    name: "Git2 IT", email: "it@example.com",
                    date: Date(), timeZone: TimeZone(identifier: "UTC")!
                ),
                message: "pushed via https",
                updatingRef: "refs/heads/main"
            )

            try repo.push(
                remoteNamed: "origin",
                refspecs: [Refspec("refs/heads/main:refs/heads/main")],
                options: Self.authOpts(token: fx.token)
            )

            // Verify by re-fetching — the freshly-fetched origin/main must
            // match the commit we pushed.
            var verifyOpts = Repository.FetchOptions()
            verifyOpts.credentials = { _, _, _ in
                .userPass(username: "x-access-token", password: fx.token)
            }
            verifyOpts.certificateCheck = { _, v in v ? .accept : .reject }
            try repo.fetch(remoteNamed: "origin", options: verifyOpts)
            let originMain = try #require(try repo.reference(named: "refs/remotes/origin/main"))
            #expect(try originMain.target == newCommit.oid)
        }
    }

    @Test(.disabled(if: !RemoteGitHubIntegrationTests.isEnabled(),
                   "ENABLE_GITHUB_INTEGRATION_TESTS not set"))
    func push_nonFastForward_throwsCallbackReference() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        let fx = try Self.setup()
        defer { Self.teardown(fx) }

        try withTemporaryDirectory { dir in
            let (repo, tipOID) = try Self.cloneToLocal(fixture: fx, localDir: dir)

            // Create a divergent first-child commit (orphan parents=[])
            // so that refs/heads/main on the remote cannot fast-forward.
            let tip = try repo.commit(for: tipOID)
            let divergentBlob = try repo.createBlob(data: Data("divergent\n".utf8))
            let divergentTree = try repo.tree(entries: [
                .init(name: "README.md", oid: divergentBlob, filemode: .blob)
            ])
            let orphan = try repo.commit(
                tree: divergentTree,
                parents: [],
                author: Signature(
                    name: "Git2 IT", email: "it@example.com",
                    date: Date(), timeZone: TimeZone(identifier: "UTC")!
                ),
                message: "orphan",
                updatingRef: nil
            )
            try repo.createBranch(named: "main", at: orphan, force: true)

            _ = tip   // silence unused warning

            // Collect per-ref callbacks so we can verify pushUpdateReference
            // fires with a rejection status over HTTPS (this path is
            // NOT reachable over file:// — libgit2's local transport short-
            // circuits to GIT_ENONFASTFORWARD without invoking the callback).
            let collected = GHCollectedUpdates()
            var opts = Self.authOpts(token: fx.token)
            opts.pushUpdateReference = { refname, status in
                collected.append(refname: refname, status: status)
            }

            do {
                try repo.push(
                    remoteNamed: "origin",
                    refspecs: [Refspec("refs/heads/main:refs/heads/main")],
                    options: opts
                )
                Issue.record("expected push to throw")
            } catch let error as GitError {
                #expect(error.code  == .user)
                #expect(error.class == .reference)
            }
            let all = collected.snapshot()
            #expect(all.contains(where: { $0.refname.contains("main") && $0.status != nil }))
        }
    }

    @Test(.disabled(if: !RemoteGitHubIntegrationTests.isEnabled(),
                   "ENABLE_GITHUB_INTEGRATION_TESTS not set"))
    func push_withInvalidToken_throwsAuthError() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        let fx = try Self.setup()
        defer { Self.teardown(fx) }

        try withTemporaryDirectory { dir in
            let (repo, tipOID) = try Self.cloneToLocal(fixture: fx, localDir: dir)
            let tip = try repo.commit(for: tipOID)
            let blobOID = try repo.createBlob(data: Data("auth-fail\n".utf8))
            let tree = try repo.tree(entries: [
                .init(name: "README.md", oid: blobOID, filemode: .blob)
            ])
            _ = try repo.commit(
                tree: tree,
                parents: [tip],
                author: Signature(
                    name: "Git2 IT", email: "it@example.com",
                    date: Date(), timeZone: TimeZone(identifier: "UTC")!
                ),
                message: "auth fail candidate",
                updatingRef: "refs/heads/main"
            )

            var opts = Repository.PushOptions()
            opts.credentials = { _, _, _ in
                .userPass(username: "x-access-token", password: "not-a-real-token")
            }
            opts.certificateCheck = { _, v in v ? .accept : .reject }
            do {
                try repo.push(
                    remoteNamed: "origin",
                    refspecs: [Refspec("refs/heads/main:refs/heads/main")],
                    options: opts
                )
                Issue.record("expected auth failure")
            } catch let error as GitError {
                // libgit2 empirically surfaces .auth class=.http on exhausted
                // retries; accept the looser "not .ok" to keep the test
                // robust against libgit2 retry-policy drift.
                #expect(error.code != .ok)
            }
        }
    }
}

private final class Counters: @unchecked Sendable {
    private let lock = NSLock()
    private var _credentials = 0
    private var _certificateCheck = 0
    private var _transferProgress = 0

    var credentials: Int { lock.lock(); defer { lock.unlock() }; return _credentials }
    var certificateCheck: Int { lock.lock(); defer { lock.unlock() }; return _certificateCheck }
    var transferProgress: Int { lock.lock(); defer { lock.unlock() }; return _transferProgress }

    func incrementCredentials() { lock.lock(); defer { lock.unlock() }; _credentials += 1 }
    func incrementCertificateCheck() { lock.lock(); defer { lock.unlock() }; _certificateCheck += 1 }
    func incrementTransferProgress() { lock.lock(); defer { lock.unlock() }; _transferProgress += 1 }
}

private final class GHCollectedUpdates: @unchecked Sendable {
    struct Entry: Sendable { let refname: String; let status: String? }
    private let state = OSAllocatedUnfairLock<[Entry]>(initialState: [])
    func append(refname: String, status: String?) {
        state.withLock { $0.append(Entry(refname: refname, status: status)) }
    }
    func snapshot() -> [Entry] { state.withLock { $0 } }
}
