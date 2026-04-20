# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows SemVer with the usual `0.x` caveat: the API is not yet stable.

## [Unreleased]

### Added

- `Repository.CheckoutOptions` + `Strategy` (`OptionSet`) — strategy flags mirroring `git_checkout_strategy_t`, plus `paths` pathspec list.
- `Repository.checkoutHead(options:)` — wraps `git_checkout_head`.
- `Repository.checkoutTree(_: Tree, options:)` and `Repository.checkoutTree(_: Commit, options:)` overloads — wrap `git_checkout_tree`.
- `Repository.checkoutIndex(_: Index?, options:)` and `Index.checkout(options:)` sugar — wrap `git_checkout_index`.
- `Repository.setHead(referenceName:)`, `Repository.setHead(detachedAt:)`, `Repository.setHead(to: Reference)`, and `Repository.setHead(to: Commit)`.
- `Repository.checkout(branch:options:)` and `Repository.checkout(branchNamed:options:)` — high-level branch switching that runs `git_checkout_tree` + `git_repository_set_head` inside a single critical section. Non-branch references throw `.invalidSpec` / `.reference` before touching the working tree.
- `AnnotatedCommit` — public handle wrapping `git_annotated_commit *`. Carries ref provenance (branch / FETCH_HEAD) that drives reflog messages.
- `Repository.annotatedCommit(for: Reference)` / `(for: OID)` / `(from: Commit)` — three creation routes for `AnnotatedCommit`.
- `Repository.MergeOptions` + `Flags: OptionSet` + `FileFavor: enum`, `Repository.CherrypickOptions`, `Repository.MergeAnalysis: OptionSet`, `Repository.MergePreference: enum`, `Repository.State: enum` — value types for merge / cherry-pick / state APIs.
- `Repository.mergeBase(of:and:)` and `Repository.mergeBase(among:)` — wrap `git_merge_base` and `git_merge_base_many`.
- `Repository.mergeAnalysis(against:)` — wraps `git_merge_analysis`. Returns `(MergeAnalysis, MergePreference)`.
- `Repository.mergeTrees(ancestor:ours:theirs:options:)` and `Repository.mergeCommits(ours:theirs:options:)` — pure-calculation merges returning an `Index`.
- `Repository.merge(_ heads: [AnnotatedCommit], mergeOptions:, checkoutOptions:)` (low-level) and `Repository.merge(_ branch: Reference, …)` / `Repository.merge(branchNamed:, …)` (porcelain — analyze → fast-forward / normal dispatch inside one critical section, returns the analysis bits). Low-level restricts `heads.count == 1` in v0.5a-i.
- `Repository.cherrypick(_: Commit, options:)` (stateful) and `Repository.cherrypickCommit(_: Commit, onto: Commit, mainline:, mergeOptions:)` (pure calculation).
- `Repository.state`, `Repository.message()`, `Repository.removeMessage()`, `Repository.cleanupState()` — repository-state introspection + cleanup.
- `Repository.setHead(detachedAtAnnotated: AnnotatedCommit)` — wraps `git_repository_set_head_detached_from_annotated`, preserves ref provenance in the reflog.
- `Commit.tree()` — wraps `git_commit_tree`. Resolves a commit's root tree. Added in Task 12 because the public API was missing despite being a natural extension.

## [0.2.0] — TBD

First release with a real Swift API layer over `Cgit2`. v0.1.0 shipped only the
re-exported C surface; v0.2.0 introduces the idiomatic wrapper.

### Added

- `Git2` module with public Swift types covering the narrowest first slice of a
  Git client:
  - `Git` lifecycle namespace: `bootstrap()`, `shutdown()`, `isBootstrapped`,
    `version`.
  - Value types: `Version`, `OID` (SHA-1), `Signature`, `GitError` (with
    forward-compatible `Code` / `Class` enums).
  - Handle types: `Repository` (`open(at:)`, `workingDirectory`, `gitDirectory`,
    `isBare`, `isHeadUnborn`, `head()`, `commit(for:)`, `log(from:)`),
    `Reference` (`name`, `shorthand`, `target`, `resolveToCommit()`),
    `Commit` (`oid`, `message`, `summary`, `body`, `author`, `committer`,
    `parentCount`, `parents()`).
  - Commit walk: `Repository.log(from:)` returns a `CommitSequence: Sequence`,
    iterated via `CommitIterator` over `git_revwalk`.
- Typed throws (`throws(GitError)`) on every failing public API.
- Per-`Repository` serialization via `OSAllocatedUnfairLock`, surfaced as the
  internal `HandleLock`. Handle classes are `@unchecked Sendable`.

### Changed

- **Module / product / target renamed** `libgit2.swift` → `Git2`. The Swift
  Package Manager repository URL (`.package(url: "...libgit2.swift.git")`) is
  unchanged. Downstream consumers should update `import libgit2_swift` →
  `import Git2` and `.product(name: "libgit2.swift", ...)` →
  `.product(name: "Git2", ...)`.
- **Package `name` field** renamed `libgit2.swift` → `Git2` to match the
  product.
- **iOS minimum bumped from 15 to 16** so the wrapper can use
  `OSAllocatedUnfairLock<State>`.
- `Cgit2` continues to ship as an XCFramework `.binaryTarget` pinned to v0.1.0
  (libgit2 1.9.x). No libgit2 rebuild was needed for this release.

### Migration from v0.1.0

- Replace `import libgit2_swift` with `import Git2`.
- Replace direct `git_libgit2_init()` / `git_libgit2_shutdown()` calls with
  `Git.bootstrap()` / `Git.shutdown()`. Mixing is safe (libgit2 itself
  reference-counts initialization) but the `Git` API is preferred.
- Bump `.iOS(.v15)` to `.iOS(.v16)` in downstream `Package.swift` manifests.

### Unreleased follow-ups

Tracked in `TODO.md`:

- `git_oid_fromstr` deprecation (libgit2 1.x deprecates it; planned replacement
  is `git_oid_fromstrn` before a libgit2 2.x bump).
- Broader API surface (read extensions like `Tree`, `Blob`, `Tag`, `Diff`,
  `Repository.discover`, `Repository.references`; write operations;
  remote / fetch / push; SSH support) planned for v0.3+.
- ThreadSanitizer in CI.

## [0.1.0] — 2026-04-19

### Added

- `Cgit2` XCFramework for Apple platforms (macOS / iOS device / iOS Simulator
  slices, Intel + Apple Silicon), distributed via GitHub Releases as
  `libgit2.xcframework.zip` and wired into `Package.swift` as a
  `.binaryTarget`. libgit2 1.9.x, built with `USE_SSH=OFF`,
  `USE_HTTPS=SecureTransport`.
- `libgit2.swift` target that re-exports Cgit2 via `@_exported import Cgit2`.
- Smoke tests covering `git_libgit2_init` / `shutdown` and the reported libgit2
  version.
- `scripts/build-xcframework.sh` and `scripts/release-xcframework.sh` — manual
  build/release tooling pending CI automation.

[Unreleased]: https://github.com/k-ymmt/libgit2.swift/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/k-ymmt/libgit2.swift/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/k-ymmt/libgit2.swift/releases/tag/v0.1.0
