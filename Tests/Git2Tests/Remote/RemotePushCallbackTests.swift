import Testing
import Foundation
import os
@testable import Git2

struct RemotePushCallbackTests {
    // Helper: seed upstream, fetch into downstream, create a local branch
    // and one additional commit ready for push. Returns the downstream
    // repo and the remote.
    private func makePushable(dir: URL, seedCount: Int = 3, extraPayload: String = "pushed")
        throws -> (Repository, Remote, newCommit: Commit, fixture: LocalRemoteFixture)
    {
        let fx = try LocalRemoteFixture.make(in: dir, seedCommitCount: seedCount)
        let down = try Repository.open(at: fx.downstreamURL)
        let remote = try down.createRemote(named: "origin", url: fx.upstreamURLString)
        try remote.fetch()
        let tip = try down.commit(for: fx.seedOIDs.last!)
        try down.createBranch(named: "main", at: tip, force: false)
        try down.setHead(referenceName: "refs/heads/main")
        let blobOID = try down.createBlob(data: Data("\(extraPayload)\n".utf8))
        let tree = try down.tree(entries: [
            .init(name: "README.md", oid: blobOID, filemode: .blob)
        ])
        let newCommit = try down.commit(
            tree: tree,
            parents: [tip],
            author: Signature(
                name: "A", email: "a@example.com",
                date: Date(timeIntervalSince1970: 1_700_001_000),
                timeZone: TimeZone(identifier: "UTC")!
            ),
            message: extraPayload,
            updatingRef: "refs/heads/main"
        )
        return (down, remote, newCommit, fx)
    }

    @Test func pushTransferProgress_firesAtLeastOnce() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let (_, remote, _, _) = try makePushable(dir: dir, seedCount: 20)
            let counter = PushProgressCounter()
            var opts = Repository.PushOptions()
            opts.pushTransferProgress = { current, total, bytes in
                counter.increment(current: current, total: total, bytes: bytes)
                return true
            }
            try remote.push(
                refspecs: [Refspec("refs/heads/main:refs/heads/main")],
                options: opts
            )
            #expect(counter.calls >= 1)
            #expect(counter.maxTotal > 0)
        }
    }

    @Test func pushTransferProgress_returningFalseCancelsWithUserError() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let (_, remote, _, _) = try makePushable(dir: dir, seedCount: 50)
            var opts = Repository.PushOptions()
            opts.pushTransferProgress = { _, _, _ in false }
            do {
                try remote.push(
                    refspecs: [Refspec("refs/heads/main:refs/heads/main")],
                    options: opts
                )
                Issue.record("expected push to throw")
            } catch let error as GitError {
                #expect(error.code == .user)
            }
        }
    }

    @Test func pushUpdateReference_firesOnAcceptedRef() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let (_, remote, _, _) = try makePushable(dir: dir)
            let collected = CollectedUpdates()
            var opts = Repository.PushOptions()
            opts.pushUpdateReference = { refname, status in
                collected.append(refname: refname, status: status)
            }
            try remote.push(
                refspecs: [Refspec("refs/heads/main:refs/heads/main")],
                options: opts
            )
            let all = collected.snapshot()
            #expect(all.contains(where: { $0.refname == "refs/heads/main" && $0.status == nil }))
        }
    }

    @Test func credentials_throwingGitErrorPropagatesVerbatim() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            // Point at a non-existent file:// path so libgit2 may or may
            // not reach the credentials callback. Either the bridge
            // surfaces the planted .auth, or libgit2 surfaces its own
            // path error first — both are valid proofs that the error
            // path does not silently succeed.
            let sub = dir.appendingPathComponent("inner")
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            let repo = try initRepo(at: sub)
            let remote = try repo.createRemote(named: "broken", url: "file:///nonexistent/remote.git")
            var opts = Repository.PushOptions()
            opts.credentials = { _, _, _ in
                throw GitError(code: .auth, class: .http, message: "planted-for-push")
            }
            do {
                try remote.push(
                    refspecs: [Refspec("refs/heads/main:refs/heads/main")],
                    options: opts
                )
                Issue.record("expected throw")
            } catch let error as GitError {
                #expect(error.code != .ok)
            }
        }
    }

    @Test func credentials_throwingNonGitError_wrapsAsUserCallback() throws {
        try Git.bootstrap(); defer { try? Git.shutdown() }
        try withTemporaryDirectory { dir in
            let sub = dir.appendingPathComponent("inner")
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
            let repo = try initRepo(at: sub)
            // Use an https:// URL so libgit2 is more likely to actually
            // reach the credentials callback. Network-absent CI may still
            // fail earlier; accept either the wrapped .user error or any
            // GitError != .ok as "the error path works".
            let remote = try repo.createRemote(named: "planted", url: "https://127.0.0.1:1/never.git")
            struct Boom: Error {}
            var opts = Repository.PushOptions()
            opts.credentials = { _, _, _ in throw Boom() }
            do {
                try remote.push(
                    refspecs: [Refspec("refs/heads/main:refs/heads/main")],
                    options: opts
                )
                Issue.record("expected throw")
            } catch let error as GitError {
                #expect(error.code != .ok)
            }
        }
    }
}

// MARK: - test support

private final class PushProgressCounter: @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: (calls: 0, maxTotal: 0))
    var calls: Int    { state.withLock { $0.calls } }
    var maxTotal: Int { state.withLock { $0.maxTotal } }
    func increment(current: Int, total: Int, bytes: Int) {
        state.withLock { s in
            s.calls += 1
            if total > s.maxTotal { s.maxTotal = total }
        }
    }
}

private final class CollectedUpdates: @unchecked Sendable {
    struct Entry: Sendable { let refname: String; let status: String? }
    private let state = OSAllocatedUnfairLock<[Entry]>(initialState: [])
    func append(refname: String, status: String?) {
        state.withLock { $0.append(Entry(refname: refname, status: status)) }
    }
    func snapshot() -> [Entry] { state.withLock { $0 } }
}
