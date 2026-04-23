import Cgit2

extension Repository.StatusOptions {
    /// Builds a `git_status_options`, initializes it via
    /// `git_status_options_init`, applies every public field, and invokes
    /// `body`. The `pathspec` strarray and the `baseline` tree handle are
    /// valid only for the duration of `body`.
    internal func withCOptions<R>(
        _ body: (UnsafePointer<git_status_options>) throws(GitError) -> R
    ) throws(GitError) -> R {
        var opts = git_status_options()
        let initResult = git_status_options_init(
            &opts, UInt32(GIT_STATUS_OPTIONS_VERSION)
        )
        try check(initResult)

        opts.show = show.rawValue
        opts.flags = flags.rawValue
        opts.rename_threshold = renameThreshold

        return try withGitStrArray(pathspec) { strarrayPtr throws(GitError) in
            if let strarrayPtr {
                opts.pathspec = strarrayPtr.pointee
            }
            return try withExtendedLifetime(baseline) { () throws(GitError) -> R in
                opts.baseline = baseline?.handle
                // withUnsafePointer is rethrows-untyped; shuttle typed throws
                // across via Result (same pattern as CheckoutOptionsBridge).
                let result: Result<R, GitError> = withUnsafePointer(to: &opts) { optsPtr in
                    do {
                        return .success(try body(optsPtr))
                    } catch let error as GitError {
                        return .failure(error)
                    } catch {
                        fatalError("unreachable: typed throws guarantees GitError")
                    }
                }
                return try result.get()
            }
        }
    }
}
