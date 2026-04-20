# TODO

Items deferred from the v0.1.0 XCFramework implementation.

## Out of scope (explicitly excluded from v0.1.0)

- [ ] **SSH support.** Built with `USE_SSH=OFF`; `libssh2` is not included. Cross-compile `libssh2` per slice and either bundle it into the same `libgit2.xcframework` or publish a second XCFramework.
- [ ] **CI automation.** The build and the GitHub Release upload are manual (`./scripts/build-xcframework.sh` + `./scripts/release-xcframework.sh` + `gh release create`). A workflow that triggers on tag push would remove the manual step.
- [ ] **Additional Apple platforms.** Mac Catalyst, visionOS, tvOS, watchOS slices.
- [ ] **iOS test execution.** `swift test` currently runs on macOS only. Verifying the iOS slices on real device / simulator would catch any platform-specific link/runtime issues.

## Deferred code review notes

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

- [ ] **ThreadSanitizer in CI.** Spec §9.4 lists this as an unaddressed test-coverage gap. Worth wiring once GitHub Actions is set up (see #3 above).
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

## Deferred from v0.4b-i (Index slice)

Non-blocking follow-ups identified while designing v0.4b-i. Each is additive and non-breaking, and can be revisited when a concrete use case appears.

- [ ] **Manual `IndexEntry` insertion.** Public API that takes a caller-constructed `IndexEntry` (stage included) and writes it to the index. Requires a public `IndexEntry.Stage.rawFlags` round-trip. Defer until Merge / cherry-pick need it.
- [ ] **`Index.readTree(from: Tree)` and `Index.clear()`.** Consumed by Merge / reset-style flows that do not exist yet.
- [ ] **Pathspec-based bulk operations.** `Index.addAll(pathspec:)` / `.removeAll(pathspec:)` / `.updateAll(pathspec:)` wrapping `git_index_add_all` / `_remove_all` / `_update_all`. v0.4b-i takes a single `String` path per call.
- [ ] **Extended `IndexEntry` stat fields.** `mtime`, `ctime`, `fileSize`, `uid`, `gid`, `dev`, `ino`, `flags_extended`. Surface when a stat-based diff or working-tree-dirty-detection API is added.
- [ ] **Lazy iteration.** `Index.lazyEntries() -> some Sequence<IndexEntry>` / `lazyConflicts() -> some Sequence<IndexConflict>`. v0.4b-i returns Array snapshots. Add only if a concrete performance pressure appears.
- [ ] **`TestFixture.makeConflictedIndex` migration off `Cgit2`.** v0.4b-i constructs synthetic 3-way conflicts via `git_index_add` with stage-encoded flags because no public API accepts stage-carrying entries yet. Replace with a public Merge-API-based helper once that slice lands.
- [ ] **Tighten error-code specificity in Index failure tests.** `IndexMutationTests.addPath_missingFileThrowsNotFound` / `addPath_onBareRepoThrows` and `IndexConflictTests.writeTree_onConflictedIndexThrows` currently assert `throws: GitError.self`. Spec §9.2 calls for `error.code == .notFound` / `error.class == .repository` / `error.code == .unmerged` assertions. Mechanical tightening, same polish as v0.3's follow-up on `invalidSpec`.
- [ ] **Clarify `_ = repo` in `IndexConflictTests.makeConflictedIndex_populatesThreeStages`.** The throwaway assignment exists to make the init side-effects (`.git/` directory on disk) explicit while discarding the unused `Repository` handle. Either inline as `_ = try initRepo(at: dir)` or add a comment explaining why the handle is created but not used.

## Deferred from v0.4b-ii (checkout / HEAD slice)

Non-blocking follow-ups identified while designing v0.4b-ii. Each is additive and non-breaking, and can be revisited when a concrete use case appears.

- [ ] **Checkout callbacks.** `notify_cb` / `progress_cb` / `perfdata_cb`. Bridging Swift closures to C callbacks (context pointer lifetime, cancellation propagation) is its own implementation surface. Land when a concrete UI requirement appears.
- [ ] **`CheckoutOptions` fields not surfaced.** `baseline`, `baseline_index`, `target_directory`, `ancestor_label` / `our_label` / `their_label`, `dir_mode`, `file_mode`, `file_open_flags`, `disable_filters`. `baseline` in particular deserves a second look during the merge slice so conflict detection gets more precise context.
- [ ] **Merge-flavored strategy flags.** `GIT_CHECKOUT_USE_OURS` / `USE_THEIRS` / `SKIP_UNMERGED`. v0.4b-ii deliberately omits them; they land with the merge / cherry-pick slice (v0.5+).
- [ ] **`checkoutTree(_: Tag, options:)` overload.** libgit2 accepts a tag as a treeish, but v0.4b-ii's `checkoutTree` surfaces only the `Tree` and `Commit` overloads. Add when a concrete tag-checkout use case appears.
- [ ] **`Repository.detachHead()`.** Sugar for `git_repository_detach_head` (detach HEAD from the current branch onto its tip). Replaceable today with `setHead(detachedAt: try repo.head().target)`; lands if the two-line version becomes a pattern.
- [ ] **Remote-branch switching.** `checkout(branchNamed:)` looks up `GIT_BRANCH_LOCAL` only. Add a `GIT_BRANCH_REMOTE` (or `GIT_BRANCH_ALL`) code path once remote-tracking use cases appear.
- [ ] **Atomic branch-switch rollback.** `checkout(branch:)` runs `checkout_tree` → `set_head` inside one lock; libgit2 does not roll back if `set_head` fails after `checkout_tree` succeeds, and neither does the wrapper. A "remember old HEAD, restore on failure" layer is possible but complex (working-tree state is already mutated) and deferred until a concrete demand surfaces.
- [ ] **Checkout FileMode integration coverage.** `.link` / `.commit` (submodule) round-trip through checkout. Same shape as the v0.4a `tree(entries:)` TODO — needs fixture-layer support before it is worth writing.
- [ ] **Tighten `CheckoutHeadTests` error-code specificity.** `safeStrategyRefusesDirtyWorkdir` asserts only `e.class == .checkout`; `unbornHeadThrowsUnbornBranch` asserts only `e.code == .unbornBranch`. Add the mirrored assertion in each (observed libgit2 values, same shape as `bareRepoThrows`) so a future regression that drifts one without the other surfaces. Consistent with v0.3 / v0.4a / v0.4b-i error-code tightening follow-ups.
- [ ] **Cosmetic `try repo.references()` warning.** `Repository.references()` is non-throwing, so `try` emits `"no calls to throwing functions occur within 'try' expression"`. Appears at least three times in `CheckoutBranchTests` (carried over from the plan verbatim) and likely in other suites that pre-date the non-throwing signature. Sweep across `Tests/Git2Tests/` and drop the redundant `try`.
- [ ] **Reconsider `@testable import Git2` in Checkout tests.** `CheckoutHeadTests`, `CheckoutTreeTests`, `CheckoutIndexTests`, `CheckoutBranchTests`, `CheckoutConcurrencyTests` all use `@testable` even though every API they exercise is `public`. Matches other test files' convention, so not a blocker; revisit if we ever decide to trim `@testable` across the test target.

## Deferred from v0.5a-i (merge / cherry-pick slice)

Non-blocking follow-ups identified while designing v0.5a-i. Each is additive and non-breaking, and can be revisited when a concrete use case appears.

- [ ] **`git_merge_file` / `_from_index`.** File-level 3-way merge with configurable drivers. Land when a UI or conflict-resolution use case needs sub-file control.
- [ ] **`git_merge_bases` / `_bases_many` (plural).** Return all common ancestors, not just the single best one.
- [ ] **`git_merge_analysis_for_ref`.** Analyze a merge into a non-HEAD ref.
- [ ] **`git_annotated_commit_from_fetchhead`.** Lands with v0.5b remote support (fetchhead doesn't exist yet).
- [ ] **`git_annotated_commit_from_revspec`.** Revspec is not yet a public surface; revisit if we expose revspec lookup.
- [ ] **`MergeOptions` deeper fields.** `metric` (function pointer), `recursion_limit`, `default_driver`, `file_flags`.
- [ ] **Octopus merge (`heads.count > 1`).** `merge(_ heads: [AnnotatedCommit], …)` rejects `heads.count != 1` today. The signature accepts an array for future compatibility.
- [ ] **Auto-commit porcelain.** `git merge` style automatic merge-commit creation on the non-conflicting `.normal` path. Callers compose the existing `commit(parents: [our, their], …)` API themselves today.
- [ ] **`abortMerge()` / `abortCherrypick()` convenience.** Composable via `cleanupState()` + `checkoutHead(strategy: .force)`; lands if the pattern repeats at call sites.
- [ ] **Merge / cherry-pick callbacks (`notify_cb` / `progress_cb` / `perfdata_cb`).** Same bridging problem as v0.4b-ii's checkout callbacks.
- [ ] **`Commit` / `Reference`-accepting merge / cherry-pick overloads.** v0.5a-i requires explicit `AnnotatedCommit`; convenience overloads can land additively later.
- [ ] **Atomic rollback on porcelain merge.** Same trade-off as v0.4b-ii's `checkout(branch:)` — if `checkoutHead` fails after `setHead` succeeds on the fast-forward path, HEAD has moved but the working tree is stale. No Swift-layer rollback.
- [ ] **`AnnotatedCommit` re-use.** Currently documented as single-use recommended. Formal re-use semantics are not pinned.
- [ ] **Reflog-content assertions.** `SetHeadAnnotatedTests.refProvenance_landsInReflog` only checks that HEAD moves, because reflog inspection is not yet public surface. Tighten when reflog reads land.
- [ ] **Porcelain `merge(_:Reference)` `.unborn` dispatch test.** The porcelain's `.unborn` branch (attach-HEAD + checkoutHead) is implemented but not covered by `MergePorcelainTests`. Task 11's `MergeAnalysisTests.unborn_whenHeadIsUnborn` covers the analysis return value but not the dispatch side-effects. Add when a concrete use case stress-tests it.
- [ ] **`among_singleOID` naming.** Task 10 renamed the test to `among_singleOID_throwsUnknown` after discovering libgit2 1.9.x rejects single-OID `git_merge_base_many` calls. Revisit if a later libgit2 version accepts them and returns self.
- [ ] **Redundant `try` on `repo.log(from:)` in `SetHeadAnnotatedTests.detachesHeadToOid`.** Shares the same "try on a non-throwing Sequence call" pattern already tracked in v0.4b-ii's TODO for `repo.references()`. Sweep together.

## Deferred from v0.5a-ii (rebase slice)

Non-blocking follow-ups identified while implementing v0.5a-ii. Each is additive and non-breaking, and can be revisited when a concrete use case appears.

- [ ] **Rebase callbacks (`commit_create_cb` / `signing_cb`).** Swift-closure-to-C-function-pointer bridging (context pointer lifetime, cancellation propagation, typed-throws leakage). Same shape as v0.4b-ii's checkout callbacks and v0.5a-i's merge callbacks; better handled as one unified slice. `signing_cb` is additionally deprecated in libgit2.
- [ ] **`Commit` / `Reference`-accepting `startRebase` overloads.** v0.5a-ii requires explicit `AnnotatedCommit`; convenience overloads can land additively.
- [ ] **Porcelain `rebase(onto:)` with auto-continue.** Higher-level "apply the whole rebase, surface conflicts once at the end" wrapper around `startRebase` + `next` / `commit` loop.
- [ ] **`abortRebase()` convenience on `Repository`.** Composable via `openRebase()` + `rebase.abort()` today.
- [ ] **Interactive rebase todo-list editing.** libgit2 does not publish a public `rebase-todo` editing API; v0.5a-ii surfaces the operation list for inspection only.
- [ ] **Cross-process rebase resume fidelity test.** `openRebase()` is exercised single-process (start → drop handle → open). Running `git rebase` from a shell and `openRebase()` from Swift in separate processes would raise coverage; skipped because the CI shape is messy.
- [ ] **Atomic rollback mid-`commit()`.** If a `commit()` is interrupted, `.git/rebase-merge/` is whatever libgit2 left — recovery is via `openRebase()` + `abort()` in a later session. Same trade-off as v0.5a-i §4.8.
- [ ] **FileMode integration coverage for `.link` / `.commit` through rebase.** Same shape as the v0.4a / v0.4b-ii / v0.5a-i deferred items — surfaces once the fixture layer supports those filemodes more conveniently.
- [ ] **`Rebase` handle-consumed guard.** `finish()` / `abort()` tear down the repository-side state but the Swift handle stays live until deinit; subsequent calls pass through libgit2's (actually idempotent in 1.9.x — not erroring) behavior. A `consuming func` or state-machine guard could reject the second call at the Swift layer — deferred because it diverges from every other handle class's "thin wrapper" convention.
- [ ] **`ontoName` / `origHeadName` asymmetry.** libgit2 strips `refs/heads/` from `git_rebase_onto_name` but keeps the full canonical path in `git_rebase_orig_head_name`. v0.5a-ii surfaces libgit2's behavior unchanged. Normalizing this at the Swift layer (e.g. always returning the canonical form) would diverge from the spec's "thin wrapper" policy; revisit if the asymmetry becomes a UX issue.
- [ ] **`withTemporaryDirectoryAsync` hoist.** `CheckoutConcurrencyTests.swift`, `MergeConcurrencyTests.swift`, and `RebaseConcurrencyTests.swift` each define their own private copy. Hoist trigger (three duplicates) is already met; pull into `Tests/Git2Tests/Support/` on the next sweep.
- [ ] **`RebaseConcurrencyTests` sanity assertion.** The parallel test currently only asserts "doesn't crash"; adding `#expect(rebase.operationCount == 3)` after the task group would tighten the guarantee that metadata reads still return correct values under contention.

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

### v0.4 — write operations

Split into two slices. v0.4a covers the ODB-write surface (blob / tree / commit creation, branch + tag create/delete, generic reference delete). v0.4b covers the filesystem-touching surface (index, checkout, HEAD manipulation). See the v0.4a spec under `docs/superpowers/specs/2026-04-20-git2-v0.4a-write-foundation-design.md`.

#### v0.4b — index, checkout, HEAD

Split into two slices. **v0.4b-i (index surface) is shipped** — see the spec under `docs/superpowers/specs/2026-04-20-git2-v0.4b-i-index-design.md`. v0.4b-ii covers the filesystem-touching surface (checkout, HEAD manipulation).

##### v0.4b-ii — checkout, HEAD — shipped

- [x] **Checkout** — `git_checkout_head` / `git_checkout_tree` / `git_checkout_index` with safety options.
- [x] **HEAD manipulation** — `git_repository_set_head` / `git_repository_set_head_detached`, branch switching.

### v0.5 — network & advanced

Split across multiple slices.

#### v0.5a-i — merge / cherry-pick — shipped

- [x] **Merge primitives** — `AnnotatedCommit` handle, `mergeBase(of:and:)` / `(among:)`, `mergeAnalysis(against:)`, `mergeTrees(...)` / `mergeCommits(...)`.
- [x] **Stateful merge** — low-level `merge([AnnotatedCommit])` + porcelain `merge(_ branch:)` / `merge(branchNamed:)` with fast-forward dispatch.
- [x] **Cherry-pick** — `cherrypick(_:)` (stateful) + `cherrypickCommit(_:onto:mainline:)` (pure).
- [x] **Repository state** — `state`, `message()`, `removeMessage()`, `cleanupState()`.
- [x] **Annotated HEAD** — `setHead(detachedAtAnnotated:)`. See the spec under `docs/superpowers/specs/2026-04-20-git2-v0.5a-i-merge-cherrypick-design.md`.

##### v0.5a-ii — rebase — shipped

- [x] **Rebase handle** — `git_rebase_init` / `git_rebase_open`, `Rebase.next()` / `.commit()` iteration, `finish()` / `abort()` termination, metadata (`operationCount` / `currentOperationIndex` / `operation(at:)` / `origHeadName` / `origHeadOid` / `ontoName` / `ontoOid`), in-memory mode + `inMemoryIndex()`, `RebaseOptions`. See the spec under `docs/superpowers/specs/2026-04-20-git2-v0.5a-ii-rebase-design.md`.

#### v0.5b — network

- [ ] **Remote / fetch / push** (HTTPS). Callbacks for credentials surfaced to the user; no UI.

### Potential future directions (unscoped)

- [ ] **Async / actor-based high-level API.** During v0.2.0 brainstorming we picked `@unchecked Sendable` + synchronous + internal lock over an `actor Repository`. Reconsider if a compelling async-first use case shows up (e.g. SwiftUI views that want to observe repo state without blocking).
- [ ] **Benchmarks.** Spec §9.4 notes that performance under large histories is not measured. Worth standing up a `swift-package-manager-plugin` or a simple benchmark target when a concrete regression is suspected.
- [ ] **Hooks, worktrees, submodules, stash, bisect, reflog, notes, attributes, config.** libgit2 exposes all of these; none are covered yet. Prioritize when a user asks.
- [ ] **SSH support**. Requires building `libssh2` into the XCFramework (or a sibling framework) — tracked above under "Out of scope from v0.1.0".

## Minor polish (non-blocking)

- [ ] **`Signature.timeZone` fallback comment** — already mentions "defensive" but could link to Git's offset range (±14h) explicitly.
- [ ] **`Repository.open` sentinel when `withUnsafeFileSystemRepresentation` yields nil** — currently returns `GIT_EINVALIDSPEC`. `preconditionFailure` (bad URL = programmer error) would be clearer; needs confirmation that the nil path truly cannot happen in practice.
- [ ] **Pre-existing test warnings** — `as GitError` "always true" warning in `GitErrorTests.swift:94`, and a redundant `try` on a non-throwing call in `RepositoryHeadTests.swift:39`. Neither affects correctness; tidy on the next test refactor.
