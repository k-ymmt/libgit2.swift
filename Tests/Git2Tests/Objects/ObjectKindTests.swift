import Testing
@testable import Git2
import Cgit2

// ObjectKind is a pure value type — no bootstrap required.
@Suite
struct ObjectKindTests {
    @Test
    func allKnownGitObjectTypesMap() {
        #expect(ObjectKind.from(GIT_OBJECT_COMMIT) == .commit)
        #expect(ObjectKind.from(GIT_OBJECT_TREE)   == .tree)
        #expect(ObjectKind.from(GIT_OBJECT_BLOB)   == .blob)
        #expect(ObjectKind.from(GIT_OBJECT_TAG)    == .tag)
    }

    @Test
    func unknownObjectTypesMapToNil() {
        #expect(ObjectKind.from(GIT_OBJECT_ANY)    == nil)
        #expect(ObjectKind.from(GIT_OBJECT_INVALID) == nil)
    }

    @Test
    func rawRoundtrips() {
        #expect(ObjectKind.commit.raw == GIT_OBJECT_COMMIT)
        #expect(ObjectKind.tree.raw   == GIT_OBJECT_TREE)
        #expect(ObjectKind.blob.raw   == GIT_OBJECT_BLOB)
        #expect(ObjectKind.tag.raw    == GIT_OBJECT_TAG)
    }
}
