import Testing
import Foundation
@testable import Git2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct IndexConcurrencyTests {
        @Test
        func parallelIndexOperationsDoNotRaceOrCrash() async throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try await withTemporaryDirectory { dir in
                let repo = try initRepo(at: dir)

                // Write 16 files to the working tree up front.
                for i in 0..<16 {
                    let url = dir.appendingPathComponent("f-\(i)")
                    try Data("payload-\(i)".utf8).write(to: url)
                }

                let index = try repo.index()

                try await withThrowingTaskGroup(of: Void.self) { group in
                    for i in 0..<16 {
                        group.addTask {
                            try index.addPath("f-\(i)")
                        }
                        group.addTask {
                            _ = index.entries
                        }
                    }
                    try await group.waitForAll()
                }

                try index.save()
                let snapshot = index.entries
                #expect(snapshot.count == 16)
            }
        }
    }
}

private func withTemporaryDirectory<T>(_ body: (URL) async throws -> T) async rethrows -> T {
    let base = URL.temporaryDirectory
        .appendingPathComponent("Git2Tests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }
    return try await body(base)
}
