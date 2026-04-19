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
3. **Swift wrapper v0.3 read-extensions** — Tree, Blob, Tag, polymorphic `Object`, tree-to-tree Diff, `Repository.discover(startingAt:)`, `Repository.references`, sortable `log(from:sorting:)`, public `RevWalk`.
4. **SSH support** — only if a concrete use case appears.

## Deferred from v0.2.0 (Swift wrapper first slice)

- [x] **Public API doc comments.** Every public type in `Git2` has `///` doc comments (commit `03d6d6a`).
- [ ] **`git_oid_fromstr` is deprecated in libgit2 1.x.** Currently used by `OID(hex:)`. Migrate to `git_oid_fromstrn` (or `git_oid_fromstrp` for prefix form) before libgit2 2.x removes it.
- [ ] **`RevWalkHandle.init` swallows errors silently.** If `git_revwalk_new` or `git_revwalk_push` fails, `nextCommit()` returns `nil` forever with no diagnostic. `Repository.log(from: Commit)` is safe because `Commit` validity is already established, but a future `log(fromOID: OID)` overload would need to surface init failures. Plan to resolve this when the public `RevWalk` type lands in v0.3.
- [x] **Defensive force-unwraps have libgit2 contract comments** (added alongside DocC comments in `03d6d6a`).
- [ ] **ThreadSanitizer in CI.** Spec §9.4 lists this as an unaddressed test-coverage gap. Worth wiring once GitHub Actions is set up (see #3 above).
- [x] **CHANGELOG.md** for v0.1.0 → v0.2.0 (landed pre-release).
- [x] **README.md** with SwiftPM snippet + quick-start (landed pre-release; the earlier "README" item in this file is now obsolete).
- [ ] **LICENSE file.** README references it; add before tagging if possible.
