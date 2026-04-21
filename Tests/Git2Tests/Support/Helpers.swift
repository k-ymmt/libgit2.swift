import Foundation
import Git2

/// Initializes a fresh non-bare repository at `dir` and returns it.
///
/// Use this when a test needs an empty (no-commits) repo; prefer the
/// higher-level `TestFixture.makeLinearHistory` / `makeMergeHistory` when a
/// populated history is required.
func initRepo(at dir: URL) throws -> Repository {
    try Repository.create(at: dir)
}

/// Initializes a fresh **bare** repository at `dir` and returns it.
func initBareRepo(at dir: URL) throws -> Repository {
    try Repository.create(at: dir, bare: true)
}
