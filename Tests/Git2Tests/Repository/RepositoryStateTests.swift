import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RepositoryStateTests {
        @Test
        func freshRepo_stateIsNone() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)
                #expect(repo.state == .none)
            }
        }

        @Test
        func afterMerge_stateIsMerge() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, _) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.checkoutHead(options: .init(strategy: [.force]))
                guard let theirs = try repo.reference(named: "refs/heads/theirs") else {
                    Issue.record("theirs ref missing"); return
                }
                _ = try repo.merge(theirs)
                #expect(repo.state == .merge)
            }
        }

        @Test
        func afterCherrypick_stateIsCherrypick() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let (fx, _, theirsOID) = try TestFixture.makeDivergedBranches(in: dir)
                let repo = try Repository.open(at: fx.repositoryURL)
                try repo.checkoutHead(options: .init(strategy: [.force]))
                let theirs = try repo.commit(for: theirsOID)
                try repo.cherrypick(theirs)
                #expect(repo.state == .cherrypick)
            }
        }
    }
}
