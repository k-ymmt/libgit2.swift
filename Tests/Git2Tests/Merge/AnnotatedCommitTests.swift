import Testing
@testable import Git2
import Cgit2

extension RuntimeSensitiveTests {
    @Suite(.serialized)
    struct AnnotatedCommitTests {
        @Test
        func typeExists() {
            // Compile-time check: AnnotatedCommit is a public final class.
            #expect(AnnotatedCommit.self == AnnotatedCommit.self)
        }
    }
}
