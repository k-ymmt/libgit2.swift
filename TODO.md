# TODO

Items deferred from the v0.1.0 XCFramework implementation.

## Out of scope (explicitly excluded from v0.1.0)

- [ ] **Idiomatic Swift wrapper layer.** Current surface is just `@_exported import Cgit2`. Add Swift types like `Repository`, `Reference`, `Commit`, etc. — likely the largest remaining body of work.
- [ ] **SSH support.** Built with `USE_SSH=OFF`; `libssh2` is not included. Cross-compile `libssh2` per slice and either bundle it into the same `libgit2.xcframework` or publish a second XCFramework.
- [ ] **CI automation.** The build and the GitHub Release upload are manual (`./scripts/build-xcframework.sh` + `./scripts/release-xcframework.sh` + `gh release create`). A workflow that triggers on tag push would remove the manual step.
- [ ] **Additional Apple platforms.** Mac Catalyst, visionOS, tvOS, watchOS slices.
- [ ] **iOS test execution.** `swift test` currently runs on macOS only. Verifying the iOS slices on real device / simulator would catch any platform-specific link/runtime issues.

## Deferred code review notes

- [ ] **README.** Top-level README with the `.package(url:)` snippet and a quick-start. Today the only docs live under `docs/superpowers/`.
- [ ] **Script portability notes.** `scripts/release-xcframework.sh` uses BSD `stat -f%z`; add a header comment noting the macOS-only assumption (or switch to a portable form if a Linux CI runner appears).
- [ ] **Error context in `build-xcframework.sh`.** Enrich failures in the per-slice CMake/build loop to name the slice (currently you infer it from the preceding `---- building` line). Validate `xcrun --show-sdk-path` output before passing to CMake.
- [ ] **`find | while` subshell scope.** The header-overlay loop in `build-xcframework.sh` uses `find ... | while`, which runs the loop body in a subshell. Harmless today (no state leaves the loop); rewrite as `while ... done < <(...)` if future logic needs to accumulate state.
- [ ] **`swift package compute-checksum` error handling.** Rely on `set -e` today; no explicit guard.

## libgit2 build options not enabled

- [ ] **`EXPERIMENTAL_SHA256`** — required to read/write SHA-256 repositories.
- [ ] **Explicit `USE_I18N` control.** Currently left at libgit2 default, which pulls in `iconv` (hence the `.linkedLibrary("iconv")` in `Package.swift`). Decide whether we want i18n on, and make it explicit in the CMake flags either way.

## Suggested next steps (rough priority)

1. **README** — lowest effort, biggest discoverability win.
2. **Swift wrapper layer, first slice** — e.g. `Repository.open(path:)` → `Repository.head()` → an iterator over commits. Probably ships as v0.2.0.
3. **GitHub Actions** — tag-push → build on a macOS runner → create release → attach zip. Removes the human from the release loop.
4. **SSH support** — only if a concrete use case appears.

## Deferred from v0.2.0 (Swift wrapper first slice)

- [ ] **Public API doc comments.** Every public type in `Git2` (`Git`, `Repository`, `Reference`, `Commit`, `OID`, `Signature`, `Version`, `GitError`, `CommitSequence`, `CommitIterator`) needs `///` doc comments. Copy the relevant prose from the design spec §8 as a starting point. Blocker for a polished v0.2.0 release.
- [ ] **`git_oid_fromstr` is deprecated in libgit2 1.x.** Currently used by `OID(hex:)`. Migrate to `git_oid_fromstrn` (or `git_oid_fromstrp` for prefix form) before libgit2 2.x removes it.
- [ ] **`RevWalkHandle.init` swallows errors silently.** If `git_revwalk_new` or `git_revwalk_push` fails, `nextCommit()` returns `nil` forever with no diagnostic. `Repository.log(from: Commit)` is safe because `Commit` validity is already established, but a future `log(fromOID: OID)` overload would need to surface init failures. Plan to resolve this when the public `RevWalk` type lands in v0.3.
- [ ] **Defensive force-unwraps need libgit2 contract comments.** Several force-unwraps in `Commit`, `Reference`, and `Repository` (e.g. `git_commit_id(handle)!`, `git_reference_name(handle)!`) rely on implicit libgit2 contracts. Add a one-line comment at each site explaining the non-NULL guarantee.
- [ ] **ThreadSanitizer in CI.** Spec §9.4 lists this as an unaddressed test-coverage gap. Worth wiring once GitHub Actions is set up (see #3 above).
- [ ] **CHANGELOG.md** for v0.1.0 → v0.2.0, covering the module rename, iOS bump, and new API surface.
