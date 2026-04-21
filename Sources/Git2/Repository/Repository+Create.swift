import Cgit2
import Foundation

extension Repository {
    /// Creates (or reinitializes) a Git repository at `url`.
    ///
    /// Thin wrapper over `git_repository_init_ext` with
    /// `GIT_REPOSITORY_INIT_MKPATH` pre-set, so missing intermediate
    /// directories under `url` are created automatically.
    ///
    /// Reinitializing an existing repository is safe and idempotent:
    /// libgit2 re-applies config but preserves the existing object
    /// database, refs, and HEAD. HEAD is re-targeted only when
    /// `initialBranch` is explicitly non-`nil` on the reinit call.
    ///
    /// - Parameters:
    ///   - url: Working-tree directory for non-bare repositories; the
    ///     repository root directory for bare repositories.
    ///   - bare: `true` to create a bare repository (no working tree).
    ///   - initialBranch: Name of the initial branch written into HEAD
    ///     (without the `refs/heads/` prefix — libgit2 adds it). `nil`
    ///     delegates to libgit2, which reads `init.defaultBranch` from
    ///     the user's gitconfig and falls back to `"master"`.
    /// - Returns: An opened ``Repository`` handle for the new
    ///   (or reinitialized) repository.
    /// - Throws: ``GitError`` — ``GitError/Code/invalidSpec`` when `url`
    ///   yields no file-system representation; libgit2 code propagation
    ///   otherwise.
    /// - Precondition: ``Git/bootstrap()`` has been called.
    public static func create(
        at url: URL,
        bare: Bool = false,
        initialBranch: String? = nil
    ) throws(GitError) -> Repository {
        GitRuntime.shared.requireBootstrapped()

        var opts = git_repository_init_options()
        let initRC = git_repository_init_options_init(
            &opts,
            UInt32(GIT_REPOSITORY_INIT_OPTIONS_VERSION)
        )
        precondition(
            initRC == 0,
            "git_repository_init_options_init failed (libgit2 version mismatch?)"
        )

        var flags = UInt32(GIT_REPOSITORY_INIT_MKPATH.rawValue)
        if bare {
            flags |= UInt32(GIT_REPOSITORY_INIT_BARE.rawValue)
        }
        opts.flags = flags

        var raw: OpaquePointer?
        let result: Int32 = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return GIT_EINVALIDSPEC.rawValue }
            if let branch = initialBranch {
                return branch.withCString { branchPtr -> Int32 in
                    opts.initial_head = branchPtr
                    return git_repository_init_ext(&raw, path, &opts)
                }
            } else {
                opts.initial_head = nil
                return git_repository_init_ext(&raw, path, &opts)
            }
        }
        try check(result)
        return Repository(handle: raw!)
    }
}
