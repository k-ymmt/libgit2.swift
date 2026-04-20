import Testing
import Foundation
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct CheckoutIndexTests {
        @Test
        func repositoryCheckoutIndex_materializesIndexToWorkdir() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "hello\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                let file = dir.appendingPathComponent("README.md")
                // makeLinearHistory writes tree+commit to the ODB but leaves
                // the index empty. Materialize README.md on disk and stage it
                // so checkoutIndex has something to restore.
                try Data("hello\n".utf8).write(to: file)
                let index = try repo.index()
                try index.addPath("README.md")
                try index.save()

                try FileManager.default.removeItem(at: file)

                try repo.checkoutIndex(
                    nil,
                    options: Repository.CheckoutOptions(strategy: [.force])
                )

                #expect(FileManager.default.fileExists(atPath: file.path))
                let content = try String(contentsOf: file, encoding: .utf8)
                #expect(content == "hello\n")
            }
        }

        @Test
        func indexCheckout_matchesRepositoryCheckoutIndex() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "hello\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                let file = dir.appendingPathComponent("README.md")
                // makeLinearHistory writes tree+commit to the ODB but leaves
                // the index empty. Materialize README.md on disk and stage it
                // so checkoutIndex has something to restore.
                try Data("hello\n".utf8).write(to: file)
                let index = try repo.index()
                try index.addPath("README.md")
                try index.save()

                try FileManager.default.removeItem(at: file)

                try index.checkout(
                    options: Repository.CheckoutOptions(strategy: [.force])
                )

                let content = try String(contentsOf: file, encoding: .utf8)
                #expect(content == "hello\n")
            }
        }

        @Test
        func newStagedFileAppearsInWorkdir() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: [(message: "hello\n", author: .test)],
                    in: dir
                )
                let repo = try Repository.open(at: fixture.repositoryURL)

                // Stage a new file; then delete from workdir; checkout restores it.
                let extra = dir.appendingPathComponent("extra.txt")
                try Data("EXTRA\n".utf8).write(to: extra)

                let index = try repo.index()
                try index.addPath("extra.txt")
                try index.save()

                try FileManager.default.removeItem(at: extra)

                try index.checkout(
                    options: Repository.CheckoutOptions(strategy: [.force])
                )

                let content = try String(contentsOf: extra, encoding: .utf8)
                #expect(content == "EXTRA\n")
            }
        }
    }
}
