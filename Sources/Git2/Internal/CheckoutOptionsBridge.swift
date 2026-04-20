import Cgit2

extension Repository.CheckoutOptions {
    /// Builds a `git_checkout_options`, initializes it via
    /// `git_checkout_options_init`, applies `strategy` and `paths`, and
    /// invokes `body`. The `paths` strarray's lifetime is scoped to `body`.
    internal func withCOptions<R>(
        _ body: (UnsafePointer<git_checkout_options>) throws(GitError) -> R
    ) throws(GitError) -> R {
        var opts = git_checkout_options()
        let initResult = git_checkout_options_init(&opts, UInt32(GIT_CHECKOUT_OPTIONS_VERSION))
        try check(initResult)

        opts.checkout_strategy = strategy.rawValue

        return try withGitStrArray(paths) { strarrayPtr throws(GitError) in
            if let strarrayPtr {
                opts.paths = strarrayPtr.pointee
            }
            // `withUnsafePointer` uses untyped `rethrows`, which can't forward
            // typed throws. Carry the outcome across the boundary as a
            // `Result<R, GitError>`, mirroring `withGitStrArray`.
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
