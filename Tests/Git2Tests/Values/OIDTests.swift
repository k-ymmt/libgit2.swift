import Testing
@testable import Git2
import Cgit2

@Test
func oidRoundtripsHex() throws {
    #expect(git_libgit2_init() >= 0)
    defer { _ = git_libgit2_shutdown() }

    let hex = "0123456789abcdef0123456789abcdef01234567"
    let oid = try OID(hex: hex)
    #expect(oid.hex == hex)
    #expect(oid.description == hex)
}

@Test
func oidLengthIs20() {
    #expect(OID.length == 20)
}

@Test
func oidEqualityIsByValue() throws {
    #expect(git_libgit2_init() >= 0)
    defer { _ = git_libgit2_shutdown() }

    let a = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
    let b = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
    let c = try OID(hex: "fedcba9876543210fedcba9876543210fedcba98")
    #expect(a == b)
    #expect(a != c)
}

@Test
func oidIsHashable() throws {
    #expect(git_libgit2_init() >= 0)
    defer { _ = git_libgit2_shutdown() }

    let a = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
    let b = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
    var set = Set<OID>()
    set.insert(a)
    set.insert(b)
    #expect(set.count == 1)
}

@Test
func oidFromShortHexThrows() {
    #expect(git_libgit2_init() >= 0)
    defer { _ = git_libgit2_shutdown() }

    #expect(throws: GitError.self) {
        _ = try OID(hex: "deadbeef")
    }
}

@Test
func oidFromNonHexThrows() {
    #expect(git_libgit2_init() >= 0)
    defer { _ = git_libgit2_shutdown() }

    #expect(throws: GitError.self) {
        _ = try OID(hex: "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz")
    }
}
