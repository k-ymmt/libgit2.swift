extension Repository {
    /// Configuration for ``Remote/push(refspecs:options:)`` and
    /// ``Repository/push(remoteNamed:refspecs:options:)``.
    ///
    /// Closure fields are invoked **synchronously on the push thread while
    /// the repository lock is held**. Do not call other ``Repository`` APIs
    /// from inside these closures — the `HandleLock`'s `os_unfair_lock` is
    /// not recursive and will deadlock. Dispatch UI updates to the main
    /// actor asynchronously (e.g. `Task { @MainActor in ... }`).
    public struct PushOptions: Sendable {
        public typealias CredentialsHandler      = FetchOptions.CredentialsHandler
        public typealias CertificateCheckHandler = FetchOptions.CertificateCheckHandler

        /// Invoked repeatedly during pack upload.
        /// - Parameters:
        ///   - current: Objects packed and sent so far.
        ///   - total: Total objects the pack will contain.
        ///   - bytes: Cumulative bytes sent over the wire.
        /// - Returns: `true` to continue, `false` to cancel. On cancel,
        ///   the enclosing `push` throws ``GitError/Code/user`` /
        ///   ``GitError/Class/callback``.
        /// - Important: Runs synchronously on the push thread with the
        ///   repository lock held. Do **not** call `repository.*` from
        ///   inside — doing so deadlocks on `os_unfair_lock`. Dispatch UI
        ///   updates via `Task { @MainActor in ... }` rather than synchronous
        ///   main-actor calls.
        public typealias PushTransferProgressHandler =
            @Sendable (_ current: Int, _ total: Int, _ bytes: Int) -> Bool

        /// Invoked once per ref after the server responds.
        /// - Parameters:
        ///   - refname: The ref the push targeted on the remote.
        ///   - status: `nil` means the server accepted the update.
        ///     Non-`nil` is the server-supplied rejection reason
        ///     (e.g. `"non-fast-forward"`).
        /// - Important: Same re-entrancy rules as `PushTransferProgressHandler`.
        public typealias PushUpdateReferenceHandler =
            @Sendable (_ refname: String, _ status: String?) -> Void

        public var credentials:          CredentialsHandler?
        public var certificateCheck:     CertificateCheckHandler?
        public var pushTransferProgress: PushTransferProgressHandler?
        public var pushUpdateReference:  PushUpdateReferenceHandler?

        /// HTTP redirect policy. Default ``FetchOptions/RedirectPolicy/initial``
        /// matches git's default.
        public var followRedirects: FetchOptions.RedirectPolicy = .initial

        /// Extra HTTP headers sent with every request on this push.
        public var customHeaders: [String] = []

        public init() {}
    }
}
