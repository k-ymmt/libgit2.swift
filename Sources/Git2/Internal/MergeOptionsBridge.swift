import Cgit2

extension Repository.MergeOptions {
    /// Builds a `git_merge_options`, initializes it via
    /// `git_merge_options_init`, applies the Swift fields, and invokes
    /// `body`. No heap-allocated fields — no scoped cleanup needed.
    internal func withCOptions<R>(
        _ body: (UnsafePointer<git_merge_options>) throws(GitError) -> R
    ) throws(GitError) -> R {
        var opts = git_merge_options()
        try check(git_merge_options_init(&opts, UInt32(GIT_MERGE_OPTIONS_VERSION)))

        opts.flags = flags.rawValue
        opts.rename_threshold = UInt32(renameThreshold)
        opts.target_limit = UInt32(targetLimit)
        switch fileFavor {
        case .normal: opts.file_favor = GIT_MERGE_FILE_FAVOR_NORMAL
        case .ours:   opts.file_favor = GIT_MERGE_FILE_FAVOR_OURS
        case .theirs: opts.file_favor = GIT_MERGE_FILE_FAVOR_THEIRS
        case .union:  opts.file_favor = GIT_MERGE_FILE_FAVOR_UNION
        }

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

extension Repository.CherrypickOptions {
    /// Builds a `git_cherrypick_options`, initializes it via
    /// `git_cherrypick_options_init`, applies `mainline` + the nested
    /// `merge` and `checkout` bundles, and invokes `body`. The nested
    /// `checkout` options may carry a pathspec strarray whose lifetime is
    /// scoped to `body`.
    internal func withCOptions<R>(
        _ body: (UnsafePointer<git_cherrypick_options>) throws(GitError) -> R
    ) throws(GitError) -> R {
        var opts = git_cherrypick_options()
        try check(git_cherrypick_options_init(&opts, UInt32(GIT_CHERRYPICK_OPTIONS_VERSION)))

        opts.mainline = UInt32(mainline)

        // Fold in merge + checkout sub-options. The pathspec strarray in
        // checkout has to stay alive through the libgit2 call, so we nest
        // the closures.
        return try merge.withCOptions { mergePtr throws(GitError) -> R in
            opts.merge_opts = mergePtr.pointee
            return try checkout.withCOptions { checkoutPtr throws(GitError) -> R in
                opts.checkout_opts = checkoutPtr.pointee
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
