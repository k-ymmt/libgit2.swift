import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct ReadConcurrencyTests {
        @Test
        func parallelReadsAcrossNewSurfacesDoNotRaceOrCrash() async throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            let (repo, treeOID, headCommit) = try withTemporaryDirectory { dir in
                let made = try TestFixture.makeCommitWithTree(
                    entries: [
                        .init(path: "a.txt", content: "a",   mode: GIT_FILEMODE_BLOB),
                        .init(path: "b.txt", content: "bb",  mode: GIT_FILEMODE_BLOB),
                        .init(path: "run",   content: "#!",  mode: GIT_FILEMODE_BLOB_EXECUTABLE),
                    ],
                    in: dir
                )
                let repo = try Repository.open(at: made.fixture.repositoryURL)
                let treeOID = OID(raw: made.treeOID)
                let headCommit = try repo.head().resolveToCommit()
                return (repo, treeOID, headCommit)
            }

            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<32 {
                    group.addTask {
                        // Object lookup.
                        _ = try repo.object(for: treeOID)

                        // Tree subscript.
                        if case .tree(let tree) = try repo.object(for: treeOID) {
                            #expect(tree.count == 3)
                            _ = tree[0]
                            _ = tree[name: "a.txt"]
                        }

                        // RevWalk via log(from:).
                        for c in repo.log(from: headCommit) {
                            _ = c.summary
                        }

                        // Diff nil -> tree.
                        if case .tree(let tree) = try repo.object(for: treeOID) {
                            let diff = try repo.diff(from: nil, to: tree)
                            for i in 0..<diff.count {
                                _ = diff[i].status
                            }
                        }

                        // References iterator.
                        for ref in repo.references() {
                            _ = ref.name
                        }
                    }
                }
                try await group.waitForAll()
            }
        }
    }
}
