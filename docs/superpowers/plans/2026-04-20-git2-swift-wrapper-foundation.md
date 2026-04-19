# Git2 Swift Wrapper Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the v0.2.0 Swift wrapper over `Cgit2`. Rename the module to `Git2`, establish the foundational layers (errors, lifecycle, lock, values), and expose the first-slice API (`Repository.open(at:)` → `Repository.head()` → `Repository.log(from:)`).

**Architecture:** One SwiftPM target `Git2` depending on the existing `Cgit2` binary target. Handle-owning types are `final class` freed in `deinit`; value types are `struct`. All libgit2 calls are serialized per `Repository` by an `OSAllocatedUnfairLock`. Errors are mapped from libgit2 into a single `struct GitError` with forward-compatible `Code` / `Class` enums, surfaced via typed throws (`throws(GitError)`). Tests use `swift-testing` with fixtures built directly through libgit2 (no `/usr/bin/git`).

**Tech Stack:** Swift 6.2, SwiftPM 6.2, `swift-testing`, `OSAllocatedUnfairLock` (`import os`), `Cgit2` binary target (libgit2 1.9.x), Foundation.

**Spec reference:** `docs/superpowers/specs/2026-04-20-git2-swift-wrapper-foundation-design.md`

---

## File Structure

**Created by this plan:**

```
Sources/Git2/
├── Git2.swift                 // @_exported import Cgit2
├── Runtime/
│   ├── Git.swift              // public enum Git
│   └── GitRuntime.swift       // internal bootstrap refcount
├── Errors/
│   ├── GitError.swift         // public struct GitError + Code + Class
│   └── GitError+Mapping.swift // Code.from / Class.from / fromLibgit2
├── Values/
│   ├── OID.swift
│   ├── Signature.swift
│   └── Version.swift
├── Repository/
│   ├── Repository.swift
│   └── Repository+Log.swift
├── References/
│   └── Reference.swift
├── Commit/
│   └── Commit.swift
└── Internal/
    ├── HandleLock.swift
    ├── RevWalkHandle.swift
    ├── CString.swift
    └── Check.swift

Tests/Git2Tests/
├── Support/
│   ├── TestFixture.swift
│   └── TemporaryDirectory.swift
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

**Removed by this plan:**

```
Sources/libgit2.swift/libgit2_swift.swift     // superseded by Sources/Git2/Git2.swift
Tests/libgit2.swiftTests/libgit2_swiftTests.swift  // superseded by Git2Tests/
```

---

## Task 1: Package rename (`libgit2.swift` → `Git2`) and platform bump

Mechanical move; no new behavior. Every later task assumes this is done.

**Files:**
- Modify: `Package.swift`
- Move: `Sources/libgit2.swift/` → `Sources/Git2/`
- Move: `Tests/libgit2.swiftTests/` → `Tests/Git2Tests/`

- [ ] **Step 1: Move the source and test directories**

```bash
git mv Sources/libgit2.swift Sources/Git2
git mv Sources/Git2/libgit2_swift.swift Sources/Git2/Git2.swift
git mv Tests/libgit2.swiftTests Tests/Git2Tests
git mv Tests/Git2Tests/libgit2_swiftTests.swift Tests/Git2Tests/SmokeTests.swift
```

- [ ] **Step 2: Rewrite `Package.swift`**

Replace the entire contents of `Package.swift` with:

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
        .library(
            name: "Git2",
            targets: ["Git2"]
        ),
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
        .testTarget(
            name: "Git2Tests",
            dependencies: ["Git2"]
        ),
    ]
)
```

- [ ] **Step 3: Update the renamed test file's import**

Open `Tests/Git2Tests/SmokeTests.swift` and replace its contents with:

```swift
import Testing
@testable import Git2

@Test
func initAndShutdown() {
    let initResult = git_libgit2_init()
    #expect(initResult >= 0)

    let shutdownResult = git_libgit2_shutdown()
    #expect(shutdownResult >= 0)
}

@Test
func reportsExpectedVersion() {
    var major: Int32 = 0
    var minor: Int32 = 0
    var rev: Int32 = 0
    _ = git_libgit2_version(&major, &minor, &rev)
    #expect(major == 1)
    #expect(minor == 9)
}
```

(The `import Cgit2` symbols are visible via `@_exported import Cgit2` from `Git2.swift`, so `@testable import Git2` is enough.)

- [ ] **Step 4: Verify the build + smoke tests pass**

Run:
```bash
swift build
swift test
```
Expected: build succeeds; both `initAndShutdown` and `reportsExpectedVersion` pass.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/Git2 Tests/Git2Tests
git commit -m "refactor: rename module libgit2.swift -> Git2, iOS 15 -> 16"
```

---

## Task 2: Internal lock wrapper (`HandleLock`)

**Files:**
- Create: `Sources/Git2/Internal/HandleLock.swift`
- Create: `Tests/Git2Tests/Support/HandleLockTests.swift` (test-only, using `@testable`)

- [ ] **Step 1: Write the failing test**

Create `Tests/Git2Tests/Support/HandleLockTests.swift`:

```swift
import Testing
@testable import Git2

@Test
func handleLockSerializesIncrements() async {
    let lock = HandleLock()
    nonisolated(unsafe) var counter = 0

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<1_000 {
            group.addTask {
                lock.withLock { counter += 1 }
            }
        }
    }

    #expect(counter == 1_000)
}

@Test
func handleLockPropagatesTypedThrow() {
    struct Boom: Error, Equatable {}
    let lock = HandleLock()

    #expect(throws: Boom.self) {
        try lock.withLock { () throws(Boom) -> Void in
            throw Boom()
        }
    }
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run:
```bash
swift test --filter HandleLock
```
Expected: compile error — `HandleLock` not defined.

- [ ] **Step 3: Implement `HandleLock`**

Create `Sources/Git2/Internal/HandleLock.swift`:

```swift
import os

internal struct HandleLock: Sendable {
    private let backing: OSAllocatedUnfairLock<Void>

    init() {
        self.backing = OSAllocatedUnfairLock()
    }

    @inline(__always)
    func withLock<T, E: Error>(_ body: () throws(E) -> T) throws(E) -> T {
        try backing.withLock { try body() }
    }
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run:
```bash
swift test --filter HandleLock
```
Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Git2/Internal/HandleLock.swift Tests/Git2Tests/Support/HandleLockTests.swift
git commit -m "feat(internal): add HandleLock over OSAllocatedUnfairLock"
```

---

## Task 3: `Version` value type

**Files:**
- Create: `Sources/Git2/Values/Version.swift`
- Create: `Tests/Git2Tests/Values/VersionTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Git2Tests/Values/VersionTests.swift`:

```swift
import Testing
@testable import Git2

@Test
func versionCurrentReturnsLibgit2Major1Minor9() {
    let v = Version.current
    #expect(v.major == 1)
    #expect(v.minor == 9)
    #expect(v.patch >= 0)
}

@Test
func versionDescription() {
    let v = Version(major: 1, minor: 9, patch: 3)
    #expect(v.description == "1.9.3")
}

@Test
func versionOrdering() {
    #expect(Version(major: 1, minor: 9, patch: 0) < Version(major: 1, minor: 9, patch: 1))
    #expect(Version(major: 1, minor: 8, patch: 9) < Version(major: 1, minor: 9, patch: 0))
    #expect(Version(major: 1, minor: 9, patch: 0) == Version(major: 1, minor: 9, patch: 0))
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:
```bash
swift test --filter Version
```
Expected: compile error — `Version` not defined.

- [ ] **Step 3: Implement `Version`**

Create `Sources/Git2/Values/Version.swift`:

```swift
import Cgit2

public struct Version: Sendable, Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static var current: Version {
        var maj: Int32 = 0
        var min: Int32 = 0
        var pat: Int32 = 0
        _ = git_libgit2_version(&maj, &min, &pat)
        return Version(major: Int(maj), minor: Int(min), patch: Int(pat))
    }

    public static func < (lhs: Version, rhs: Version) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run:
```bash
swift test --filter Version
```
Expected: all three tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Git2/Values/Version.swift Tests/Git2Tests/Values/VersionTests.swift
git commit -m "feat: add Version value type"
```

---

## Task 4: `GitError` struct and enums

`GitError` has no logic yet beyond storage, `Equatable`, and `CustomStringConvertible`. The mapping from libgit2 raw codes comes in Task 5.

**Files:**
- Create: `Sources/Git2/Errors/GitError.swift`
- Create: `Tests/Git2Tests/Errors/GitErrorTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Git2Tests/Errors/GitErrorTests.swift`:

```swift
import Testing
@testable import Git2

@Test
func gitErrorEqualityIgnoresNothing() {
    let a = GitError(code: .notFound, class: .reference, message: "hi")
    let b = GitError(code: .notFound, class: .reference, message: "hi")
    let c = GitError(code: .notFound, class: .reference, message: "different")
    #expect(a == b)
    #expect(a != c)
}

@Test
func gitErrorDescriptionIncludesAllFields() {
    let e = GitError(code: .notFound, class: .reference, message: "no ref")
    #expect(e.description == "GitError(notFound, reference): no ref")
}

@Test
func gitErrorCodeUnknownIsDistinctPerRawValue() {
    #expect(GitError.Code.unknown(7) != GitError.Code.unknown(8))
    #expect(GitError.Code.unknown(7) == GitError.Code.unknown(7))
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:
```bash
swift test --filter GitError
```
Expected: compile error — `GitError` not defined.

- [ ] **Step 3: Implement `GitError`**

Create `Sources/Git2/Errors/GitError.swift`:

```swift
public struct GitError: Error, Sendable, Equatable, CustomStringConvertible {
    public let code: Code
    public let `class`: Class
    public let message: String

    public init(code: Code, class: Class, message: String) {
        self.code = code
        self.class = `class`
        self.message = message
    }

    public var description: String {
        "GitError(\(code), \(`class`)): \(message)"
    }

    public enum Code: Sendable, Equatable {
        case ok
        case notFound
        case exists
        case ambiguous
        case bufferTooShort
        case user
        case barelyRepo
        case unbornBranch
        case unmerged
        case nonFastForward
        case invalidSpec
        case conflict
        case locked
        case modified
        case auth
        case certificate
        case applied
        case peel
        case endOfFile
        case invalid
        case uncommitted
        case directory
        case mergeConflict
        case passthrough
        case iterationOver
        case retry
        case mismatch
        case indexDirty
        case applyFail
        case owner
        case timeout
        case unchanged
        case notSupported
        case readOnly
        case unknown(Int32)
    }

    public enum Class: Sendable, Equatable {
        case none
        case noMemory
        case os
        case invalid
        case reference
        case zlib
        case repository
        case config
        case regex
        case odb
        case index
        case object
        case net
        case tag
        case tree
        case indexer
        case ssl
        case submodule
        case thread
        case stash
        case checkout
        case fetchHead
        case merge
        case ssh
        case filter
        case revert
        case callback
        case cherrypick
        case describe
        case rebase
        case filesystem
        case patch
        case worktree
        case sha
        case http
        case `internal`
        case grafts
        case unknown(Int32)
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run:
```bash
swift test --filter GitError
```
Expected: all three tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Git2/Errors/GitError.swift Tests/Git2Tests/Errors/GitErrorTests.swift
git commit -m "feat: add GitError struct with Code and Class enums"
```

---

## Task 5: libgit2 → `GitError` mapping and `check(_:)` helper

This is where raw libgit2 return codes become `GitError` values.

**Files:**
- Create: `Sources/Git2/Errors/GitError+Mapping.swift`
- Create: `Sources/Git2/Internal/Check.swift`
- Modify: `Tests/Git2Tests/Errors/GitErrorTests.swift`

- [ ] **Step 1: Append integration tests that exercise mapping**

Append to `Tests/Git2Tests/Errors/GitErrorTests.swift`:

```swift
import Cgit2

@Test
func codeFromMapsKnownLibgit2Constants() {
    #expect(GitError.Code.from(GIT_OK.rawValue) == .ok)
    #expect(GitError.Code.from(GIT_ENOTFOUND.rawValue) == .notFound)
    #expect(GitError.Code.from(GIT_EEXISTS.rawValue) == .exists)
    #expect(GitError.Code.from(GIT_EUNBORNBRANCH.rawValue) == .unbornBranch)
    #expect(GitError.Code.from(GIT_EINVALIDSPEC.rawValue) == .invalidSpec)
    #expect(GitError.Code.from(GIT_ITEROVER.rawValue) == .iterationOver)
}

@Test
func codeFromFallsThroughToUnknown() {
    // Pick an Int32 that's not a libgit2 code.
    #expect(GitError.Code.from(-9999) == .unknown(-9999))
}

@Test
func classFromMapsKnownLibgit2Classes() {
    #expect(GitError.Class.from(Int32(GIT_ERROR_NONE.rawValue)) == .none)
    #expect(GitError.Class.from(Int32(GIT_ERROR_REFERENCE.rawValue)) == .reference)
    #expect(GitError.Class.from(Int32(GIT_ERROR_ODB.rawValue)) == .odb)
}

@Test
func fromLibgit2ProducesUnknownWhenNoErrorIsSet() {
    git_error_clear()
    let error = GitError.fromLibgit2(-9999)
    #expect(error.code == .unknown(-9999))
    #expect(error.class == .none)
    #expect(error.message.isEmpty)
}

@Test
func classFromFallsThroughToUnknown() {
    #expect(GitError.Class.from(9999) == .unknown(9999))
}

@Test
func checkReturnsOnSuccess() throws {
    try check(0)
    try check(1)
    try check(Int32.max)
}

@Test
func checkThrowsOnFailure() {
    // Force a real libgit2 error (invalid OID hex) before calling check.
    var oid = git_oid()
    let result = git_oid_fromstr(&oid, "not-a-real-oid-string")
    #expect(result < 0)

    var thrown: GitError?
    do {
        try check(result)
    } catch let e as GitError {
        thrown = e
    } catch {
        Issue.record("unexpected error type")
    }

    #expect(thrown?.code == .invalid || thrown?.code == .ambiguous || thrown?.code == .invalidSpec)
    #expect(thrown?.message.isEmpty == false)
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:
```bash
swift test --filter GitError
```
Expected: compile error — `GitError.Code.from`, `GitError.Class.from`, and `check` not defined.

- [ ] **Step 3: Implement the mapping**

Create `Sources/Git2/Errors/GitError+Mapping.swift`:

```swift
import Cgit2

extension GitError.Code {
    internal static func from(_ raw: Int32) -> GitError.Code {
        switch raw {
        case GIT_OK.rawValue:             return .ok
        case GIT_ERROR.rawValue:          return .unknown(raw)
        case GIT_ENOTFOUND.rawValue:      return .notFound
        case GIT_EEXISTS.rawValue:        return .exists
        case GIT_EAMBIGUOUS.rawValue:     return .ambiguous
        case GIT_EBUFS.rawValue:          return .bufferTooShort
        case GIT_EUSER.rawValue:          return .user
        case GIT_EBAREREPO.rawValue:      return .barelyRepo
        case GIT_EUNBORNBRANCH.rawValue:  return .unbornBranch
        case GIT_EUNMERGED.rawValue:      return .unmerged
        case GIT_ENONFASTFORWARD.rawValue: return .nonFastForward
        case GIT_EINVALIDSPEC.rawValue:   return .invalidSpec
        case GIT_ECONFLICT.rawValue:      return .conflict
        case GIT_ELOCKED.rawValue:        return .locked
        case GIT_EMODIFIED.rawValue:      return .modified
        case GIT_EAUTH.rawValue:          return .auth
        case GIT_ECERTIFICATE.rawValue:   return .certificate
        case GIT_EAPPLIED.rawValue:       return .applied
        case GIT_EPEEL.rawValue:          return .peel
        case GIT_EEOF.rawValue:           return .endOfFile
        case GIT_EINVALID.rawValue:       return .invalid
        case GIT_EUNCOMMITTED.rawValue:   return .uncommitted
        case GIT_EDIRECTORY.rawValue:     return .directory
        case GIT_EMERGECONFLICT.rawValue: return .mergeConflict
        case GIT_PASSTHROUGH.rawValue:    return .passthrough
        case GIT_ITEROVER.rawValue:       return .iterationOver
        case GIT_RETRY.rawValue:          return .retry
        case GIT_EMISMATCH.rawValue:      return .mismatch
        case GIT_EINDEXDIRTY.rawValue:    return .indexDirty
        case GIT_EAPPLYFAIL.rawValue:     return .applyFail
        case GIT_EOWNER.rawValue:         return .owner
        case GIT_TIMEOUT.rawValue:        return .timeout
        case GIT_EUNCHANGED.rawValue:     return .unchanged
        case GIT_ENOTSUPPORTED.rawValue:  return .notSupported
        case GIT_EREADONLY.rawValue:      return .readOnly
        default:                          return .unknown(raw)
        }
    }
}

extension GitError.Class {
    internal static func from(_ raw: Int32) -> GitError.Class {
        switch raw {
        case Int32(GIT_ERROR_NONE.rawValue):       return .none
        case Int32(GIT_ERROR_NOMEMORY.rawValue):   return .noMemory
        case Int32(GIT_ERROR_OS.rawValue):         return .os
        case Int32(GIT_ERROR_INVALID.rawValue):    return .invalid
        case Int32(GIT_ERROR_REFERENCE.rawValue):  return .reference
        case Int32(GIT_ERROR_ZLIB.rawValue):       return .zlib
        case Int32(GIT_ERROR_REPOSITORY.rawValue): return .repository
        case Int32(GIT_ERROR_CONFIG.rawValue):     return .config
        case Int32(GIT_ERROR_REGEX.rawValue):      return .regex
        case Int32(GIT_ERROR_ODB.rawValue):        return .odb
        case Int32(GIT_ERROR_INDEX.rawValue):      return .index
        case Int32(GIT_ERROR_OBJECT.rawValue):     return .object
        case Int32(GIT_ERROR_NET.rawValue):        return .net
        case Int32(GIT_ERROR_TAG.rawValue):        return .tag
        case Int32(GIT_ERROR_TREE.rawValue):       return .tree
        case Int32(GIT_ERROR_INDEXER.rawValue):    return .indexer
        case Int32(GIT_ERROR_SSL.rawValue):        return .ssl
        case Int32(GIT_ERROR_SUBMODULE.rawValue):  return .submodule
        case Int32(GIT_ERROR_THREAD.rawValue):     return .thread
        case Int32(GIT_ERROR_STASH.rawValue):      return .stash
        case Int32(GIT_ERROR_CHECKOUT.rawValue):   return .checkout
        case Int32(GIT_ERROR_FETCHHEAD.rawValue):  return .fetchHead
        case Int32(GIT_ERROR_MERGE.rawValue):      return .merge
        case Int32(GIT_ERROR_SSH.rawValue):        return .ssh
        case Int32(GIT_ERROR_FILTER.rawValue):     return .filter
        case Int32(GIT_ERROR_REVERT.rawValue):     return .revert
        case Int32(GIT_ERROR_CALLBACK.rawValue):   return .callback
        case Int32(GIT_ERROR_CHERRYPICK.rawValue): return .cherrypick
        case Int32(GIT_ERROR_DESCRIBE.rawValue):   return .describe
        case Int32(GIT_ERROR_REBASE.rawValue):     return .rebase
        case Int32(GIT_ERROR_FILESYSTEM.rawValue): return .filesystem
        case Int32(GIT_ERROR_PATCH.rawValue):      return .patch
        case Int32(GIT_ERROR_WORKTREE.rawValue):   return .worktree
        case Int32(GIT_ERROR_SHA.rawValue):        return .sha
        case Int32(GIT_ERROR_HTTP.rawValue):       return .http
        case Int32(GIT_ERROR_INTERNAL.rawValue):   return .internal
        case Int32(GIT_ERROR_GRAFTS.rawValue):     return .grafts
        default:                                    return .unknown(raw)
        }
    }
}

extension GitError {
    internal static func fromLibgit2(_ result: Int32) -> GitError {
        let raw = git_error_last()
        let message: String
        let klass: Class
        if let raw {
            message = String(cString: raw.pointee.message)
            klass = Class.from(raw.pointee.klass)
        } else {
            message = ""
            klass = .none
        }
        return GitError(code: Code.from(result), class: klass, message: message)
    }
}
```

Create `Sources/Git2/Internal/Check.swift`:

```swift
import Cgit2

@inline(__always)
internal func check(_ result: Int32) throws(GitError) {
    guard result < 0 else { return }
    throw GitError.fromLibgit2(result)
}
```

- [ ] **Step 4: Build (to shake out any `GIT_ERROR_*` constants whose Swift names differ)**

Run:
```bash
swift build
```
Expected: succeeds. If any case label fails to resolve, the corresponding libgit2 1.9.x constant is spelled differently; replace the offending case with the correct Swift name (visible via `grep GIT_ERROR_ .build/checkouts/... ` or by inspecting `Cgit2`'s module map). Re-run until build succeeds.

- [ ] **Step 5: Run the tests and confirm they pass**

Run:
```bash
swift test --filter GitError
```
Expected: all mapping and `check` tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Git2/Errors/GitError+Mapping.swift Sources/Git2/Internal/Check.swift Tests/Git2Tests/Errors/GitErrorTests.swift
git commit -m "feat(errors): map libgit2 codes/classes into GitError + add check helper"
```

---

## Task 6: `OID` value type

**Files:**
- Create: `Sources/Git2/Values/OID.swift`
- Create: `Tests/Git2Tests/Values/OIDTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Git2Tests/Values/OIDTests.swift`:

```swift
import Testing
@testable import Git2

@Test
func oidRoundtripsHex() throws {
    let hex = "0123456789abcdef0123456789abcdef01234567"
    let oid = try OID(hex: hex)
    #expect(oid.hex == hex)
    #expect(oid.description == hex)
}

@Test
func oidLengthIs20() {
    #expect(OID.length == 20)
}

@Test
func oidEqualityIsByValue() throws {
    let a = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
    let b = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
    let c = try OID(hex: "fedcba9876543210fedcba9876543210fedcba98")
    #expect(a == b)
    #expect(a != c)
}

@Test
func oidIsHashable() throws {
    let a = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
    let b = try OID(hex: "0123456789abcdef0123456789abcdef01234567")
    var set = Set<OID>()
    set.insert(a)
    set.insert(b)
    #expect(set.count == 1)
}

@Test
func oidFromShortHexThrows() {
    #expect(throws: GitError.self) {
        _ = try OID(hex: "deadbeef")
    }
}

@Test
func oidFromNonHexThrows() {
    #expect(throws: GitError.self) {
        _ = try OID(hex: "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz")
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:
```bash
swift test --filter OID
```
Expected: compile error — `OID` not defined.

- [ ] **Step 3: Implement `OID`**

Create `Sources/Git2/Values/OID.swift`:

```swift
import Cgit2

public struct OID: Sendable, Hashable, CustomStringConvertible {
    public static let length = 20

    internal let raw: git_oid

    public init(hex: String) throws(GitError) {
        var oid = git_oid()
        let result = hex.withCString { cstr in
            git_oid_fromstr(&oid, cstr)
        }
        try check(result)
        self.raw = oid
    }

    internal init(raw: git_oid) {
        self.raw = raw
    }

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

- [ ] **Step 4: Run the tests and confirm they pass**

Run:
```bash
swift test --filter OID
```
Expected: all six tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Git2/Values/OID.swift Tests/Git2Tests/Values/OIDTests.swift
git commit -m "feat: add OID value type (SHA-1, hex round-trip, Hashable)"
```

---

## Task 7: `Signature` value type

**Files:**
- Create: `Sources/Git2/Values/Signature.swift`
- Create: `Tests/Git2Tests/Values/SignatureTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Tests/Git2Tests/Values/SignatureTests.swift`:

```swift
import Testing
import Foundation
@testable import Git2
import Cgit2

@Test
func signatureCopiesFromLibgit2() throws {
    var raw: UnsafeMutablePointer<git_signature>?
    defer { if let raw { git_signature_free(raw) } }
    let r = git_signature_new(&raw, "Alice", "alice@example.com", 1_700_000_000, 540) // +0900
    #expect(r == 0)
    let ptr = try #require(raw)

    let signature = Signature(copyingFrom: UnsafePointer(ptr))
    #expect(signature.name == "Alice")
    #expect(signature.email == "alice@example.com")
    #expect(signature.date == Date(timeIntervalSince1970: 1_700_000_000))
    #expect(signature.timeZone.secondsFromGMT() == 540 * 60) // +9h in seconds
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run:
```bash
swift test --filter Signature
```
Expected: compile error — `Signature` not defined.

- [ ] **Step 3: Implement `Signature`**

Create `Sources/Git2/Values/Signature.swift`:

```swift
import Cgit2
import Foundation

public struct Signature: Sendable, Equatable {
    public let name: String
    public let email: String
    public let date: Date
    public let timeZone: TimeZone

    public init(name: String, email: String, date: Date, timeZone: TimeZone) {
        self.name = name
        self.email = email
        self.date = date
        self.timeZone = timeZone
    }

    internal init(copyingFrom raw: UnsafePointer<git_signature>) {
        self.name = String(cString: raw.pointee.name)
        self.email = String(cString: raw.pointee.email)
        self.date = Date(timeIntervalSince1970: TimeInterval(raw.pointee.when.time))
        let offsetSeconds = Int(raw.pointee.when.offset) * 60
        self.timeZone = TimeZone(secondsFromGMT: offsetSeconds)
            ?? TimeZone(secondsFromGMT: 0)!
    }
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run:
```bash
swift test --filter Signature
```
Expected: test passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/Git2/Values/Signature.swift Tests/Git2Tests/Values/SignatureTests.swift
git commit -m "feat: add Signature value type (copied from git_signature)"
```

---

## Task 8: `GitRuntime` and `Git` lifecycle API

**Files:**
- Create: `Sources/Git2/Runtime/GitRuntime.swift`
- Create: `Sources/Git2/Runtime/Git.swift`
- Create: `Tests/Git2Tests/Runtime/GitLifecycleTests.swift`
- Modify: `Tests/Git2Tests/SmokeTests.swift` (delete — now redundant)

- [ ] **Step 1: Write the failing tests**

Create `Tests/Git2Tests/Runtime/GitLifecycleTests.swift`:

```swift
import Testing
@testable import Git2

@Test
func bootstrapAndShutdownAreIdempotent() throws {
    try Git.bootstrap()
    try Git.bootstrap()
    #expect(Git.isBootstrapped)
    try Git.shutdown()
    #expect(Git.isBootstrapped)        // still bootstrapped after one shutdown
    try Git.shutdown()
    #expect(Git.isBootstrapped == false)
}

@Test
func shutdownWithoutBootstrapIsNoOp() throws {
    // Ensure fully shut down first.
    while Git.isBootstrapped { try Git.shutdown() }
    try Git.shutdown()      // should not throw
    #expect(Git.isBootstrapped == false)
}

@Test
func versionIsAvailableWithoutBootstrap() throws {
    while Git.isBootstrapped { try Git.shutdown() }
    let v = Git.version
    #expect(v.major == 1)
    #expect(v.minor == 9)
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:
```bash
swift test --filter GitLifecycle
```
Expected: compile error — `Git` not defined.

- [ ] **Step 3: Implement `GitRuntime`**

Create `Sources/Git2/Runtime/GitRuntime.swift`:

```swift
import Cgit2
import os

internal final class GitRuntime: @unchecked Sendable {
    static let shared = GitRuntime()

    private let lock = OSAllocatedUnfairLock<Int>(initialState: 0)

    private init() {}

    func bootstrap() throws(GitError) {
        try lock.withLock { (state: inout Int) throws(GitError) in
            if state == 0 {
                try check(git_libgit2_init())
                let optResult = git_libgit2_opts(Int32(GIT_OPT_ENABLE_THREADS.rawValue), Int32(1))
                try check(optResult)
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

    var isBootstrapped: Bool {
        lock.withLock { $0 > 0 }
    }

    func requireBootstrapped(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        precondition(
            isBootstrapped,
            "Git.bootstrap() must be called before using \(function).",
            file: file,
            line: line
        )
    }
}
```

- [ ] **Step 4: Implement `Git`**

Create `Sources/Git2/Runtime/Git.swift`:

```swift
public enum Git {
    public static func bootstrap() throws(GitError) {
        try GitRuntime.shared.bootstrap()
    }

    public static func shutdown() throws(GitError) {
        try GitRuntime.shared.shutdown()
    }

    public static var isBootstrapped: Bool {
        GitRuntime.shared.isBootstrapped
    }

    public static var version: Version {
        Version.current
    }
}
```

- [ ] **Step 5: Delete the obsolete smoke test**

```bash
git rm Tests/Git2Tests/SmokeTests.swift
```

- [ ] **Step 6: Run all tests and confirm they pass**

Run:
```bash
swift test
```
Expected: all tests pass including the new `GitLifecycleTests`.

- [ ] **Step 7: Commit**

```bash
git add Sources/Git2/Runtime Tests/Git2Tests/Runtime
git commit -m "feat: add Git lifecycle API (bootstrap/shutdown/version/isBootstrapped)"
```

---

## Task 9: Test fixture support (`TemporaryDirectory`, `TestFixture`)

This internal test infrastructure is needed before we can test `Repository.open`. It uses libgit2 directly (not through the wrapper) because the wrapper doesn't yet expose commit creation.

**Files:**
- Create: `Tests/Git2Tests/Support/TemporaryDirectory.swift`
- Create: `Tests/Git2Tests/Support/TestFixture.swift`
- Create: `Tests/Git2Tests/Support/TestFixtureTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Git2Tests/Support/TestFixtureTests.swift`:

```swift
import Testing
import Foundation
@testable import Git2
import Cgit2

@Test
func withTemporaryDirectoryCreatesAndRemovesDirectory() throws {
    var capturedURL: URL?
    try withTemporaryDirectory { url in
        capturedURL = url
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }
    let url = try #require(capturedURL)
    #expect(FileManager.default.fileExists(atPath: url.path) == false)
}

@Test
func makeLinearHistoryCreatesGitDirectoryWithCommits() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeLinearHistory(
            commits: [
                (message: "first",  author: .test),
                (message: "second", author: .test),
                (message: "third",  author: .test),
            ],
            in: dir
        )

        let gitDir = fixture.repositoryURL.appendingPathComponent(".git")
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: gitDir.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }
}

extension Signature {
    /// Convenience for fixtures.
    static let test = Signature(
        name: "Tester",
        email: "tester@example.com",
        date: Date(timeIntervalSince1970: 1_700_000_000),
        timeZone: TimeZone(secondsFromGMT: 0)!
    )
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:
```bash
swift test --filter TestFixture
```
Expected: compile error — `withTemporaryDirectory` / `TestFixture` not defined.

- [ ] **Step 3: Implement `TemporaryDirectory`**

Create `Tests/Git2Tests/Support/TemporaryDirectory.swift`:

```swift
import Foundation

func withTemporaryDirectory<T>(_ body: (URL) throws -> T) rethrows -> T {
    let base = URL.temporaryDirectory
        .appendingPathComponent("Git2Tests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }
    return try body(base)
}
```

- [ ] **Step 4: Implement `TestFixture`**

Create `Tests/Git2Tests/Support/TestFixture.swift`:

```swift
import Foundation
@testable import Git2
import Cgit2

struct TestFixture {
    let repositoryURL: URL

    /// Create a linear commit history in `directory` and return a fixture pointing at it.
    /// Uses libgit2 directly because the Git2 wrapper does not yet expose commit creation.
    static func makeLinearHistory(
        commits: [(message: String, author: Signature)],
        in directory: URL
    ) throws -> TestFixture {
        // 1. Init repo
        var repoHandle: OpaquePointer?
        var result: Int32 = directory.withUnsafeFileSystemRepresentation { path in
            git_repository_init(&repoHandle, path, 0)
        }
        guard result == 0, let repo = repoHandle else {
            throw GitError.fromLibgit2(result)
        }
        defer { git_repository_free(repo) }

        // 2. For each commit, build a tree with a single file "README.md"
        //    containing the commit message, then create the commit.
        var parentID: git_oid?

        for (index, entry) in commits.enumerated() {
            // Write the blob
            var blobID = git_oid()
            let contents = entry.message
            try contents.withCString { bytes in
                let r = git_blob_create_from_buffer(
                    &blobID,
                    repo,
                    UnsafeRawPointer(bytes),
                    strlen(bytes)
                )
                guard r == 0 else { throw GitError.fromLibgit2(r) }
            }

            // Build a tree with that blob at "README.md"
            var builder: OpaquePointer?
            let rBuilder = git_treebuilder_new(&builder, repo, nil)
            guard rBuilder == 0, let tb = builder else { throw GitError.fromLibgit2(rBuilder) }
            defer { git_treebuilder_free(tb) }

            var withBlobID = blobID
            let rInsert = git_treebuilder_insert(
                nil, tb, "README.md", &withBlobID, GIT_FILEMODE_BLOB.rawValue
            )
            guard rInsert == 0 else { throw GitError.fromLibgit2(rInsert) }

            var treeID = git_oid()
            let rWrite = git_treebuilder_write(&treeID, tb)
            guard rWrite == 0 else { throw GitError.fromLibgit2(rWrite) }

            var tree: OpaquePointer?
            let rLookup = git_tree_lookup(&tree, repo, &treeID)
            guard rLookup == 0, let treeHandle = tree else { throw GitError.fromLibgit2(rLookup) }
            defer { git_tree_free(treeHandle) }

            // Create signature
            var sig: UnsafeMutablePointer<git_signature>?
            let rSig = git_signature_new(
                &sig,
                entry.author.name,
                entry.author.email,
                git_time_t(entry.author.date.timeIntervalSince1970),
                Int32(entry.author.timeZone.secondsFromGMT() / 60)
            )
            guard rSig == 0, let signature = sig else { throw GitError.fromLibgit2(rSig) }
            defer { git_signature_free(signature) }

            // Collect parent (index == 0 → no parents)
            var parents: [OpaquePointer?] = []
            if var pid = parentID {
                var parent: OpaquePointer?
                let rP = git_commit_lookup(&parent, repo, &pid)
                guard rP == 0, let parentHandle = parent else { throw GitError.fromLibgit2(rP) }
                parents.append(parentHandle)
            }
            defer {
                for p in parents { if let p { git_commit_free(p) } }
            }

            let parentPointers = parents.map { UnsafePointer<OpaquePointer?>(bitPattern: 0) } // placeholder
            _ = parentPointers
            // Build [const git_commit *] array for git_commit_create
            var parentCommits: [OpaquePointer?] = parents

            var commitID = git_oid()
            let refName = "HEAD"
            let rCreate = refName.withCString { refNameC in
                parentCommits.withUnsafeMutableBufferPointer { buf -> Int32 in
                    entry.message.withCString { msgC in
                        git_commit_create(
                            &commitID,
                            repo,
                            refNameC,
                            signature,
                            signature,
                            "UTF-8",
                            msgC,
                            treeHandle,
                            parents.count,
                            UnsafeMutablePointer(
                                OpaquePointer(buf.baseAddress.map { UnsafeRawPointer($0) })
                            )?.assumingMemoryBound(to: OpaquePointer?.self)
                                ?? nil
                        )
                    }
                }
            }
            guard rCreate == 0 else { throw GitError.fromLibgit2(rCreate) }
            parentID = commitID
            _ = index
        }

        return TestFixture(repositoryURL: directory)
    }
}
```

NOTE: The `git_commit_create` parents-array marshalling above is subtle because Swift bridges `UnsafePointer<UnsafePointer<git_commit>?>`. A cleaner implementation uses `withUnsafeBufferPointer` on `[UnsafePointer<git_commit>?]` and binds memory. If the build errors on the parents pointer conversion, replace the final `rCreate = ...` block with:

```swift
let rCreate: Int32 = entry.message.withCString { msgC in
    if parentCommits.isEmpty {
        return git_commit_create(
            &commitID, repo, "HEAD",
            signature, signature, "UTF-8", msgC, treeHandle,
            0, nil
        )
    } else {
        var parentPtr: OpaquePointer? = parentCommits[0]
        return withUnsafePointer(to: &parentPtr) { p in
            git_commit_create(
                &commitID, repo, "HEAD",
                signature, signature, "UTF-8", msgC, treeHandle,
                parentCommits.count, p
            )
        }
    }
}
```

(Linear history has at most one parent, so a single-parent pointer is sufficient.)

- [ ] **Step 5: Run the tests and confirm they pass**

Run:
```bash
swift test --filter TestFixture
```
Expected: both tests pass. If the `git_commit_create` parents pointer fails to compile, apply the alternate marshalling shown above, then re-run.

- [ ] **Step 6: Commit**

```bash
git add Tests/Git2Tests/Support
git commit -m "test(support): add withTemporaryDirectory + TestFixture.makeLinearHistory"
```

---

## Task 10: `Repository` open + basic properties

**Files:**
- Create: `Sources/Git2/Repository/Repository.swift`
- Create: `Tests/Git2Tests/Repository/RepositoryOpenTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Git2Tests/Repository/RepositoryOpenTests.swift`:

```swift
import Testing
import Foundation
@testable import Git2

@Test
func repositoryOpenSucceedsOnFixture() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeLinearHistory(
            commits: [(message: "initial", author: .test)],
            in: dir
        )
        let repo = try Repository.open(at: fixture.repositoryURL)
        #expect(repo.isBare == false)
        #expect(repo.workingDirectory?.standardizedFileURL == dir.standardizedFileURL)
        #expect(repo.gitDirectory.lastPathComponent == ".git" || repo.gitDirectory.path.hasSuffix(".git/"))
        #expect(repo.isHeadUnborn == false)
    }
}

@Test
func repositoryOpenOnEmptyDirectoryThrowsNotFound() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        do {
            _ = try Repository.open(at: dir)
            Issue.record("expected GitError")
        } catch let e as GitError {
            #expect(e.code == .notFound)
        }
    }
}

@Test
func repositoryOpenOnUnbornReportsUnbornHead() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        // Init a fresh repo without any commits
        var raw: OpaquePointer?
        try dir.withUnsafeFileSystemRepresentation { path in
            let r = git_repository_init(&raw, path, 0)
            #expect(r == 0)
        }
        git_repository_free(raw)

        let repo = try Repository.open(at: dir)
        #expect(repo.isHeadUnborn == true)
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:
```bash
swift test --filter RepositoryOpen
```
Expected: compile error — `Repository` not defined.

- [ ] **Step 3: Implement `Repository`**

Create `Sources/Git2/Repository/Repository.swift`:

```swift
import Cgit2
import Foundation

public final class Repository: @unchecked Sendable {
    internal let handle: OpaquePointer
    internal let lock: HandleLock

    internal init(handle: OpaquePointer) {
        self.handle = handle
        self.lock = HandleLock()
    }

    deinit {
        git_repository_free(handle)
    }

    public static func open(at url: URL) throws(GitError) -> Repository {
        GitRuntime.shared.requireBootstrapped()
        var raw: OpaquePointer?
        let result: Int32 = url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return GIT_EINVALIDSPEC.rawValue }
            return git_repository_open(&raw, path)
        }
        try check(result)
        return Repository(handle: raw!)
    }

    public var workingDirectory: URL? {
        lock.withLock {
            guard let cstr = git_repository_workdir(handle) else { return nil }
            return URL(fileURLWithPath: String(cString: cstr), isDirectory: true)
        }
    }

    public var gitDirectory: URL {
        lock.withLock {
            let cstr = git_repository_path(handle)
            return URL(fileURLWithPath: String(cString: cstr!), isDirectory: true)
        }
    }

    public var isBare: Bool {
        lock.withLock { git_repository_is_bare(handle) != 0 }
    }

    public var isHeadUnborn: Bool {
        lock.withLock { git_repository_head_unborn(handle) != 0 }
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run:
```bash
swift test --filter RepositoryOpen
```
Expected: all three tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Git2/Repository/Repository.swift Tests/Git2Tests/Repository
git commit -m "feat(repo): add Repository.open + basic properties"
```

---

## Task 11: `Reference` type and `Repository.head()`

**Files:**
- Create: `Sources/Git2/References/Reference.swift`
- Modify: `Sources/Git2/Repository/Repository.swift` (add `head()`)
- Create: `Tests/Git2Tests/Repository/RepositoryHeadTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Git2Tests/Repository/RepositoryHeadTests.swift`:

```swift
import Testing
import Foundation
@testable import Git2
import Cgit2

@Test
func headReturnsReferenceOnPopulatedRepo() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeLinearHistory(
            commits: [(message: "one", author: .test)],
            in: dir
        )
        let repo = try Repository.open(at: fixture.repositoryURL)
        let head = try repo.head()
        #expect(head.name.hasPrefix("refs/heads/"))
        #expect(["main", "master"].contains(head.shorthand))
    }
}

@Test
func headOnUnbornBranchThrows() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        var raw: OpaquePointer?
        try dir.withUnsafeFileSystemRepresentation { path in
            #expect(git_repository_init(&raw, path, 0) == 0)
        }
        git_repository_free(raw)

        let repo = try Repository.open(at: dir)
        do {
            _ = try repo.head()
            Issue.record("expected GitError")
        } catch let e as GitError {
            #expect(e.code == .unbornBranch)
        }
    }
}

@Test
func referenceTargetReturnsOID() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeLinearHistory(
            commits: [(message: "solo", author: .test)],
            in: dir
        )
        let repo = try Repository.open(at: fixture.repositoryURL)
        let head = try repo.head()
        let oid = try head.target
        #expect(oid.hex.count == 40)
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:
```bash
swift test --filter RepositoryHead
```
Expected: compile error — `Reference` / `Repository.head` not defined.

- [ ] **Step 3: Implement `Reference`**

Create `Sources/Git2/References/Reference.swift`:

```swift
import Cgit2

public final class Reference: @unchecked Sendable {
    internal let handle: OpaquePointer
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_reference_free(handle)
    }

    public var name: String {
        repository.lock.withLock {
            String(cString: git_reference_name(handle)!)
        }
    }

    public var shorthand: String {
        repository.lock.withLock {
            String(cString: git_reference_shorthand(handle)!)
        }
    }

    public var target: OID {
        get throws(GitError) {
            try repository.lock.withLock { () throws(GitError) -> OID in
                var resolved: OpaquePointer?
                try check(git_reference_resolve(&resolved, handle))
                defer { git_reference_free(resolved) }
                guard let oidPtr = git_reference_target(resolved) else {
                    throw GitError(code: .notFound, class: .reference, message: "symbolic reference has no target")
                }
                return OID(raw: oidPtr.pointee)
            }
        }
    }
}
```

- [ ] **Step 4: Add `head()` to `Repository`**

Modify `Sources/Git2/Repository/Repository.swift`: add the following method to the class body (after `isHeadUnborn`):

```swift
    public func head() throws(GitError) -> Reference {
        try lock.withLock { () throws(GitError) -> Reference in
            var raw: OpaquePointer?
            try check(git_repository_head(&raw, handle))
            return Reference(handle: raw!, repository: self)
        }
    }
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run:
```bash
swift test --filter RepositoryHead
```
Expected: all three tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Git2/References Sources/Git2/Repository Tests/Git2Tests/Repository/RepositoryHeadTests.swift
git commit -m "feat: add Reference type and Repository.head()"
```

---

## Task 12: `Commit` type, `Repository.commit(for:)`, and `Reference.resolveToCommit()`

**Files:**
- Create: `Sources/Git2/Commit/Commit.swift`
- Modify: `Sources/Git2/Repository/Repository.swift` (add `commit(for:)`)
- Modify: `Sources/Git2/References/Reference.swift` (add `resolveToCommit`)
- Create: `Tests/Git2Tests/Commit/CommitTests.swift`
- Create: `Tests/Git2Tests/Reference/ReferenceTests.swift`

- [ ] **Step 1: Write the failing tests for `Commit`**

Create `Tests/Git2Tests/Commit/CommitTests.swift`:

```swift
import Testing
import Foundation
@testable import Git2

@Test
func commitExposesOIDMessageAuthorCommitter() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let author = Signature.test
        let fixture = try TestFixture.makeLinearHistory(
            commits: [(message: "hello\n\nbody text here", author: author)],
            in: dir
        )
        let repo = try Repository.open(at: fixture.repositoryURL)
        let head = try repo.head()
        let tipOID = try head.target
        let commit = try repo.commit(for: tipOID)

        #expect(commit.oid == tipOID)
        #expect(commit.message.hasPrefix("hello"))
        #expect(commit.summary == "hello")
        #expect(commit.body == "body text here")
        #expect(commit.author.name == author.name)
        #expect(commit.author.email == author.email)
        #expect(commit.committer.name == author.name)
        #expect(commit.parentCount == 0)
    }
}

@Test
func commitWithoutBodyHasNilBody() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeLinearHistory(
            commits: [(message: "single line", author: .test)],
            in: dir
        )
        let repo = try Repository.open(at: fixture.repositoryURL)
        let head = try repo.head()
        let commit = try repo.commit(for: try head.target)
        #expect(commit.body == nil)
    }
}
```

- [ ] **Step 2: Write the failing tests for `Reference.resolveToCommit`**

Create `Tests/Git2Tests/Reference/ReferenceTests.swift`:

```swift
import Testing
import Foundation
@testable import Git2

@Test
func referenceResolvesToCommit() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeLinearHistory(
            commits: [(message: "only", author: .test)],
            in: dir
        )
        let repo = try Repository.open(at: fixture.repositoryURL)
        let head = try repo.head()
        let commit = try head.resolveToCommit()
        #expect(commit.summary == "only")
    }
}
```

- [ ] **Step 3: Run the tests and confirm they fail**

Run:
```bash
swift test --filter Commit
swift test --filter Reference
```
Expected: compile error — `Commit` / `resolveToCommit` / `Repository.commit(for:)` not defined.

- [ ] **Step 4: Implement `Commit`**

Create `Sources/Git2/Commit/Commit.swift`:

```swift
import Cgit2

public final class Commit: @unchecked Sendable {
    internal let handle: OpaquePointer
    public let repository: Repository

    internal init(handle: OpaquePointer, repository: Repository) {
        self.handle = handle
        self.repository = repository
    }

    deinit {
        git_commit_free(handle)
    }

    public var oid: OID {
        repository.lock.withLock {
            OID(raw: git_commit_id(handle)!.pointee)
        }
    }

    public var message: String {
        repository.lock.withLock {
            String(cString: git_commit_message(handle)!)
        }
    }

    public var summary: String {
        repository.lock.withLock {
            String(cString: git_commit_summary(handle)!)
        }
    }

    public var body: String? {
        repository.lock.withLock {
            guard let cstr = git_commit_body(handle) else { return nil }
            return String(cString: cstr)
        }
    }

    public var author: Signature {
        repository.lock.withLock {
            Signature(copyingFrom: git_commit_author(handle))
        }
    }

    public var committer: Signature {
        repository.lock.withLock {
            Signature(copyingFrom: git_commit_committer(handle))
        }
    }

    public var parentCount: Int {
        repository.lock.withLock {
            Int(git_commit_parentcount(handle))
        }
    }
}
```

- [ ] **Step 5: Add `commit(for:)` to `Repository`**

Modify `Sources/Git2/Repository/Repository.swift`: add the following method to the class body (after `head()`):

```swift
    public func commit(for oid: OID) throws(GitError) -> Commit {
        try lock.withLock { () throws(GitError) -> Commit in
            var oidCopy = oid.raw
            var raw: OpaquePointer?
            try check(git_commit_lookup(&raw, handle, &oidCopy))
            return Commit(handle: raw!, repository: self)
        }
    }
```

- [ ] **Step 6: Add `resolveToCommit` to `Reference`**

Modify `Sources/Git2/References/Reference.swift`: add the following method to the class body (after `target`):

```swift
    public func resolveToCommit() throws(GitError) -> Commit {
        try repository.lock.withLock { () throws(GitError) -> Commit in
            var raw: OpaquePointer?
            try check(git_reference_peel(&raw, handle, GIT_OBJECT_COMMIT))
            return Commit(handle: raw!, repository: repository)
        }
    }
```

- [ ] **Step 7: Run the tests and confirm they pass**

Run:
```bash
swift test --filter Commit
swift test --filter Reference
```
Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add Sources/Git2/Commit Sources/Git2/Repository Sources/Git2/References Tests/Git2Tests/Commit Tests/Git2Tests/Reference
git commit -m "feat: add Commit + Repository.commit(for:) + Reference.resolveToCommit"
```

---

## Task 13: `Commit.parents()`

Adding parents requires a merge fixture. Extend `TestFixture` with `makeMergeHistory` first.

**Files:**
- Modify: `Tests/Git2Tests/Support/TestFixture.swift` (add `makeMergeHistory`)
- Modify: `Sources/Git2/Commit/Commit.swift` (add `parents()`)
- Modify: `Tests/Git2Tests/Commit/CommitTests.swift` (add tests)

- [ ] **Step 1: Write failing tests for `parents()`**

Append to `Tests/Git2Tests/Commit/CommitTests.swift`:

```swift
@Test
func commitParentsForLinearHistory() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeLinearHistory(
            commits: [
                (message: "first",  author: .test),
                (message: "second", author: .test),
            ],
            in: dir
        )
        let repo = try Repository.open(at: fixture.repositoryURL)
        let tip = try repo.head().resolveToCommit()
        let parents = try tip.parents()
        #expect(parents.count == 1)
        #expect(parents[0].summary == "first")
    }
}

@Test
func commitParentsForMergeHistory() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeMergeHistory(in: dir)
        let repo = try Repository.open(at: fixture.repositoryURL)
        let tip = try repo.head().resolveToCommit()
        let parents = try tip.parents()
        #expect(parents.count == 2)
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:
```bash
swift test --filter commitParents
```
Expected: compile errors — `parents()` / `makeMergeHistory` not defined.

- [ ] **Step 3: Add `makeMergeHistory` to `TestFixture`**

Append the following method to the `TestFixture` struct in `Tests/Git2Tests/Support/TestFixture.swift`:

```swift
extension TestFixture {
    /// Creates a repo with history:
    ///     A --- B --- D
    ///      \       /
    ///       C-----/
    /// `D` has two parents (`B` and `C`).
    static func makeMergeHistory(in directory: URL) throws -> TestFixture {
        var repoHandle: OpaquePointer?
        let rInit: Int32 = directory.withUnsafeFileSystemRepresentation { path in
            git_repository_init(&repoHandle, path, 0)
        }
        guard rInit == 0, let repo = repoHandle else { throw GitError.fromLibgit2(rInit) }
        defer { git_repository_free(repo) }

        var sigPtr: UnsafeMutablePointer<git_signature>?
        let rSig = git_signature_new(
            &sigPtr, "Tester", "tester@example.com",
            git_time_t(1_700_000_000), 0
        )
        guard rSig == 0, let signature = sigPtr else { throw GitError.fromLibgit2(rSig) }
        defer { git_signature_free(signature) }

        func writeTree(content: String) throws -> git_oid {
            var blobID = git_oid()
            try content.withCString { bytes in
                let r = git_blob_create_from_buffer(&blobID, repo, UnsafeRawPointer(bytes), strlen(bytes))
                guard r == 0 else { throw GitError.fromLibgit2(r) }
            }
            var builder: OpaquePointer?
            let rB = git_treebuilder_new(&builder, repo, nil)
            guard rB == 0, let tb = builder else { throw GitError.fromLibgit2(rB) }
            defer { git_treebuilder_free(tb) }
            let rI = git_treebuilder_insert(nil, tb, "README.md", &blobID, GIT_FILEMODE_BLOB.rawValue)
            guard rI == 0 else { throw GitError.fromLibgit2(rI) }
            var treeID = git_oid()
            let rW = git_treebuilder_write(&treeID, tb)
            guard rW == 0 else { throw GitError.fromLibgit2(rW) }
            return treeID
        }

        func commit(tree treeID: git_oid, message: String, parents: [git_oid], updateRef: String?) throws -> git_oid {
            var tree: OpaquePointer?
            var treeIDCopy = treeID
            let rT = git_tree_lookup(&tree, repo, &treeIDCopy)
            guard rT == 0, let treeH = tree else { throw GitError.fromLibgit2(rT) }
            defer { git_tree_free(treeH) }

            var parentHandles: [OpaquePointer?] = []
            defer { for p in parentHandles { if let p { git_commit_free(p) } } }
            for var pid in parents {
                var parent: OpaquePointer?
                let r = git_commit_lookup(&parent, repo, &pid)
                guard r == 0, let ph = parent else { throw GitError.fromLibgit2(r) }
                parentHandles.append(ph)
            }

            var out = git_oid()
            let r: Int32 = message.withCString { msg in
                parentHandles.withUnsafeMutableBufferPointer { buf in
                    git_commit_create(
                        &out, repo,
                        updateRef,
                        signature, signature,
                        "UTF-8", msg,
                        treeH,
                        parentHandles.count,
                        buf.baseAddress
                    )
                }
            }
            guard r == 0 else { throw GitError.fromLibgit2(r) }
            return out
        }

        // A on main
        let treeA = try writeTree(content: "A")
        let oidA = try commit(tree: treeA, message: "A", parents: [], updateRef: "HEAD")

        // B on main
        let treeB = try writeTree(content: "B")
        let oidB = try commit(tree: treeB, message: "B", parents: [oidA], updateRef: "HEAD")

        // C on a side branch (refs/heads/side)
        let treeC = try writeTree(content: "C")
        let oidC = try commit(tree: treeC, message: "C", parents: [oidA], updateRef: "refs/heads/side")

        // D on main with B and C as parents (merge commit)
        let treeD = try writeTree(content: "D")
        _ = try commit(tree: treeD, message: "D (merge)", parents: [oidB, oidC], updateRef: "HEAD")

        return TestFixture(repositoryURL: directory)
    }
}
```

- [ ] **Step 4: Add `parents()` to `Commit`**

Modify `Sources/Git2/Commit/Commit.swift`: add the following method to the class body (after `parentCount`):

```swift
    public func parents() throws(GitError) -> [Commit] {
        try repository.lock.withLock { () throws(GitError) -> [Commit] in
            let count = git_commit_parentcount(handle)
            var out: [Commit] = []
            out.reserveCapacity(Int(count))
            for index: UInt32 in 0..<count {
                var raw: OpaquePointer?
                try check(git_commit_parent(&raw, handle, index))
                out.append(Commit(handle: raw!, repository: repository))
            }
            return out
        }
    }
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run:
```bash
swift test --filter commitParents
```
Expected: both new tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Git2/Commit/Commit.swift Tests/Git2Tests/Support/TestFixture.swift Tests/Git2Tests/Commit/CommitTests.swift
git commit -m "feat(commit): add parents() + merge fixture helper"
```

---

## Task 14: `RevWalkHandle`, `CommitSequence`, `CommitIterator`, `Repository.log(from:)`

**Files:**
- Create: `Sources/Git2/Internal/RevWalkHandle.swift`
- Create: `Sources/Git2/Repository/Repository+Log.swift`
- Create: `Tests/Git2Tests/Repository/RepositoryLogTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/Git2Tests/Repository/RepositoryLogTests.swift`:

```swift
import Testing
import Foundation
@testable import Git2

@Test
func logWalksLinearHistoryNewestFirst() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeLinearHistory(
            commits: [
                (message: "first",  author: .test),
                (message: "second", author: .test),
                (message: "third",  author: .test),
            ],
            in: dir
        )
        let repo = try Repository.open(at: fixture.repositoryURL)
        let tip = try repo.head().resolveToCommit()
        let summaries = repo.log(from: tip).map(\.summary)
        #expect(summaries == ["third", "second", "first"])
    }
}

@Test
func logCanBeIteratedTwice() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeLinearHistory(
            commits: [
                (message: "a", author: .test),
                (message: "b", author: .test),
            ],
            in: dir
        )
        let repo = try Repository.open(at: fixture.repositoryURL)
        let tip = try repo.head().resolveToCommit()
        let sequence = repo.log(from: tip)
        #expect(sequence.map(\.summary) == ["b", "a"])
        #expect(sequence.map(\.summary) == ["b", "a"])
    }
}

@Test
func logOnMergeReachesAllAncestors() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeMergeHistory(in: dir)
        let repo = try Repository.open(at: fixture.repositoryURL)
        let tip = try repo.head().resolveToCommit()
        let summaries = Set(repo.log(from: tip).map(\.summary))
        #expect(summaries == Set(["A", "B", "C", "D (merge)"]))
    }
}

@Test
func logPrefixWorks() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeLinearHistory(
            commits: [
                (message: "one",   author: .test),
                (message: "two",   author: .test),
                (message: "three", author: .test),
                (message: "four",  author: .test),
            ],
            in: dir
        )
        let repo = try Repository.open(at: fixture.repositoryURL)
        let tip = try repo.head().resolveToCommit()
        let first2 = repo.log(from: tip).prefix(2).map(\.summary)
        #expect(first2 == ["four", "three"])
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run:
```bash
swift test --filter RepositoryLog
```
Expected: compile error — `Repository.log` / `CommitSequence` not defined.

- [ ] **Step 3: Implement `RevWalkHandle`**

Create `Sources/Git2/Internal/RevWalkHandle.swift`:

```swift
import Cgit2

internal final class RevWalkHandle {
    private let repository: Repository
    private var walker: OpaquePointer?
    private var initialized = false

    init(repository: Repository, startOID: OID) {
        self.repository = repository
        repository.lock.withLock {
            var raw: OpaquePointer?
            guard git_revwalk_new(&raw, repository.handle) == 0, let created = raw else {
                return
            }
            var oidCopy = startOID.raw
            guard git_revwalk_push(created, &oidCopy) == 0 else {
                git_revwalk_free(created)
                return
            }
            self.walker = created
            self.initialized = true
        }
    }

    deinit {
        if let walker {
            git_revwalk_free(walker)
        }
    }

    func nextCommit() -> Commit? {
        guard initialized, let walker else { return nil }
        return repository.lock.withLock {
            var oid = git_oid()
            guard git_revwalk_next(&oid, walker) == 0 else { return nil }
            var commitHandle: OpaquePointer?
            guard git_commit_lookup(&commitHandle, repository.handle, &oid) == 0 else {
                return nil
            }
            return Commit(handle: commitHandle!, repository: repository)
        }
    }
}
```

- [ ] **Step 4: Implement `CommitSequence`, `CommitIterator`, and `Repository.log(from:)`**

Create `Sources/Git2/Repository/Repository+Log.swift`:

```swift
extension Repository {
    public func log(from start: Commit) -> CommitSequence {
        CommitSequence(repository: self, startOID: start.oid)
    }
}

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

    private let walker: RevWalkHandle

    internal init(repository: Repository, startOID: OID) {
        self.walker = RevWalkHandle(repository: repository, startOID: startOID)
    }

    public mutating func next() -> Commit? {
        walker.nextCommit()
    }
}
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run:
```bash
swift test --filter RepositoryLog
```
Expected: all four tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Git2/Internal/RevWalkHandle.swift Sources/Git2/Repository/Repository+Log.swift Tests/Git2Tests/Repository/RepositoryLogTests.swift
git commit -m "feat(repo): add log(from:) via CommitSequence + RevWalkHandle"
```

---

## Task 15: End-to-end smoke test matching the spec's usage sketch

Spec §8.5 shows the intended top-level usage. Lock it in as a test.

**Files:**
- Create: `Tests/Git2Tests/EndToEndTests.swift`

- [ ] **Step 1: Write the test**

Create `Tests/Git2Tests/EndToEndTests.swift`:

```swift
import Testing
import Foundation
@testable import Git2

@Test
func specUsageSketchWorksEndToEnd() throws {
    try Git.bootstrap()
    defer { try? Git.shutdown() }

    try withTemporaryDirectory { dir in
        let fixture = try TestFixture.makeLinearHistory(
            commits: (0..<15).map { i in
                (message: "commit \(i)", author: .test)
            },
            in: dir
        )

        let repo = try Repository.open(at: fixture.repositoryURL)
        let head = try repo.head()
        let tip = try head.resolveToCommit()

        let first10 = repo.log(from: tip).prefix(10).map(\.summary)
        #expect(first10.count == 10)
        #expect(first10.first == "commit 14")
        #expect(first10.last == "commit 5")
    }
}
```

- [ ] **Step 2: Run the test and confirm it passes**

Run:
```bash
swift test --filter specUsageSketch
```
Expected: the test passes.

- [ ] **Step 3: Full test run**

Run:
```bash
swift test
```
Expected: every test across the suite passes. No warnings about unused imports, `Sendable` violations, or typed-throws mismatches.

- [ ] **Step 4: Commit**

```bash
git add Tests/Git2Tests/EndToEndTests.swift
git commit -m "test: end-to-end smoke test matching spec usage sketch"
```

---

## Task 16: Tag v0.2.0 release candidate

- [ ] **Step 1: Confirm clean state**

Run:
```bash
git status
```
Expected: working tree clean.

- [ ] **Step 2: Run the whole test suite one last time**

Run:
```bash
swift test
```
Expected: all tests pass.

- [ ] **Step 3: (optional) Tag**

Tagging is the user's call — this plan does not create the tag automatically. When the user asks:

```bash
git tag -a v0.2.0 -m "v0.2.0: Git2 Swift wrapper foundation + first slice"
git push origin v0.2.0
```

---

## Appendix: Common failure modes

- **`OSAllocatedUnfairLock<Void>` constructor mismatch**: On some SDKs, `OSAllocatedUnfairLock()` without arguments requires `Void` as the generic parameter and no `initialState`. `OSAllocatedUnfairLock<Int>(initialState: 0)` is the correct form for the stateful runtime lock. The `HandleLock` wrapper uses `OSAllocatedUnfairLock<Void>`; if that fails to construct, change it to `OSAllocatedUnfairLock<Void>(initialState: ())`.
- **`GIT_ERROR_*` cases not found**: libgit2 1.9 spells some classes differently than older releases. If any `case GIT_ERROR_X: return .y` line fails to compile, consult `.build/.../Cgit2.framework/Headers/errors.h` or the libgit2 source for the exact constant name; delete the offending case (it will fall through to `.unknown(raw)`) and file a follow-up to add it later.
- **`git_oid_fromstr` vs `git_oid_fromstrp`**: libgit2 1.9 has both. The former requires exactly 40 hex characters; the latter accepts shorter prefixes. We use `git_oid_fromstr` because the public `OID(hex:)` API expects a full OID.
- **`git_commit_create` parents array**: The trickiest C-bridging point. If the main version of `makeLinearHistory` in Task 9 fails to compile, fall back to the single-parent form documented in that task's note.
- **`git_repository_open` on a path that points at a file, not a directory**: libgit2 reports `.notFound` rather than an OS error. Tests assume this mapping.
- **`withTemporaryDirectory` reuse across tests**: Each call creates its own UUID-named directory and removes it on scope exit. Tests should not share a fixture directory.
