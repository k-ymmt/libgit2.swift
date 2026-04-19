import Testing
import Foundation
@testable import Git2
import Cgit2

@Test
func signatureCopiesFromLibgit2() throws {
    #expect(git_libgit2_init() >= 0)
    defer { _ = git_libgit2_shutdown() }

    var raw: UnsafeMutablePointer<git_signature>?
    defer { if let raw { git_signature_free(raw) } }
    let r = git_signature_new(&raw, "Alice", "alice@example.com", 1_700_000_000, 540) // +0900
    #expect(r == 0)
    let ptr = try #require(raw)

    let signature = Signature(copyingFrom: UnsafePointer(ptr))
    #expect(signature.name == "Alice")
    #expect(signature.email == "alice@example.com")
    #expect(signature.date == Date(timeIntervalSince1970: 1_700_000_000))
    #expect(signature.timeZone.secondsFromGMT() == 540 * 60) // +9h in seconds
}
