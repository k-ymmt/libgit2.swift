# Git2

A Swift wrapper around [libgit2](https://libgit2.org), distributed as a Swift
Package for Apple platforms.

> Status: `v0.2.0` is the first release with an idiomatic Swift API. The surface
> is intentionally small — enough to open a repository, resolve HEAD, and walk
> commit history. See [`TODO.md`](TODO.md) and the design docs under
> `docs/superpowers/` for the roadmap.

## Requirements

- Swift 6.2 or later
- macOS 13 or later
- iOS 16 or later

## Installation

Add the package to your `Package.swift`:

```swift
let package = Package(
    // ...
    dependencies: [
        .package(url: "https://github.com/k-ymmt/libgit2.swift.git", from: "0.2.0"),
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: [
                .product(name: "Git2", package: "libgit2.swift"),
            ]
        ),
    ]
)
```

In Xcode, add the same URL through **File ▸ Add Package Dependencies…**.

## Quick start

```swift
import Git2

try Git.bootstrap()
defer { try? Git.shutdown() }

let repo = try Repository.open(at: URL(filePath: "/path/to/repo"))
let tip = try repo.head().resolveToCommit()

for commit in repo.log(from: tip).prefix(10) {
    print(commit.oid.hex.prefix(7), commit.author.name, commit.summary)
}
```

### Error handling

Every failing API throws `GitError`:

```swift
do {
    _ = try Repository.open(at: someURL)
} catch let error as GitError where error.code == .notFound {
    print("Not a Git repository: \(someURL.path)")
}
```

Git2 uses typed throws (`throws(GitError)`), so the error type is already known
at the `catch` site.

### Concurrency

`Repository`, `Reference`, and `Commit` are `Sendable` and safe to share across
tasks. All libgit2 calls for a given repository are internally serialized.

```swift
try await withThrowingTaskGroup(of: String.self) { group in
    for oid in interestingOIDs {
        group.addTask {
            let commit = try repo.commit(for: oid)
            return commit.summary
        }
    }
    for try await summary in group {
        print(summary)
    }
}
```

`CommitSequence` and `CommitIterator` are intentionally non-`Sendable` — they
hold an in-progress revwalk.

## Falling back to the C API

Git2 re-exports the Cgit2 C surface. If you need a libgit2 function that the
Swift layer does not yet cover, you can call it directly after `import Git2`:

```swift
import Git2

// Cgit2 symbols are visible via @_exported import.
var major: Int32 = 0, minor: Int32 = 0, rev: Int32 = 0
_ = git_libgit2_version(&major, &minor, &rev)
```

When mixing raw libgit2 calls with the wrapper, prefer `Git.bootstrap()` /
`Git.shutdown()` over calling `git_libgit2_init` / `git_libgit2_shutdown`
yourself.

## What's inside

| Layer | Provides |
|---|---|
| `Cgit2` (binary target) | An XCFramework with libgit2 1.9.x built for macOS, iOS device, and iOS Simulator slices (Intel + Apple Silicon). |
| `Git2` | The Swift wrapper — `Repository`, `Reference`, `Commit`, `OID`, `Signature`, `GitError`, `Git` lifecycle, `Repository.log(from:)`. |

## Current scope (v0.2.0)

**Included:** opening an existing repository, inspecting HEAD and references,
reading commit metadata, walking commit history.

**Not yet included:** discovering a repository by walking up from a child
directory, listing references, tree/blob/tag objects, diffs, index/staging,
committing, branch/tag manipulation, merge/rebase, remotes, SSH. See
`TODO.md` and `docs/superpowers/specs/` for the planned slices.

## Versioning

v0.x is treated as unstable per the SemVer `0.x` convention. Breaking changes
may land in any `0.y.0` bump. Regular SemVer guarantees begin at `v1.0`.

## License

libgit2 itself is GPLv2 with a linking exception — see the
[libgit2 project](https://github.com/libgit2/libgit2) for details. A `LICENSE`
file for this wrapper will be added in a follow-up.
