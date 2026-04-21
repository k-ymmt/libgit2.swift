import Testing
@testable import Git2
import Cgit2

struct CredentialTests {
    @Test func userPass_holdsComponents() {
        let c = Credential.userPass(username: "u", password: "p")
        guard case let .userPass(user, pass) = c else {
            Issue.record("expected .userPass, got \(c)"); return
        }
        #expect(user == "u")
        #expect(pass == "p")
    }

    @Test func allowedTypes_userpassPlaintextRaw() {
        #expect(Credential.AllowedTypes.userpassPlaintext.rawValue == 1 << 0)
    }

    @Test func allowedTypes_defaultRaw() {
        #expect(Credential.AllowedTypes.default.rawValue == 1 << 3)
    }

    @Test func allowedTypes_usernameRaw() {
        #expect(Credential.AllowedTypes.username.rawValue == 1 << 5)
    }

    @Test func allowedTypes_matchesLibgit2Constants() {
        #expect(Credential.AllowedTypes.userpassPlaintext.rawValue == GIT_CREDENTIAL_USERPASS_PLAINTEXT.rawValue)
        #expect(Credential.AllowedTypes.default.rawValue          == GIT_CREDENTIAL_DEFAULT.rawValue)
        #expect(Credential.AllowedTypes.username.rawValue         == GIT_CREDENTIAL_USERNAME.rawValue)
    }

    @Test func allowedTypes_unionWorks() {
        let u: Credential.AllowedTypes = [.userpassPlaintext, .username]
        #expect(u.contains(.userpassPlaintext))
        #expect(u.contains(.username))
        #expect(!u.contains(.default))
    }

    @Test func createGitCredential_userPassSucceeds() throws {
        try Git.bootstrap()
        defer { try? Git.shutdown() }
        var out: OpaquePointer? = nil
        let rc = Credential.userPass(username: "u", password: "p").createGitCredential(out: &out)
        #expect(rc == 0)
        #expect(out != nil)
        if let out {
            git_credential_free(UnsafeMutablePointer<git_credential>(out))
        }
    }

    @Test func createGitCredential_defaultSucceeds() throws {
        try Git.bootstrap()
        defer { try? Git.shutdown() }
        var out: OpaquePointer? = nil
        let rc = Credential.default.createGitCredential(out: &out)
        #expect(rc == 0)
        #expect(out != nil)
        if let out {
            git_credential_free(UnsafeMutablePointer<git_credential>(out))
        }
    }

    @Test func createGitCredential_usernameSucceeds() throws {
        try Git.bootstrap()
        defer { try? Git.shutdown() }
        var out: OpaquePointer? = nil
        let rc = Credential.username("u").createGitCredential(out: &out)
        #expect(rc == 0)
        #expect(out != nil)
        if let out {
            git_credential_free(UnsafeMutablePointer<git_credential>(out))
        }
    }
}
