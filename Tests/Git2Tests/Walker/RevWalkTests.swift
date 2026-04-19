import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct RevWalkTests {
        @Test
        func pushCommitWalksLinearHistory() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "first",  author: .test),
                        (message: "second", author: .test),
                        (message: "third",  author: .test),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tip = try repo.head().resolveToCommit()

                let walk = try RevWalk(repository: repo)
                try walk.push(tip)

                var summaries: [String] = []
                while let commit = try walk.next() {
                    summaries.append(commit.summary)
                }
                #expect(summaries == ["third", "second", "first"])
            }
        }

        @Test
        func pushByOidMatchesPushByCommit() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "a", author: .test),
                        (message: "b", author: .test),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tip = try repo.head().resolveToCommit()

                let walkByOID = try RevWalk(repository: repo)
                try walkByOID.push(oid: tip.oid)
                var oids: [OID] = []
                while let c = try walkByOID.next() { oids.append(c.oid) }
                #expect(oids.count == 2)
            }
        }

        @Test
        func pushByRefNameWorks() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "only", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()

                let walk = try RevWalk(repository: repo)
                try walk.push(refName: head.name)
                var n = 0
                while try walk.next() != nil { n += 1 }
                #expect(n == 1)
            }
        }

        @Test
        func pushHeadWalksFromCurrentHead() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [
                        (message: "a", author: .test),
                        (message: "b", author: .test),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                let walk = try RevWalk(repository: repo)
                try walk.pushHead()
                var n = 0
                while try walk.next() != nil { n += 1 }
                #expect(n == 2)
            }
        }

        // MARK: - hidePrunesSubgraph is deferred until Task 10 adds
        //         Repository.reference(named:). Re-enable at that point.
        // @Test
        // func hidePrunesSubgraph() throws { ... }

        @Test
        func simplifyFirstParentFollowsMainLineOnly() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeMergeHistory(in: dir)
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tip = try repo.head().resolveToCommit()

                let walk = try RevWalk(repository: repo)
                try walk.push(tip)
                try walk.simplifyFirstParent()

                var summaries: [String] = []
                while let c = try walk.next() { summaries.append(c.summary) }
                // Main line is A <- B <- D. C is off the first-parent chain.
                #expect(summaries == ["D (merge)", "B", "A"])
            }
        }

        @Test
        func resetClearsPushed() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "only", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)
                let tip = try repo.head().resolveToCommit()

                let walk = try RevWalk(repository: repo)
                try walk.push(tip)
                _ = try walk.next()
                walk.reset()
                #expect(try walk.next() == nil)
            }
        }
    }
}
