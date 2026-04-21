/// Result of a ``Repository/FetchOptions/CertificateCheckHandler``.
///
/// The handler is invoked by libgit2 after its default certificate
/// verification runs. The `isValid` parameter tells the handler whether
/// that default verification passed; the handler's return value tells
/// libgit2 what to do next.
public enum CertificateVerdict: Sendable, Equatable {
    /// Allow the connection regardless of the default verification
    /// outcome. Maps to libgit2 return `0`.
    case accept

    /// Refuse the connection. `Remote.fetch(...)` throws with the
    /// libgit2-reported error (typically ``GitError/Code/certificate``
    /// under class ``GitError/Class/callback``). Maps to libgit2
    /// return `-1`.
    case reject

    /// Fall back to libgit2 / SecureTransport default behavior as if
    /// no handler were installed. Maps to libgit2 return
    /// `GIT_PASSTHROUGH`.
    case passthrough
}
