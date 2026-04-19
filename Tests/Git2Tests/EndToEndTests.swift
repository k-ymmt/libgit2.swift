import Testing
import Foundation
@testable import Git2

// Exercises the entire public API from the spec's §8.5 usage sketch as a single
// integration test. Nested under the serialized `RuntimeSensitiveTests` root
// suite (declared in `Runtime/RuntimeSensitiveTests.swift`) because it calls
// `Git.bootstrap()` / `Git.shutdown()` and must not race with other runtime
// lifecycle tests.
extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct EndToEndTests {
        @Test
        func specUsageSketchWorksEndToEnd() throws {
            try Git.bootstrap()
            defer { try? Git.shutdown() }

            try withTemporaryDirectory { dir in
                let fixture = try TestFixture.makeLinearHistory(
                    commits: (0..<15).map { i in
                        (message: "commit \(i)", author: .test)
                    },
                    in: dir
                )

                let repo = try Repository.open(at: fixture.repositoryURL)
                let head = try repo.head()
                let tip = try head.resolveToCommit()

                let first10 = repo.log(from: tip).prefix(10).map(\.summary)
                #expect(first10.count == 10)
                #expect(first10.first == "commit 14")
                #expect(first10.last == "commit 5")
            }
        }
    }
}
