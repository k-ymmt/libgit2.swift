import Testing
@testable import Git2

@Test
func versionCurrentReturnsLibgit2Major1Minor9() {
    let v = Version.current
    #expect(v.major == 1)
    #expect(v.minor == 9)
    #expect(v.patch >= 0)
}

@Test
func versionDescription() {
    let v = Version(major: 1, minor: 9, patch: 3)
    #expect(v.description == "1.9.3")
}

@Test
func versionOrdering() {
    #expect(Version(major: 1, minor: 9, patch: 0) < Version(major: 1, minor: 9, patch: 1))
    #expect(Version(major: 1, minor: 8, patch: 9) < Version(major: 1, minor: 9, patch: 0))
    #expect(Version(major: 1, minor: 9, patch: 0) == Version(major: 1, minor: 9, patch: 0))
}
