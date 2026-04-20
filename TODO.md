# TODO

Items deferred from the v0.1.0 XCFramework implementation.

## Out of scope (explicitly excluded from v0.1.0)

- [x] **Idiomatic Swift wrapper layer — first slice (v0.2.0).** `Repository.open(at:)` → `head()` → `log(from:)`, plus `Reference`, `Commit`, `OID`, `Signature`, `Version`, `GitError`, and the `Git` lifecycle namespace. See the v0.2.0 spec under `docs/superpowers/specs/`. Broader wrapper coverage (Tree, Blob, Diff, write operations, remotes) is the follow-up for v0.3+.
- [ ] **SSH support.** Built with `USE_SSH=OFF`; `libssh2` is not included. Cross-compile `libssh2` per slice and either bundle it into the same `libgit2.xcframework` or publish a second XCFramework.
- [ ] **CI automation.** The build and the GitHub Release upload are manual (`./scripts/build-xcframework.sh` + `./scripts/release-xcframework.sh` + `gh release create`). A workflow that triggers on tag push would remove the manual step.
- [ ] **Additional Apple platforms.** Mac Catalyst, visionOS, tvOS, watchOS slices.
- [ ] **iOS test execution.** `swift test` currently runs on macOS only. Verifying the iOS slices on real device / simulator would catch any platform-specific link/runtime issues.

## Deferred code review notes

- [x] **README.** Landed pre-v0.2.0.
- [ ] **Script portability notes.** `scripts/release-xcframework.sh` uses BSD `stat -f%z`; add a header comment noting the macOS-only assumption (or switch to a portable form if a Linux CI runner appears).
- [ ] **Error context in `build-xcframework.sh`.** Enrich failures in the per-slice CMake/build loop to name the slice (currently you infer it from the preceding `---- building` line). Validate `xcrun --show-sdk-path` output before passing to CMake.
- [ ] **`find | while` subshell scope.** The header-overlay loop in `build-xcframework.sh` uses `find ... | while`, which runs the loop body in a subshell. Harmless today (no state leaves the loop); rewrite as `while ... done < <(...)` if future logic needs to accumulate state.
- [ ] **`swift package compute-checksum` error handling.** Rely on `set -e` today; no explicit guard.

## libgit2 build options not enabled

- [ ] **`EXPERIMENTAL_SHA256`** — required to read/write SHA-256 repositories.
- [ ] **Explicit `USE_I18N` control.** Currently left at libgit2 default, which pulls in `iconv` (hence the `.linkedLibrary("iconv")` in `Package.swift`). Decide whether we want i18n on, and make it explicit in the CMake flags either way.

## Suggested next steps (rough priority, post-v0.2.0)

1. **LICENSE file** — referenced from README; trivial cost and blocks nothing but should land before the first polished release.
2. **GitHub Actions** — tag-push → build on a macOS runner → create release → attach zip. Removes the human from the release loop.
3. **Swift wrapper v0.3 read-extensions — shipped.** Tree, Blob, Tag, polymorphic `Object`, tree-to-tree Diff, `Repository.discover(startingAt:)`, `Repository.references`, sortable `log(from:sorting:)`, public `RevWalk`.
4. **SSH support** — only if a concrete use case appears.

## Deferred from v0.2.0 (Swift wrapper first slice)

- [x] **Public API doc comments.** Every public type in `Git2` has `///` doc comments (commit `03d6d6a`).
- [x] **`git_oid_fromstr` is deprecated in libgit2 1.x.** Currently used by `OID(hex:)`. Migrate to `git_oid_fromstrn` (or `git_oid_fromstrp` for prefix form) before libgit2 2.x removes it. Resolved in Task 1 — `OID(hex:)` now uses `git_oid_fromstrn`.
- [x] **`RevWalkHandle.init` swallows errors silently.** If `git_revwalk_new` or `git_revwalk_push` fails, `nextCommit()` returns `nil` forever with no diagnostic. `Repository.log(from: Commit)` is safe because `Commit` validity is already established, but a future `log(fromOID: OID)` overload would need to surface init failures. Resolved in Task 9 — `RevWalkHandle` deleted; public `RevWalk` has throwing init/push/next.
- [x] **Defensive force-unwraps have libgit2 contract comments** (added alongside DocC comments in `03d6d6a`).
- [ ] **ThreadSanitizer in CI.** Spec §9.4 lists this as an unaddressed test-coverage gap. Worth wiring once GitHub Actions is set up (see #3 above).
- [x] **CHANGELOG.md** for v0.1.0 → v0.2.0 (landed pre-release).
- [x] **README.md** with SwiftPM snippet + quick-start (landed pre-release; the earlier "README" item in this file is now obsolete).
- [ ] **LICENSE file.** README references it; add before tagging if possible.

## Deferred from v0.4a (ODB write foundation)

Non-blocking follow-ups identified while designing v0.4a. Each is an additive, non-breaking API and can be revisited when a concrete use case appears.

- [ ] **Stateful `TreeBuilder` class.** Public handle with `insert(name:oid:filemode:)` / `remove(name:)` / `derived(from: Tree)` / `write() -> Tree`. v0.4a ships a flat `Repository.tree(entries:)` only; differential builds and "take an existing tree and tweak one entry" land here.
- [ ] **`createBlob(fromFileAt: URL)` / streaming blob creation.** v0.4a takes `Data` only.
- [ ] **Tag of non-commit target.** `target: Object` overloads on `createLightweightTag` / `createAnnotatedTag` for tag-of-tag / tag-of-tree use cases. v0.4a restricts `target` to `Commit`.
- [ ] **Remote branch creation / deletion** (`GIT_BRANCH_REMOTE`). v0.4a is `GIT_BRANCH_LOCAL` only.
- [ ] **Signed commits** — `commit(...)` overload wrapping `git_commit_create_with_signature`.
- [ ] **`message_encoding:` parameter** on `commit(...)`. v0.4a passes `nil` to libgit2 (treat as UTF-8).
- [ ] **TestFixture `TreeEntryDescription` migration.** v0.4a leaves `TreeEntryDescription.mode` as `git_filemode_t`; swap it for the public `TreeEntry.FileMode` to drop the final `@testable` `Cgit2` dependency from the fixture layer.
- [ ] **`import Cgit2` in v0.4a test files.** `RepositoryBlobsTests`, `RepositoryTreesTests`, `RepositoryCommitsTests`, `RepositoryBranchesTests`, `RepositoryTagsTests`, and `WriteConcurrencyTests` each call `git_repository_init` + `git_repository_free` directly to set up an empty repo. Remove the import once repository initialization itself is exposed as a public API (separate slice — v0.4a intentionally does not cover repo creation).
- [ ] **`ReferenceDeleteTests.secondDeleteThrows` only asserts the error type.** Tighten to `#expect(error.code == .notFound)` (`git_reference_delete` on a missing ref is documented as `GIT_ENOTFOUND`). Aligns with spec §9.2 error-code specificity.
- [ ] **`tree(entries:)` duplicate check is String-based.** The `Set<String>` guard treats Unicode NFC vs NFD variants of the same logical name as duplicates, while libgit2 would byte-compare and accept them. Unlikely to bite in practice, but document the assumption or normalize the names before insertion.
- [ ] **FileMode integration coverage for `.link` / `.commit`.** `TreeEntryFileModeRawTests` covers every case as a unit, and `TreeTests` covers `.blob` / `.blobExecutable`. Add a `tree(entries:)` integration test that round-trips a symbolic-link and a submodule-commit entry through the ODB once the fixture layer supports them more conveniently.

## Deferred from v0.3.0 (Swift wrapper read extensions)

- [ ] **`RevWalk.next()` holds the lock across `git_commit_lookup`.** The closure passed to `repository.lock.withLock` does (a) `git_revwalk_next` and (b) `git_commit_lookup` back-to-back. No deadlock in practice (the standard `while let c = try walk.next()` loop releases the lock between calls), but it serializes the lookup against every other repo operation and is a future trap if the lookup grows side effects. Worth revisiting when introducing additional throwing APIs that want to call into the public surface mid-walk.
- [ ] **`ReferenceLookupTests.invalidRefSpecThrows` only asserts the error type.** It uses `""` (legitimately rejected with `GIT_EINVALIDSPEC`) and checks `throws: GitError.self`. Tighten to `#expect(error.code == .invalidSpec)` so a future regression that swallows the spec error and throws a generic `GitError` cannot pass.
- [ ] **`Object.wrap` default-branch test.** The `default:` arm in `Object.wrap` frees the handle and throws `.invalid` / `.object` for any `git_object_t` outside the four user-level kinds. In a healthy libgit2 build this branch is unreachable from the public API, but a regression test that hands `wrap` a synthetic non-standard `git_object_type` would lock in the leak-safety guarantee.
- [ ] **`ObjectKindTests` uses numeric literals (`5`, `6`) for delta types.** `GIT_OBJECT_OFS_DELTA` / `GIT_OBJECT_REF_DELTA` are not in the public Cgit2 surface (they live in libgit2's packfile internals). The test asserts the mapping by passing `git_object_t(5)` / `git_object_t(6)` directly. If libgit2 ever renumbers those internals the test silently shifts meaning. Either drop those two `#expect` lines (the `default:` branch is already exercised by `ANY` and `INVALID`) or reach into a libgit2 internal header to pull the constants honestly.

## Future wrapper slices (planned post-v0.2.0)

Mirrors the roadmap in the v0.2.0 design spec §10.2
(`docs/superpowers/specs/2026-04-20-git2-swift-wrapper-foundation-design.md`).
Phase labels are non-binding — each slice will get its own spec before
implementation.

### v0.3 — read extensions

- [x] **`Repository.discover(startingAt:)`** — walk up from a child directory to find `.git`. Resolved by discover + open(discoveringFrom:).
- [x] **`Repository.references`** (list) and **`reference(named:)`** (lookup). Resolved.
- [x] **`Tree` / `Blob` / `Tag` / polymorphic `Object` enum** — the other object types. Resolved.
- [x] **`Diff`** — tree-to-tree, file-level (no hunk/line yet). Resolved.
- [x] **`CommitSequence.Sorting`** — `.none` / `.topological` / `.time` / `.reverse`, exposed via a new `log(from:sorting:)` overload. Resolved.
- [x] **Public `RevWalk` type** — advanced revwalk control (`push(refName:)`, `hide(_:)`, `simplifyFirstParent()`, explicit error reporting). Resolved.
- [x] **Tag peel handling in `Reference`** — right now `resolveToCommit()` handles annotated tags, but there is no standalone test. Resolved (test added).

### v0.4 — write operations

Split into two slices. v0.4a covers the ODB-write surface (blob / tree / commit creation, branch + tag create/delete, generic reference delete). v0.4b covers the filesystem-touching surface (index, checkout, HEAD manipulation). See the v0.4a spec under `docs/superpowers/specs/2026-04-20-git2-v0.4a-write-foundation-design.md`.

#### v0.4a — ODB write foundation

- [x] **Blob creation** — `Repository.createBlob(data:) -> OID`.
- [x] **Tree construction (flat)** — `Repository.tree(entries:) -> Tree` with a `TreeBuilderEntry` snapshot value.
- [x] **Commit creation** — `Repository.commit(tree:parents:author:committer:message:updatingRef:)`. Replaces the test-only `TestFixture` builder with a real public API.
- [x] **Branch creation / deletion** — `Repository.createBranch(named:at:force:)` / `Repository.deleteBranch(named:)`. Local branches only.
- [x] **Tag creation / deletion** — split `createLightweightTag` / `createAnnotatedTag` + `deleteTag(named:)`. `target: Commit` only.
- [x] **Generic reference delete** — `Reference.delete()` for non-branch / non-tag refs.
- [x] **TestFixture rewrite** — delegate `makeLinearHistory` / `makeMergeHistory` / `makeCommitWithTree` / `makeBranches` / `makeAnnotatedTag` to the new public API; drop the libgit2-direct paths where possible.

#### v0.4b — index, checkout, HEAD

- [ ] **Index / staging** — `git_index_*` wrapper (read, add, remove, write, conflict enumeration).
- [ ] **Checkout** — `git_checkout_head` / `git_checkout_tree` / `git_checkout_index` with safety options.
- [ ] **HEAD manipulation** — `git_repository_set_head` / `git_repository_set_head_detached`, branch switching.

### v0.5+ — network & advanced

- [ ] **Remote / fetch / push** (HTTPS). Callbacks for credentials surfaced to the user; no UI.
- [ ] **Merge / rebase / cherry-pick**. Deep write operations with conflict handling.

### Potential future directions (unscoped)

- [ ] **Async / actor-based high-level API.** During v0.2.0 brainstorming we picked `@unchecked Sendable` + synchronous + internal lock over an `actor Repository`. Reconsider if a compelling async-first use case shows up (e.g. SwiftUI views that want to observe repo state without blocking).
- [ ] **Benchmarks.** Spec §9.4 notes that performance under large histories is not measured. Worth standing up a `swift-package-manager-plugin` or a simple benchmark target when a concrete regression is suspected.
- [ ] **Hooks, worktrees, submodules, stash, bisect, reflog, notes, attributes, config.** libgit2 exposes all of these; none are covered yet. Prioritize when a user asks.
- [ ] **SSH support**. Requires building `libssh2` into the XCFramework (or a sibling framework) — tracked above under "Out of scope from v0.1.0".

## Minor polish (non-blocking)

- [ ] **`Signature.timeZone` fallback comment** — already mentions "defensive" but could link to Git's offset range (±14h) explicitly.
- [ ] **`Repository.open` sentinel when `withUnsafeFileSystemRepresentation` yields nil** — currently returns `GIT_EINVALIDSPEC`. `preconditionFailure` (bad URL = programmer error) would be clearer; needs confirmation that the nil path truly cannot happen in practice.
- [ ] **Pre-existing test warnings** — `as GitError` "always true" warning in `GitErrorTests.swift:94`, and a redundant `try` on a non-throwing call in `RepositoryHeadTests.swift:39`. Neither affects correctness; tidy on the next test refactor.
