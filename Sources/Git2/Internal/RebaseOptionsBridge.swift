import Cgit2

extension Repository.RebaseOptions {
    /// Builds a `git_rebase_options`, initializes it via
    /// `git_rebase_options_init`, applies the Swift fields, and invokes
    /// `body`. Heap-allocated substructures (merge + checkout + rewrite
    /// notes ref) are kept alive for the duration of the closure through
    /// nested scoping.
    internal func withCOptions<R>(
        _ body: (UnsafePointer<git_rebase_options>) throws(GitError) -> R
    ) throws(GitError) -> R {
        var opts = git_rebase_options()
        try check(git_rebase_options_init(&opts, UInt32(GIT_REBASE_OPTIONS_VERSION)))

        opts.quiet = quiet ? 1 : 0
        opts.inmemory = inMemory ? 1 : 0

        return try merge.withCOptions { mergePtr throws(GitError) -> R in
            opts.merge_options = mergePtr.pointee
            return try checkout.withCOptions { checkoutPtr throws(GitError) -> R in
                opts.checkout_options = checkoutPtr.pointee
                return try withOptionalCString(rewriteNotesRef) { notesPtr throws(GitError) -> R in
                    opts.rewrite_notes_ref = notesPtr
                    // `withUnsafePointer` uses untyped `rethrows`; carry the
                    // outcome across the boundary as a `Result<R, GitError>`.
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
}
