import Testing
@testable import Git2

@Test
func gitErrorEqualityIgnoresNothing() {
    let a = GitError(code: .notFound, class: .reference, message: "hi")
    let b = GitError(code: .notFound, class: .reference, message: "hi")
    let c = GitError(code: .notFound, class: .reference, message: "different")
    #expect(a == b)
    #expect(a != c)
}

@Test
func gitErrorDescriptionIncludesAllFields() {
    let e = GitError(code: .notFound, class: .reference, message: "no ref")
    #expect(e.description == "GitError(notFound, reference): no ref")
}

@Test
func gitErrorCodeUnknownIsDistinctPerRawValue() {
    #expect(GitError.Code.unknown(7) != GitError.Code.unknown(8))
    #expect(GitError.Code.unknown(7) == GitError.Code.unknown(7))
}
