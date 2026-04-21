import Testing
import Foundation
@testable import Git2
import Cgit2

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
            var raw: OpaquePointer?
            let rc: Int32 = dir.withUnsafeFileSystemRepresentation { p in
                guard let p else { return -1 }
                return git_repository_init(&raw, p, 0)
            }
            #expect(rc == 0)
            git_repository_free(raw!)

            let repo = try Repository.open(at: dir)
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
            var raw: OpaquePointer?
            let rc: Int32 = dir.withUnsafeFileSystemRepresentation { p in
                guard let p else { return -1 }
                return git_repository_init(&raw, p, 0)
            }
            #expect(rc == 0)
            git_repository_free(raw!)

            let repo = try Repository.open(at: dir)
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
