import Cgit2

/// Credentials returned by a ``Repository/FetchOptions/CredentialsHandler``.
///
/// v0.5b-i ships HTTPS-facing cases only; SSH credentials are out of scope
/// while the XCFramework is built with `USE_SSH=OFF`.
public enum Credential: Sendable {
    /// Plain-text username and password. The typical HTTPS case —
    /// for GitHub, use `username: "x-access-token"` with a Personal
    /// Access Token as the password.
    case userPass(username: String, password: String)

    /// NTLM / Kerberos default-credentials. Mostly relevant on Windows
    /// domains; rarely useful on Apple platforms. Included for
    /// completeness.
    case `default`

    /// Username-only credential used during SSH pre-authentication when
    /// the transport does not know which user to authenticate as. Kept
    /// even though v0.5b-i is HTTPS-only because libgit2's
    /// `GIT_CREDENTIAL_USERNAME` bit can be requested on HTTPS as well
    /// (rare, but possible).
    case username(String)

    /// The libgit2 credential-type bitmask passed to the credentials
    /// callback. Only the HTTPS-relevant bits are exposed; SSH bits are
    /// deferred.
    public struct AllowedTypes: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        public static let userpassPlaintext = AllowedTypes(rawValue: 1 << 0)
        public static let `default`         = AllowedTypes(rawValue: 1 << 3)
        public static let username          = AllowedTypes(rawValue: 1 << 5)
    }
}

extension Credential {
    /// Allocates a `git_credential *` matching this case.
    ///
    /// libgit2 takes ownership of the allocated credential once the
    /// acquisition callback returns success; callers do not free it.
    ///
    /// - Parameter out: destination pointer slot (written on success).
    /// - Returns: zero on success, negative libgit2 error code on failure.
    internal func createGitCredential(out: UnsafeMutablePointer<OpaquePointer?>) -> Int32 {
        out.withMemoryRebound(to: UnsafeMutablePointer<git_credential>?.self, capacity: 1) { credOut in
            switch self {
            case let .userPass(username, password):
                return username.withCString { userPtr in
                    password.withCString { passPtr in
                        git_credential_userpass_plaintext_new(credOut, userPtr, passPtr)
                    }
                }
            case .default:
                return git_credential_default_new(credOut)
            case let .username(name):
                return name.withCString { namePtr in
                    git_credential_username_new(credOut, namePtr)
                }
            }
        }
    }
}
