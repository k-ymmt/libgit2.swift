import Foundation
@testable import Git2
import Cgit2

/// Initializes a fresh non-bare repository at `dir` via `git_repository_init`,
/// then opens and returns it via the public API.
///
/// Use this when a test needs an empty (no-commits) repo; prefer the
/// higher-level `TestFixture.makeLinearHistory` / `makeMergeHistory` when a
/// populated history is required.
func initRepo(at dir: URL) throws -> Repository {
    var raw: OpaquePointer?
    let r: Int32 = dir.withUnsafeFileSystemRepresentation { path in
        guard let path else { return -1 }
        return git_repository_init(&raw, path, 0)
    }
    guard r == 0, let raw else { throw GitError.fromLibgit2(r) }
    git_repository_free(raw)
    return try Repository.open(at: dir)
}

/// Initializes a fresh **bare** repository at `dir` via `git_repository_init`
/// with `is_bare = 1`, then opens and returns it via the public API.
func initBareRepo(at dir: URL) throws -> Repository {
    var raw: OpaquePointer?
    let r: Int32 = dir.withUnsafeFileSystemRepresentation { path in
        guard let path else { return -1 }
        return git_repository_init(&raw, path, 1)
    }
    guard r == 0, let raw else { throw GitError.fromLibgit2(r) }
    git_repository_free(raw)
    return try Repository.open(at: dir)
}
