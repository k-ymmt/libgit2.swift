import Cgit2

/// Per-fetch state that the C trampolines dispatch into.
///
/// One instance is created per `withRemoteCallbacks` call and kept alive
/// for the duration of the libgit2 operation via `withExtendedLifetime`.
/// The C trampolines receive a raw `payload` pointer that is cast back to
/// this object using an unretained `Unmanaged` reference — no ARC traffic
/// during the callback.
internal final class RemoteCallbackContext {
    let credentials:      Repository.FetchOptions.CredentialsHandler?
    let certificateCheck: Repository.FetchOptions.CertificateCheckHandler?
    let transferProgress: Repository.FetchOptions.TransferProgressHandler?
    /// Set by the credentials trampoline when the Swift handler throws.
    /// The fetch site inspects this after libgit2 returns an error.
    var capturedError:    (any Error)?

    init(_ options: Repository.FetchOptions) {
        self.credentials      = options.credentials
        self.certificateCheck = options.certificateCheck
        self.transferProgress = options.transferProgress
    }
}

/// Sets up a `git_remote_callbacks` struct, installs the trampolines only
/// for the handlers the caller provided in `options`, and invokes `body`.
///
/// The `RemoteCallbackContext` is passed to `body` so the call site can
/// inspect `capturedError` after libgit2 returns.
internal func withRemoteCallbacks<R>(
    _ options: Repository.FetchOptions,
    _ body: (UnsafeMutablePointer<git_remote_callbacks>, RemoteCallbackContext) throws(GitError) -> R
) throws(GitError) -> R {
    var cbs = git_remote_callbacks()
    let rc = git_remote_init_callbacks(&cbs, UInt32(GIT_REMOTE_CALLBACKS_VERSION))
    precondition(rc == 0, "git_remote_init_callbacks should never fail at version \(GIT_REMOTE_CALLBACKS_VERSION)")

    let ctx = RemoteCallbackContext(options)
    cbs.payload = Unmanaged.passUnretained(ctx).toOpaque()

    if options.credentials      != nil { cbs.credentials       = remoteBridge_credentials }
    if options.certificateCheck != nil { cbs.certificate_check = remoteBridge_certCheck }
    if options.transferProgress != nil { cbs.transfer_progress = remoteBridge_transfer }

    // `withExtendedLifetime` / `withUnsafeMutablePointer` use `rethrows`, which
    // cannot forward typed throws. Bridge through Result<R, GitError>.
    let result: Result<R, GitError> = withExtendedLifetime(ctx) {
        withUnsafeMutablePointer(to: &cbs) { cbsPtr in
            do throws(GitError) {
                return .success(try body(cbsPtr, ctx))
            } catch {
                return .failure(error)
            }
        }
    }
    return try result.get()
}

// MARK: - @convention(c) Trampolines
//
// These are free functions (not methods or closures) because C function
// pointers cannot capture Swift state. Context is threaded through the
// opaque `payload` field set by `withRemoteCallbacks`.

private func remoteBridge_credentials(
    out: UnsafeMutablePointer<UnsafeMutablePointer<git_credential>?>?,
    url: UnsafePointer<CChar>?,
    usernameFromURL: UnsafePointer<CChar>?,
    allowedTypes: UInt32,
    payload: UnsafeMutableRawPointer?
) -> Int32 {
    guard let payload, let out else { return -1 }
    let ctx = Unmanaged<RemoteCallbackContext>.fromOpaque(payload).takeUnretainedValue()
    guard let handler = ctx.credentials else { return Int32(GIT_PASSTHROUGH.rawValue) }
    do {
        let cred = try handler(
            url.map(String.init(cString:)) ?? "",
            usernameFromURL.map(String.init(cString:)),
            Credential.AllowedTypes(rawValue: allowedTypes)
        )
        // `createGitCredential` expects `UnsafeMutablePointer<OpaquePointer?>`.
        // Rebind through the memory since both pointer types have identical
        // ABI representation (both are pointer-sized).
        return out.withMemoryRebound(to: OpaquePointer?.self, capacity: 1) { opaqueOut in
            cred.createGitCredential(out: opaqueOut)
        }
    } catch {
        ctx.capturedError = error
        return Int32(GIT_EUSER.rawValue)
    }
}

private func remoteBridge_certCheck(
    cert: UnsafeMutablePointer<git_cert>?,
    valid: Int32,
    host: UnsafePointer<CChar>?,
    payload: UnsafeMutableRawPointer?
) -> Int32 {
    guard let payload else { return -1 }
    let ctx = Unmanaged<RemoteCallbackContext>.fromOpaque(payload).takeUnretainedValue()
    guard let handler = ctx.certificateCheck else { return Int32(GIT_PASSTHROUGH.rawValue) }
    let verdict = handler(
        host.map(String.init(cString:)) ?? "",
        valid != 0
    )
    switch verdict {
    case .accept:      return 0
    case .reject:      return -1
    case .passthrough: return Int32(GIT_PASSTHROUGH.rawValue)
    }
}

private func remoteBridge_transfer(
    stats: UnsafePointer<git_indexer_progress>?,
    payload: UnsafeMutableRawPointer?
) -> Int32 {
    guard let payload, let stats else { return -1 }
    let ctx = Unmanaged<RemoteCallbackContext>.fromOpaque(payload).takeUnretainedValue()
    guard let handler = ctx.transferProgress else { return 0 }
    let carry = handler(TransferProgress(stats.pointee))
    return carry ? 0 : Int32(GIT_EUSER.rawValue)
}
