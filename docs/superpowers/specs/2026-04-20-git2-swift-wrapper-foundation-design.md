# Git2 Swift Wrapper — Foundation & v0.2.0 First Slice

**Status:** Draft
**Date:** 2026-04-20
**Scope:** Foundational architecture for the Swift wrapper over libgit2 (`Cgit2`), plus the minimal v0.2.0 first slice of the public API.

## 1. Purpose

`libgit2.swift` v0.1.0 shipped the `Cgit2` XCFramework and exposes only `@_exported import Cgit2`. This spec defines the idiomatic Swift layer on top of it.

The wrapper's long-term goal is a **general-purpose Git client API** covering commit, branch, merge, rebase, and remote (HTTPS) operations. SSH is explicitly deferred (tracked in `TODO.md`).

This spec is focused and deliberately small:

1. The foundational decisions that every future slice must honor (error model, resource ownership, concurrency, bootstrap lifecycle, module layout).
2. The **v0.2.0 first slice**: the narrowest public surface that lets a user open a repository, resolve HEAD, and walk commit history (`Repository.open(at:)` → `Repository.head()` → `Repository.log(from:)`).

Later slices (read-extensions in v0.3, write operations in v0.4+, remote operations in v0.5+) are out of scope here and will each get their own spec.

## 2. Target Platforms

- **Apple platforms only.** `Cgit2` binary target is an XCFramework with macOS / iOS / iOS Simulator / Mac Catalyst slices. Linux / Windows / Android are non-goals.
- **macOS 13+**, **iOS 16+**.
  - iOS is raised from 15 (v0.1.0) to 16 to allow the use of `OSAllocatedUnfairLock<State>`.
- **Swift 6.2** (already the current toolchain in `Package.swift`).

## 3. Package Layout

### 3.1 `Package.swift`

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Git2",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "Git2", targets: ["Git2"]),
    ],
    targets: [
        .binaryTarget(
            name: "Cgit2",
            url: "https://github.com/k-ymmt/libgit2.swift/releases/download/v0.1.0/libgit2.xcframework.zip",
            checksum: "31f84a90e9fa8887b4e45280d01a1ca06b8c2134293dbaf30b627ec2094db46b"
        ),
        .target(
            name: "Git2",
            dependencies: ["Cgit2"],
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("GSS"),
                .linkedLibrary("z"),
                .linkedLibrary("iconv"),
            ]
        ),
        .testTarget(name: "Git2Tests", dependencies: ["Git2"]),
    ]
)
```

Key changes from v0.1.0:

- Package / product / target all rename to **`Git2`**.
- iOS minimum raised **15 → 16**.
- `Cgit2` binary target URL / checksum unchanged (libgit2 itself is not rebuilt for v0.2.0).

### 3.2 Source directory

```
Sources/Git2/
├── Git2.swift                 // @_exported import Cgit2
├── Runtime/
│   ├── Git.swift              // public enum Git { bootstrap/shutdown/version/isBootstrapped }
│   └── GitRuntime.swift       // internal bootstrap refcount
├── Errors/
│   ├── GitError.swift         // public struct GitError (+ Code, Class)
│   └── GitError+Mapping.swift // internal libgit2-last-error → GitError
├── Values/
│   ├── OID.swift
│   ├── Signature.swift
│   └── Version.swift
├── Repository/
│   ├── Repository.swift
│   └── Repository+Log.swift   // log() + CommitSequence / CommitIterator
├── References/
│   └── Reference.swift
├── Commit/
│   └── Commit.swift
└── Internal/
    ├── HandleLock.swift       // OSAllocatedUnfairLock wrapper
    ├── RevWalkHandle.swift    // internal wrapper over git_revwalk
    ├── CString.swift          // UnsafePointer<CChar> <-> String helpers
    └── Check.swift            // check(_ Int32) throws(GitError)
```

Top-level types (`Repository`, `Reference`, `Commit`, `OID`, `Signature`, `GitError`, `Version`) sit directly in the `Git2` module. Only the lifecycle API is namespaced under the caseless enum `Git` (`Git.bootstrap()`).

`@_exported import Cgit2` keeps low-level access available from `import Git2` for users who need to drop down to the C API.

### 3.3 Tests directory

```
Tests/Git2Tests/
├── Support/
│   ├── TestFixture.swift        // makeLinearHistory / makeMergeHistory
│   ├── TemporaryDirectory.swift // withTemporaryDirectory { url in ... }
│   └── (no /usr/bin/git spawn)
├── Runtime/
│   └── GitLifecycleTests.swift
├── Values/
│   ├── OIDTests.swift
│   └── SignatureTests.swift
├── Errors/
│   └── GitErrorTests.swift
├── Repository/
│   ├── RepositoryOpenTests.swift
│   ├── RepositoryHeadTests.swift
│   └── RepositoryLogTests.swift
├── Reference/
│   └── ReferenceTests.swift
└── Commit/
    └── CommitTests.swift
```

Fixtures are built with libgit2 itself through an internal-only repository builder. `/usr/bin/git` is deliberately not invoked from tests.

## 4. Error Model

A single struct captures every libgit2 error. Both the error code and the error class are surfaced as Swift enums with a forward-compatible `unknown` fallback.

```swift
public struct GitError: Error, Sendable, Equatable, CustomStringConvertible {
    public let code: Code
    public let `class`: Class
    public let message: String

    public var description: String {
        "GitError(\(code), \(`class`)): \(message)"
    }

    public enum Code: Sendable, Equatable {
        case ok, notFound, exists, ambiguous, bufferTooShort, user
        case barelyRepo, unbornBranch, unmerged, nonFastForward, invalidSpec
        case conflict, locked, modified, auth, certificate, applied, peel
        case endOfFile, invalid, uncommitted, directory, mergeConflict
        case passthrough, iterationOver, retry, mismatch, indexDirty
        case applyFail, owner, timeout, unchanged, notSupported, readOnly
        /// Any libgit2 code not mapped to a specific case above. Forward-compatible.
        case unknown(Int32)
    }

    public enum Class: Sendable, Equatable {
        case none, noMemory, os, invalid, reference, zlib, repository, config
        case regex, odb, index, object, net, tag, tree, indexer, ssl, submodule
        case thread, stash, checkout, fetchHead, merge, ssh, filter, revert
        case callback, cherrypick, describe, rebase, filesystem, patch
        case worktree, sha, http, `internal`, grafts
        case unknown(Int32)
    }
}
```

### 4.1 Design rules

- **Typed throws.** Every public API that can fail uses `throws(GitError)`. Call sites get static type narrowing; `catch let e as GitError` is never needed at the API boundary.
- **Forward compatibility.** Neither `Code` nor `Class` is `@frozen`. New libgit2 codes are absorbed into `.unknown(Int32)` without rebuild.
- **No `LocalizedError`.** libgit2 messages are English-only; localization is the caller's concern.
- **`GIT_ITEROVER` is not an error.** It signals normal iterator termination and is consumed inside `CommitIterator.next()` (returns nil).
- **`Equatable` on errors.** Tests can assert on code and class; message comparison is avoided in practice because libgit2 messages are environment-dependent.

### 4.2 Internal mapping

```swift
@inline(__always)
internal func check(_ result: Int32) throws(GitError) {
    guard result < 0 else { return }
    throw GitError.fromLibgit2(result)
}

extension GitError {
    internal static func fromLibgit2(_ result: Int32) -> GitError {
        let raw = git_error_last()
        let message = raw.map { String(cString: $0.pointee.message) } ?? ""
        let klass   = raw.map { Class.from(Int32($0.pointee.klass)) } ?? .none
        let code    = Code.from(result)
        return GitError(code: code, class: klass, message: message)
    }
}
```

`Code.from(Int32)` and `Class.from(Int32)` switch on the raw libgit2 constants from `git2/errors.h` (libgit2 1.9.x is the pinned version). Any unrecognized value folds into `.unknown(rawValue)`.

## 5. Resource Ownership and Concurrency

### 5.1 Ownership model (hybrid class + struct)

- **Handle types are `final class`.** Each holds one libgit2 handle and frees it in `deinit`:
  `Repository`, `Reference`, `Commit`. Future: `Tree`, `Blob`, `Tag`, `Index`, `ObjectDatabase`.
- **Value types are `struct`.** They copy libgit2 data into Swift and do not retain a handle:
  `OID`, `Signature`, `Version`, `GitError`.

### 5.2 Parent-child lifetime

Child objects (`Reference`, `Commit`, ...) hold a **strong reference to their owning `Repository`**. This keeps the parent alive for as long as any child exists, eliminating dangling handles at the cost of slightly extended `Repository` lifetime (acceptable in practice — one `Repository` per open repo, typically application-scoped).

```swift
public final class Commit: @unchecked Sendable {
    internal let handle: OpaquePointer      // git_commit *
    public let repository: Repository        // strong back-reference
    internal init(handle: OpaquePointer, repository: Repository) { ... }
    deinit { git_commit_free(handle) }
}
```

### 5.3 Concurrency & `Sendable`

- libgit2 must be built with `GIT_OPT_ENABLE_THREADS = 1`. `Git.bootstrap()` sets this unconditionally.
- Individual handles are not thread-safe. The wrapper serializes all access per `Repository`.
- **One `OSAllocatedUnfairLock<Void>` per `Repository`.** All libgit2 calls involving that repository — including calls through its children — take the repository's lock.
- Handle classes (`Repository`, `Reference`, `Commit`) are `@unchecked Sendable`; correctness is established by the locking rules below, not by the compiler.
- Value types (`OID`, `Signature`, `Version`, `GitError`) are naturally `Sendable`.
- Iterators (`CommitIterator`, `CommitSequence`) are **not** `Sendable` — they hold a mutable libgit2 `git_revwalk` state.

### 5.4 Locking rules (enforced by convention in v0.2, may be enforced structurally in a later version)

1. Every libgit2 call site runs **inside `Repository.lock.withLock { ... }`**.
2. Operations on a child (`Reference.shorthand`, `Commit.summary`, ...) take **the parent Repository's lock**, not a child-local lock.
3. Never `await` inside `withLock`. No suspension points within a lock region.
4. Don't re-enter the same `Repository` from a libgit2 callback. v0.2 exposes no callback-taking APIs, so this is theoretical for now.
5. `@unchecked Sendable` on handle classes is a contract: correctness is maintained by the lock discipline above.

### 5.5 `HandleLock` wrapper

```swift
internal struct HandleLock: Sendable {
    private let backing: OSAllocatedUnfairLock<Void>

    init() { backing = OSAllocatedUnfairLock() }

    @inline(__always)
    func withLock<T, E: Error>(_ body: () throws(E) -> T) throws(E) -> T {
        try backing.withLock { try body() }
    }
}
```

A thin wrapper around `OSAllocatedUnfairLock` so the lock primitive can evolve (e.g. future debug-only deadlock detection) without touching call sites.

## 6. Lifecycle (`Git`)

Bootstrap is **explicit**. Forgetting to call `Git.bootstrap()` is a programmer error and trips a `preconditionFailure`.

### 6.1 Public API

```swift
public enum Git {
    /// Initializes libgit2. Safe to call multiple times (reference-counted).
    /// Also enables libgit2 threading (`GIT_OPT_ENABLE_THREADS = 1`).
    public static func bootstrap() throws(GitError)

    /// Releases one bootstrap reference. The final matching call fully shuts libgit2 down.
    /// A shutdown without a matching bootstrap is a no-op.
    public static func shutdown() throws(GitError)

    public static var isBootstrapped: Bool { get }

    /// The libgit2 runtime version. Available even before `bootstrap()`.
    public static var version: Version { get }
}
```

### 6.2 Internal implementation

```swift
internal final class GitRuntime: @unchecked Sendable {
    static let shared = GitRuntime()
    private let lock = OSAllocatedUnfairLock<Int>(initialState: 0)

    func bootstrap() throws(GitError) {
        try lock.withLock { (state: inout Int) throws(GitError) in
            if state == 0 {
                try check(git_libgit2_init())
                try check(git_libgit2_opts(GIT_OPT_ENABLE_THREADS, Int32(1)))
            }
            state += 1
        }
    }

    func shutdown() throws(GitError) {
        try lock.withLock { (state: inout Int) throws(GitError) in
            guard state > 0 else { return }
            try check(git_libgit2_shutdown())
            state -= 1
        }
    }

    var isBootstrapped: Bool { lock.withLock { $0 > 0 } }

    func requireBootstrapped(
        function: StaticString = #function, file: StaticString = #file, line: UInt = #line
    ) {
        precondition(
            isBootstrapped,
            "Git.bootstrap() must be called before using \(function).",
            file: file, line: line
        )
    }
}
```

### 6.3 Enforcement at API boundaries

The **public entry points** (`Repository.open(at:)`) call `GitRuntime.shared.requireBootstrapped()` before any libgit2 work. Deeper layers do not re-check.

## 7. Values

### 7.1 `Version`

```swift
public struct Version: Sendable, Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public static var current: Version {
        var maj: Int32 = 0, min: Int32 = 0, pat: Int32 = 0
        _ = git_libgit2_version(&maj, &min, &pat)
        return Version(major: Int(maj), minor: Int(min), patch: Int(pat))
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String { "\(major).\(minor).\(patch)" }
}
```

### 7.2 `OID`

SHA-1 only in v0.2. SHA-256 (tracked in `TODO.md` via `EXPERIMENTAL_SHA256`) is out of scope.

```swift
public struct OID: Sendable, Hashable, CustomStringConvertible {
    public static let length = 20   // SHA-1 bytes

    internal let raw: git_oid

    public init(hex: String) throws(GitError) {
        var oid = git_oid()
        try hex.withCString { cstr in
            try check(git_oid_fromstr(&oid, cstr))
        }
        self.raw = oid
    }

    internal init(raw: git_oid) { self.raw = raw }

    public var hex: String {
        var buffer = [CChar](repeating: 0, count: 41)
        withUnsafePointer(to: raw) { p in
            _ = git_oid_tostr(&buffer, 41, p)
        }
        return String(cString: buffer)
    }

    public var description: String { hex }

    public static func == (lhs: OID, rhs: OID) -> Bool {
        withUnsafePointer(to: lhs.raw) { l in
            withUnsafePointer(to: rhs.raw) { r in
                git_oid_equal(l, r) != 0
            }
        }
    }

    public func hash(into hasher: inout Hasher) {
        withUnsafePointer(to: raw) { p in
            let bytes = UnsafeRawBufferPointer(start: p, count: MemoryLayout<git_oid>.size)
            hasher.combine(bytes: bytes)
        }
    }
}
```

### 7.3 `Signature`

```swift
public struct Signature: Sendable, Equatable {
    public let name: String
    public let email: String
    public let date: Date
    public let timeZone: TimeZone

    internal init(copyingFrom raw: UnsafePointer<git_signature>) {
        self.name = String(cString: raw.pointee.name)
        self.email = String(cString: raw.pointee.email)
        self.date = Date(timeIntervalSince1970: TimeInterval(raw.pointee.when.time))
        self.timeZone = TimeZone(secondsFromGMT: Int(raw.pointee.when.offset) * 60)
            ?? TimeZone(secondsFromGMT: 0)!
    }
}
```

`git_signature *` is a pointer into commit memory; its lifetime is tied to the parent commit. Copying into a Swift value type detaches it safely.

## 8. v0.2.0 First-Slice Public API

### 8.1 `Repository`

```swift
public final class Repository: @unchecked Sendable {
    // Opening

    /// Opens an existing repository.
    /// Accepts either a directory containing `.git` or the root of a bare repository.
    public static func open(at url: URL) throws(GitError) -> Repository

    // Properties

    /// The working directory, or `nil` for bare repositories.
    public var workingDirectory: URL? { get }

    /// The `.git` directory (or the repository root for bare repositories).
    public var gitDirectory: URL { get }

    public var isBare: Bool { get }

    /// True if HEAD has no commits yet (empty branch).
    public var isHeadUnborn: Bool { get }

    // HEAD / references

    /// Resolves HEAD. Throws `GitError(.unbornBranch, ...)` on an unborn branch.
    public func head() throws(GitError) -> Reference

    // Commit lookup

    /// Looks up a commit by its OID.
    public func commit(for oid: OID) throws(GitError) -> Commit

    // Log

    /// Returns a sequence of commits reachable from `start`, walking toward ancestors.
    /// Default ordering is the libgit2 `GIT_SORT_NONE` insertion order.
    /// The sequence can be iterated multiple times; each `makeIterator()` creates a fresh revwalk.
    public func log(from start: Commit) -> CommitSequence
}
```

### 8.2 `Reference`

```swift
public final class Reference: @unchecked Sendable {
    public let repository: Repository

    /// Full reference name, e.g. `refs/heads/main`, `refs/tags/v1.0`, `HEAD`.
    public var name: String { get }

    /// Short reference name, e.g. `main`, `v1.0`.
    public var shorthand: String { get }

    /// The OID the reference points at. Symbolic references are resolved first.
    public var target: OID { get throws(GitError) }

    /// Resolves to a commit, peeling through tags as needed.
    public func resolveToCommit() throws(GitError) -> Commit
}
```

### 8.3 `Commit`

```swift
public final class Commit: @unchecked Sendable {
    public let repository: Repository

    public var oid: OID { get }
    public var message: String { get }

    /// The first line of the commit message.
    public var summary: String { get }

    /// The commit message body after the summary, or `nil` if absent.
    public var body: String? { get }

    public var author: Signature { get }
    public var committer: Signature { get }

    /// Number of parent commits. O(1) — does not hit the ODB.
    public var parentCount: Int { get }

    /// Resolves all parent commits. Looks them up in the ODB on call.
    public func parents() throws(GitError) -> [Commit]
}
```

### 8.4 `CommitSequence` / `CommitIterator`

```swift
public struct CommitSequence: Sequence {
    public typealias Element = Commit

    internal let repository: Repository
    internal let startOID: OID

    public func makeIterator() -> CommitIterator {
        CommitIterator(repository: repository, startOID: startOID)
    }
}

public struct CommitIterator: IteratorProtocol {
    public typealias Element = Commit

    internal init(repository: Repository, startOID: OID)

    /// Returns the next commit, or `nil` when the walk completes or fails.
    /// `GIT_ITEROVER` terminates the walk normally. Other errors during walking
    /// (ODB corruption, etc.) also terminate the iterator; callers who need to
    /// distinguish "done" from "failed" should wait for the v0.3 `RevWalk` type.
    public mutating func next() -> Commit?
}
```

### 8.5 Usage sketch

```swift
import Git2

try Git.bootstrap()
defer { try? Git.shutdown() }

let repo = try Repository.open(at: URL(filePath: "/path/to/repo"))
let head = try repo.head()
let tip  = try head.resolveToCommit()

for commit in repo.log(from: tip).prefix(10) {
    print(commit.oid.hex.prefix(7), commit.author.name, commit.summary)
}
```

### 8.6 API design notes

- `Repository.log(from: Commit)` takes a `Commit` rather than an `OID`. The type itself certifies validity; callers with an OID in hand write `repo.log(from: try repo.commit(for: oid))`.
- `Reference.target` is a throwing **computed property**, not a method. libgit2's lookup here is lightweight.
- `Commit.parents()` is a **method** because each call hits the ODB for every parent. The non-throwing `parentCount` property gives the arity without a lookup.
- `CommitSequence` does not expose a sorting option in v0.2. It will gain a `log(from:sorting:)` overload in v0.3 alongside a public `RevWalk` type.

## 9. Tests

### 9.1 Framework

`swift-testing` (`@Test` / `#expect`) — already in use since v0.1.0.

### 9.2 Fixture strategy

`TestFixture` creates repositories using libgit2 itself through an **internal-only** repository builder (which will be generalized into the public commit/branch creation API in v0.4). `/usr/bin/git` is not invoked.

```swift
struct TestFixture {
    let repositoryURL: URL

    static func makeLinearHistory(
        commits: [(message: String, author: Signature)],
        in directory: URL
    ) throws -> TestFixture

    static func makeMergeHistory(in directory: URL) throws -> TestFixture
}

func withTemporaryDirectory<T>(_ body: (URL) throws -> T) rethrows -> T
```

### 9.3 Coverage in v0.2

- `Git.bootstrap` / `shutdown` / multi-call symmetry / `version`.
- `Repository.open` — success, non-existent path, non-Git directory.
- `Repository.head` — normal, unborn → `.unbornBranch`.
- `Reference.shorthand` / `resolveToCommit` — direct reference (tag peeling is untested; tags are out of scope in v0.2).
- `Commit.summary` / `message` / `author` / `parentCount` / `parents()` — linear history and a 2-parent merge.
- `Repository.log(from:)` — linear, merge, and empty repository (throws).
- `OID(hex:)` — valid hex, wrong length, non-hex characters.
- `GitError` — `.notFound`, `.exists`, `.unbornBranch` mappings.

### 9.4 Not covered in v0.2 (tracked in `TODO.md`)

- Performance benchmarks.
- Cross-thread data race detection under ThreadSanitizer (CI wiring is its own task).
- iOS execution (macOS-only for v0.2, consistent with v0.1.0).

## 10. Scope Boundaries

### 10.1 Included in v0.2.0

| Area | API |
|---|---|
| Lifecycle | `Git.bootstrap()` / `shutdown()` / `isBootstrapped` / `version` |
| Values | `OID`, `Signature`, `Version`, `GitError`, `GitError.Code`, `GitError.Class` |
| Repository | `open(at:)`, `workingDirectory`, `gitDirectory`, `isBare`, `isHeadUnborn`, `head()`, `commit(for:)`, `log(from:)` |
| Reference | `name`, `shorthand`, `target`, `resolveToCommit()` |
| Commit | `oid`, `message`, `summary`, `body`, `author`, `committer`, `parentCount`, `parents()` |
| Sequence | `CommitSequence`, `CommitIterator` (no sorting option) |
| Module | `Git2` target/product; `Cgit2` retained; `@_exported import Cgit2` |

### 10.2 Deferred (future slices; not committed to specific versions)

| Feature | Likely phase | Reason for deferral |
|---|---|---|
| `Repository.discover(startingAt:)` | v0.3 | Not needed for the minimum first-slice path |
| `Repository.references` / `reference(named:)` | v0.3 | Read extensions |
| `Tree` / `Blob` / `Tag` / `Object` enum | v0.3 | Read extensions |
| `Diff` (tree-to-tree, file-level) | v0.3 | Read extensions |
| `CommitSequence.Sorting` (topological / time / reverse) | v0.3 | Added via `log(from:sorting:)` overload |
| Public `RevWalk` (`hide`, `pushRef`, `simplifyFirstParent`, ...) | v0.3+ | Advanced revwalk control |
| Commit creation, branch/tag creation, index staging | v0.4 | Write operations |
| Merge / rebase / cherry-pick | v0.5+ | Deep write operations |
| Remote / fetch / push (HTTPS; auth via callbacks) | v0.5+ | Network layer |
| SSH support (add `libssh2` XCFramework) | `TODO.md` | v0.1.0 follow-up task |
| SHA-256 repositories | `TODO.md` | Requires `EXPERIMENTAL_SHA256` in libgit2 |
| Linux / Windows / Android | — | `Cgit2` is Apple-only |

### 10.3 Explicit non-goals

- No shipped CLI (`swift run git2 ...`).
- No 1:1 exposure of every libgit2 function; low-level access is via `Cgit2`.
- No Linux / Windows / Android support.
- No Keychain / credential-UI integration; v0.5+ remote operations will expose callback hooks only.

## 11. Migration from v0.1.0

| Change | Action |
|---|---|
| Package / product / target renamed `libgit2.swift` → `Git2` | Update `import libgit2_swift` → `import Git2` and `.product(name: "libgit2.swift", ...)` → `.product(name: "Git2", ...)`. Repository URL (`.package(url: "...libgit2.swift.git", ...)`) is unchanged. |
| iOS minimum 15 → 16 | Update `.iOS(.v15)` → `.iOS(.v16)` in downstream `Package.swift`. |
| `@_exported import Cgit2` | Still transitively available via `import Git2`. Direct `.product(name: "Cgit2", ...)` consumers are unaffected. |
| `git_libgit2_init` / `shutdown` calls | Replace with `Git.bootstrap()` / `Git.shutdown()`. Mixing is technically safe (libgit2 reference-counts internally) but the `Git` API also ensures `GIT_OPT_ENABLE_THREADS = 1`. |

v0.x is treated as unstable per the SemVer `0.x` convention. Regular SemVer guarantees begin at v1.0.

## 12. libgit2 Build Options

No libgit2 rebuild is required for v0.2.0. The `Cgit2` binary target keeps v0.1.0's zip. Items from `TODO.md` (`EXPERIMENTAL_SHA256`, explicit `USE_I18N`, `USE_SSH=ON`) are unaffected by this spec.

## 13. Open Questions

None at the time of writing. Items that came up during brainstorming and were resolved:

- Resource ownership: hybrid (class handles + struct values).
- Parent-child lifetime: child holds a strong reference to the parent `Repository`.
- Error representation: single `GitError` struct with `Code` / `Class` enums (forward-compatible).
- Concurrency: `@unchecked Sendable` classes serialized by a per-`Repository` `OSAllocatedUnfairLock`.
- Lifecycle: explicit `Git.bootstrap()` / `shutdown()`; missing bootstrap trips `preconditionFailure`.
- Module name: `Git2`.
- First-slice scope: `open` → `head` → `log` (Sequence-based), no sorting options, no discover, no tag handling.
