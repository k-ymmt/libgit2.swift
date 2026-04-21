extension Repository {
    /// Configuration for ``Remote/fetch(refspecs:options:reflogMessage:)`` and
    /// ``Repository/fetch(remoteNamed:refspecs:options:reflogMessage:)``.
    ///
    /// Closure fields are invoked **synchronously on the fetch thread while
    /// the repository lock is held**. Do not call other ``Repository`` APIs
    /// from inside these closures — the `HandleLock`'s `os_unfair_lock`
    /// is not recursive and will deadlock. Dispatch UI updates to the main
    /// actor asynchronously (e.g. `Task { @MainActor in ... }`).
    public struct FetchOptions: Sendable {
        /// Invoked when the remote requests authentication. The handler
        /// returns the ``Credential`` to try. libgit2 may invoke the
        /// handler more than once (e.g. after a rejected password). Throw
        /// from the handler to surface an authentication error to the
        /// caller of `fetch(...)`.
        public typealias CredentialsHandler = @Sendable (
            _ url: String,
            _ usernameFromURL: String?,
            _ allowed: Credential.AllowedTypes
        ) throws -> Credential

        /// Invoked after libgit2 / SecureTransport runs its default
        /// certificate validation. `isValid` reports the default
        /// verdict; the closure's ``CertificateVerdict`` return value
        /// overrides or defers to it.
        public typealias CertificateCheckHandler = @Sendable (
            _ host: String,
            _ isValid: Bool
        ) -> CertificateVerdict

        /// Invoked periodically during packfile download / indexing.
        /// Return `false` to cancel the fetch (surfaces as
        /// ``GitError/Code/user`` / ``GitError/Class/callback``).
        public typealias TransferProgressHandler = @Sendable (TransferProgress) -> Bool

        public var credentials:      CredentialsHandler?
        public var certificateCheck: CertificateCheckHandler?
        public var transferProgress: TransferProgressHandler?

        /// Whether to prune remote-tracking refs that no longer exist on
        /// the remote.
        public var prune: PruneSetting = .unspecified

        /// Whether to write `FETCH_HEAD` on fetch completion. Default `true`.
        public var updateFetchHead: Bool = true

        /// Tag-following behavior.
        public var downloadTags: AutotagOption = .unspecified

        /// Fetch depth. `0` = full history. Non-zero triggers shallow
        /// fetch; `Int.max` equivalent (`2147483647`) unshallows a
        /// shallow repository.
        public var depth: Int = 0

        /// HTTP redirect policy. Default ``RedirectPolicy/initial``
        /// matches git's default.
        public var followRedirects: RedirectPolicy = .initial

        /// Extra HTTP headers sent with every request on this fetch.
        public var customHeaders: [String] = []

        public init() {}

        public enum PruneSetting: Sendable, Hashable { case unspecified, prune, noPrune }
        public enum AutotagOption: Sendable, Hashable { case unspecified, auto, none, all }
        public enum RedirectPolicy: Sendable, Hashable { case none, initial, all }
    }
}
