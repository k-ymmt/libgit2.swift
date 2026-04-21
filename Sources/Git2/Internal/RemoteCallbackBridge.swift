import Cgit2

/// Per-call state that the C trampolines dispatch into.
///
/// One instance is created per `withRemoteCallbacks` call and kept alive
/// for the duration of the libgit2 operation via `withExtendedLifetime`.
/// The C trampolines receive a raw `payload` pointer that is cast back to
/// this object using an unretained `Unmanaged` reference — no ARC traffic
/// during the callback.
///
/// Fetch and push fields are disjoint in practice: each call site
/// constructs the context with exactly one `init`, leaving the other
/// family's fields `nil` / empty.
internal final class RemoteCallbackContext {
    // fetch (v0.5b-i)
    let credentials:      Repository.FetchOptions.CredentialsHandler?
    let certificateCheck: Repository.FetchOptions.CertificateCheckHandler?
    let transferProgress: Repository.FetchOptions.TransferProgressHandler?
    // push (v0.5b-ii)
    let pushTransferProgress: Repository.PushOptions.PushTransferProgressHandler?
    let pushUpdateReference:  Repository.PushOptions.PushUpdateReferenceHandler?
    /// Collected by `remoteBridge_pushUpdateReference` every time the
    /// server returns a non-nil status for a ref. Inspected by
    /// `Remote.push(...)` after `git_remote_push` returns.
    var pushRejections: [(refname: String, status: String)] = []
    // shared
    var capturedError: (any Error)?

    init(fetch options: Repository.FetchOptions) {
        self.credentials            = options.credentials
        self.certificateCheck       = options.certificateCheck
        self.transferProgress       = options.transferProgress
        self.pushTransferProgress   = nil
        self.pushUpdateReference    = nil
    }

    init(push options: Repository.PushOptions) {
        self.credentials            = options.credentials
        self.certificateCheck       = options.certificateCheck
        self.transferProgress       = nil
        self.pushTransferProgress   = options.pushTransferProgress
        self.pushUpdateReference    = options.pushUpdateReference
    }
}

/// Fetch overload (v0.5b-i).
internal func withRemoteCallbacks<R>(
    _ options: Repository.FetchOptions,
    _ body: (UnsafeMutablePointer<git_remote_callbacks>, RemoteCallbackContext) throws(GitError) -> R
) throws(GitError) -> R {
    var cbs = git_remote_callbacks()
    let rc = git_remote_init_callbacks(&cbs, UInt32(GIT_REMOTE_CALLBACKS_VERSION))
    precondition(rc == 0, "git_remote_init_callbacks should never fail at version \(GIT_REMOTE_CALLBACKS_VERSION)")

    let ctx = RemoteCallbackContext(fetch: options)
    cbs.payload = Unmanaged.passUnretained(ctx).toOpaque()

    if options.credentials      != nil { cbs.credentials       = remoteBridge_credentials }
    if options.certificateCheck != nil { cbs.certificate_check = remoteBridge_certCheck }
    if options.transferProgress != nil { cbs.transfer_progress = remoteBridge_transfer }

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

/// Push overload (v0.5b-ii).
internal func withRemoteCallbacks<R>(
    _ options: Repository.PushOptions,
    _ body: (UnsafeMutablePointer<git_remote_callbacks>, RemoteCallbackContext) throws(GitError) -> R
) throws(GitError) -> R {
    var cbs = git_remote_callbacks()
    let rc = git_remote_init_callbacks(&cbs, UInt32(GIT_REMOTE_CALLBACKS_VERSION))
    precondition(rc == 0, "git_remote_init_callbacks should never fail at version \(GIT_REMOTE_CALLBACKS_VERSION)")

    let ctx = RemoteCallbackContext(push: options)
    cbs.payload = Unmanaged.passUnretained(ctx).toOpaque()

    if options.credentials          != nil { cbs.credentials            = remoteBridge_credentials }
    if options.certificateCheck     != nil { cbs.certificate_check      = remoteBridge_certCheck }
    if options.pushTransferProgress != nil { cbs.push_transfer_progress = remoteBridge_pushTransfer }
    // push_update_reference is ALWAYS installed — even when the caller
    // does not set a handler — because Remote.push relies on the
    // rejection collector (ctx.pushRejections) to synthesize a GitError
    // for any server-side reject.
    cbs.push_update_reference = remoteBridge_pushUpdateReference

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

private func remoteBridge_pushTransfer(
    current: UInt32,
    total: UInt32,
    bytes: Int,
    payload: UnsafeMutableRawPointer?
) -> Int32 {
    guard let payload else { return -1 }
    let ctx = Unmanaged<RemoteCallbackContext>.fromOpaque(payload).takeUnretainedValue()
    guard let handler = ctx.pushTransferProgress else { return 0 }
    return handler(Int(current), Int(total), bytes) ? 0 : Int32(GIT_EUSER.rawValue)
}

private func remoteBridge_pushUpdateReference(
    refname: UnsafePointer<CChar>?,
    status:  UnsafePointer<CChar>?,
    payload: UnsafeMutableRawPointer?
) -> Int32 {
    guard let payload, let refname else { return -1 }
    let ctx = Unmanaged<RemoteCallbackContext>.fromOpaque(payload).takeUnretainedValue()
    let name = String(cString: refname)
    let statusStr = status.map(String.init(cString:))
    if let s = statusStr {
        ctx.pushRejections.append((refname: name, status: s))
    }
    ctx.pushUpdateReference?(name, statusStr)
    // Return 0 on every invocation — including rejected refs — so libgit2
    // continues delivering results for the remaining refspecs before
    // git_remote_push unwinds. Returning non-zero here short-circuits the
    // call and hides rejection details for refs we have not seen yet.
    // The Swift side inspects ctx.pushRejections after git_remote_push
    // returns and synthesizes a single GitError covering all rejected refs.
    return 0
}
