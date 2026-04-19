# libgit2 XCFramework Build & Distribution Design

- Date: 2026-04-19
- Status: Draft
- Owner: @k-ymmt

## Goal

Build the bundled `libgit2` submodule (currently pinned at `v1.9.0-241-g1f34e2a57`)
into a multi-platform XCFramework covering macOS, iOS device, and iOS simulator,
then distribute it as a GitHub Release asset consumed by `Package.swift` through
`.binaryTarget(url:checksum:)`. The XCFramework exposes the libgit2 C headers as
a Swift `Cgit2` module so downstream code can `import Cgit2`.

## Scope

### In scope
- Local shell scripts that produce the XCFramework from the `libgit2` submodule.
- A release helper script that zips the XCFramework and computes its SHA-256.
- `Package.swift` wiring: a `.binaryTarget` named `Cgit2` and a `libgit2.swift`
  Swift target that depends on it.
- A single smoke-test in the existing test target that calls
  `git_libgit2_init()`, `git_libgit2_version()`, and `git_libgit2_shutdown()`
  to prove the binary target links and loads correctly.

### Out of scope
- The full Swift wrapper layer over libgit2 (tracked separately).
- SSH support (`USE_SSH` stays `OFF`); no `libssh2` build is produced.
- CI automation / GitHub Actions. The build and the release upload are performed
  manually on a developer's machine.
- Non-target Apple platforms: Mac Catalyst, visionOS, tvOS, watchOS.

## Assumptions & Prerequisites

- The developer runs the scripts on an Apple Silicon Mac with Xcode installed
  (providing `xcodebuild`, `lipo`, and the iOS/macOS SDKs).
- `cmake` and `ninja` are installed (`brew install cmake ninja`).
- `git submodule update --init` has been run so `libgit2/CMakeLists.txt` exists.

## Architecture

```
libgit2.swift/
├── scripts/
│   ├── build-xcframework.sh     # produces artifacts/libgit2.xcframework
│   └── release-xcframework.sh   # zips + checksums the XCFramework
├── artifacts/                    # git-ignored output root
│   ├── build/<slice>/           # per-slice CMake build directories
│   ├── slices/<platform>/       # lipo-combined .a + Headers/
│   ├── libgit2.xcframework/
│   └── libgit2.xcframework.zip
├── libgit2/                      # existing submodule
├── Sources/libgit2.swift/       # thin re-export: @_exported import Cgit2
├── Tests/libgit2.swiftTests/    # smoke test
└── Package.swift                # declares Cgit2 binaryTarget
```

## Build Configuration

### Common CMake options (all slices)
```
-DBUILD_SHARED_LIBS=OFF
-DBUILD_TESTS=OFF
-DBUILD_CLI=OFF
-DBUILD_EXAMPLES=OFF
-DUSE_SSH=OFF
-DUSE_HTTPS=SecureTransport
-DUSE_SHA1=builtin
-DUSE_REGEX=builtin
-DCMAKE_BUILD_TYPE=Release
```

### Per-slice options

| slice          | CMAKE_SYSTEM_NAME | CMAKE_OSX_SYSROOT    | CMAKE_OSX_ARCHITECTURES | deployment target            |
|----------------|-------------------|----------------------|-------------------------|------------------------------|
| macos-arm64    | Darwin            | macosx               | arm64                   | CMAKE_OSX_DEPLOYMENT_TARGET=13.0 |
| macos-x86_64   | Darwin            | macosx               | x86_64                  | CMAKE_OSX_DEPLOYMENT_TARGET=13.0 |
| ios-arm64      | iOS               | iphoneos             | arm64                   | CMAKE_OSX_DEPLOYMENT_TARGET=15.0 |
| iossim-arm64   | iOS               | iphonesimulator      | arm64                   | CMAKE_OSX_DEPLOYMENT_TARGET=15.0 |
| iossim-x86_64  | iOS               | iphonesimulator      | x86_64                  | CMAKE_OSX_DEPLOYMENT_TARGET=15.0 |

The SDK paths are resolved via `xcrun --sdk <sdk> --show-sdk-path`.

## Build Flow (`scripts/build-xcframework.sh`)

1. **Preflight checks** — `command -v` for `cmake`, `ninja`, `xcodebuild`,
   `lipo`, `xcrun`; verify `libgit2/CMakeLists.txt` exists.
2. **Clean** — remove `artifacts/build`, `artifacts/slices`,
   `artifacts/libgit2.xcframework`, `artifacts/libgit2.xcframework.zip`.
3. **Per-slice build** — for each of the 5 slices:
   ```
   cmake -S libgit2 -B artifacts/build/<slice> -G Ninja <common> <per-slice>
   cmake --build artifacts/build/<slice> --config Release
   ```
   Output: `artifacts/build/<slice>/libgit2.a`.
4. **Universalize with lipo** — produce one `.a` per platform:
   - `slices/macos/libgit2.a` = lipo(macos-arm64, macos-x86_64)
   - `slices/iossim/libgit2.a` = lipo(iossim-arm64, iossim-x86_64)
   - `slices/ios/libgit2.a` = cp of ios-arm64
5. **Collect headers** — copy `libgit2/include/git2.h` and
   `libgit2/include/git2/**` into each `slices/<platform>/Headers/`. Also walk
   each `artifacts/build/<slice>/include/` and copy any CMake-generated headers
   (e.g., `git2_features.h`) on top of the source headers. If the same header
   name appears in both trees, the generated one wins.
6. **Emit module.modulemap** — write the following into each
   `slices/<platform>/Headers/module.modulemap`:
   ```
   module Cgit2 {
       umbrella header "git2.h"
       export *
   }
   ```
7. **Create XCFramework**:
   ```
   xcodebuild -create-xcframework \
     -library slices/macos/libgit2.a   -headers slices/macos/Headers \
     -library slices/ios/libgit2.a     -headers slices/ios/Headers \
     -library slices/iossim/libgit2.a  -headers slices/iossim/Headers \
     -output artifacts/libgit2.xcframework
   ```
8. **Final verification** (script exits non-zero on any failure):
   - `test -f artifacts/libgit2.xcframework/Info.plist`
   - `lipo -info` on each slice's `.a` matches expected arches
     (macos: `x86_64 arm64`, ios: `arm64`, iossim: `x86_64 arm64`)
   - Each `Headers/git2.h` exists
   - Each `Headers/module.modulemap` exists

## Release Flow (`scripts/release-xcframework.sh`)

1. Verify `artifacts/libgit2.xcframework` exists; otherwise instruct the user to
   run `build-xcframework.sh` first.
2. `zip -r artifacts/libgit2.xcframework.zip artifacts/libgit2.xcframework`.
3. Compute SHA-256 via `swift package compute-checksum
   artifacts/libgit2.xcframework.zip`.
4. Print to stdout: the zip path, size, checksum, and a ready-to-paste
   `binaryTarget(url:checksum:)` snippet with a placeholder URL.

### Manual operator steps (outside the scripts)
1. Run `scripts/build-xcframework.sh`.
2. Run `scripts/release-xcframework.sh`.
3. Create a new GitHub Release; attach the zip.
4. Update `Package.swift` with the Release's download URL and the printed
   checksum; commit.

## Package.swift Wiring

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "libgit2.swift",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        .library(name: "libgit2.swift", targets: ["libgit2.swift"]),
    ],
    targets: [
        .binaryTarget(
            name: "Cgit2",
            url: "https://github.com/<owner>/libgit2.swift/releases/download/<tag>/libgit2.xcframework.zip",
            checksum: "<sha256>"
        ),
        .target(
            name: "libgit2.swift",
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
            name: "libgit2.swiftTests",
            dependencies: ["libgit2.swift"]
        ),
    ]
)
```

The `linkerSettings` are required because the bundled `libgit2.a` statically references Apple framework symbols (SecureTransport, CoreFoundation, GSSAPI) and system libraries (zlib, iconv). libgit2's internal features (SecureTransport HTTPS, Negotiate auth, iconv-based Unicode normalization) pull these in at compile time; we surface them to SwiftPM's linker step via `linkerSettings`.

`Sources/libgit2.swift/Exports.swift` contains a single line:
```swift
@_exported import Cgit2
```

Until a Release is published, the README documents a local-override recipe that
swaps the remote `binaryTarget` for `.binaryTarget(path: "artifacts/libgit2.xcframework")`.

## Error Handling

- Every script starts with `set -euo pipefail`.
- Each phase prints `==> <phase name>` so failures are localized in the log.
- Preflight failures report the missing tool and the fix (e.g., `brew install
  cmake ninja`, `git submodule update --init --recursive`).
- Intermediate artifacts are not cleaned up on failure; the developer keeps the
  partial build for debugging.

## Testing

`Tests/libgit2.swiftTests/Libgit2SmokeTests.swift` exercises the binary target:

- Call `git_libgit2_init()` and assert the return value is non-negative.
- Call `git_libgit2_version(&major, &minor, &rev)` and assert `major == 1` and
  `minor == 9`.
- Call `git_libgit2_shutdown()` and assert non-negative.

Verification loop (manual during development):
1. Edit `Package.swift` to use `.binaryTarget(path: "artifacts/libgit2.xcframework")`.
2. Run `./scripts/build-xcframework.sh`.
3. Run `swift test` on macOS; it must pass.
4. Revert `Package.swift` to the remote URL form before committing a release.

iOS execution of tests is out of scope; iOS slice coverage is guaranteed by the
`lipo -info` checks in the build script.

## Operator Runbook

1. `git submodule update --init --recursive`
2. `./scripts/build-xcframework.sh`
3. `./scripts/release-xcframework.sh` — records the SHA-256 in its output.
4. Upload `artifacts/libgit2.xcframework.zip` to a new GitHub Release.
5. Edit `Package.swift`: swap the `.binaryTarget(name: "Cgit2", path: ...)`
   line for a `.binaryTarget(name: "Cgit2", url: ..., checksum: ...)` using
   the Release's download URL and the printed checksum. Commit.

To temporarily fall back to a local XCFramework build during development,
revert to the `path:` form.

## Acceptance Criteria

- [ ] After `git submodule update --init`, `./scripts/build-xcframework.sh`
      completes successfully on a clean machine.
- [ ] `artifacts/libgit2.xcframework` contains the three expected slices:
      `macos-arm64_x86_64`, `ios-arm64`, `ios-arm64_x86_64-simulator`.
- [ ] `./scripts/release-xcframework.sh` prints a valid zip path and SHA-256.
- [ ] With local `.binaryTarget(path:)` and the freshly built XCFramework,
      `swift test` on macOS passes the smoke test.
- [ ] After uploading the zip to a GitHub Release and updating
      `Package.swift` with URL and checksum, `swift build` passes on a fresh
      checkout (no submodule fetch required for consumers).

## Risks & Mitigations

- **Missing CMake-generated headers (e.g., `git2_features.h`)**: If only the
  source `include/` is copied, downstream compilation may fail. The build script
  explicitly walks each build directory's `include/` and overlays generated
  headers (step 5).
- **Duplicate symbols from bundled deps (`llhttp`, `zlib`, `pcre`)**: libgit2
  merges them into its static archive; two consumers linking the same archive
  are not a concern. If future changes add another archive that also bundles
  these, `nm` inspection will be needed. Not guarded today.
- **Xcode / CMake version drift**: Xcode upgrades have historically shifted
  default flags (bitcode, linker). Because the script pins
  `CMAKE_OSX_DEPLOYMENT_TARGET` and uses Ninja (not the Xcode generator), most
  drift should be cosmetic. If a future Xcode removes a used SDK, the preflight
  `xcrun --show-sdk-path` call surfaces it immediately.
