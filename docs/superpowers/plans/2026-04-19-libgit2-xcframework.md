# libgit2 XCFramework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a macOS / iOS / iOS-Simulator XCFramework from the `libgit2` submodule, distribute it via GitHub Releases, and wire it into `Package.swift` as a `.binaryTarget` so Swift code can `import Cgit2`.

**Architecture:** A shell script (`build-xcframework.sh`) drives CMake + Ninja per slice, universalizes per-platform static archives with `lipo`, assembles headers + a `module.modulemap` for the `Cgit2` Clang module, then runs `xcodebuild -create-xcframework`. A second script (`release-xcframework.sh`) zips and SHA-256's the framework. `Package.swift` declares `Cgit2` as a `.binaryTarget` and the existing `libgit2.swift` target re-exports it.

**Tech Stack:** CMake 3.5+, Ninja, Apple's `xcodebuild` / `lipo` / `xcrun`, Swift Package Manager 6.2, Swift Testing.

**Spec reference:** `docs/superpowers/specs/2026-04-19-libgit2-xcframework-design.md`

---

## Prerequisites (run once)

- [ ] **Install toolchain**

```bash
brew install cmake ninja
```

Verify:

```bash
command -v cmake ninja xcodebuild lipo xcrun
```
Expected: one path per tool, exit code 0.

- [ ] **Initialize submodule**

```bash
git submodule update --init --recursive
test -f libgit2/CMakeLists.txt
```
Expected: file exists (non-zero exit if not).

---

## Task 1: Add `.gitignore` entry for build artifacts

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Append `/artifacts` to `.gitignore`**

Current `.gitignore` already has entries like `/.build`, `/Packages`. Add one line:

```
/artifacts
```

Final file should read:
```
.DS_Store
/.build
/Packages
xcuserdata/
DerivedData/
.swiftpm/configuration/registries.json
.swiftpm/xcode/package.xcworkspace/contents.xcworkspacedata
.netrc
/artifacts
```

- [ ] **Step 2: Verify**

```bash
grep -x "/artifacts" .gitignore
```
Expected: prints `/artifacts`.

- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: ignore artifacts/ (XCFramework build output)"
```

---

## Task 2: Create the build script skeleton (preflight + clean)

**Files:**
- Create: `scripts/build-xcframework.sh`

Scope of this task: write the outer structure and the first two phases (preflight, clean). Later tasks extend the same file.

- [ ] **Step 1: Create `scripts/` and the script file**

```bash
mkdir -p scripts
```

Create `scripts/build-xcframework.sh` with these contents (this is the full file for Task 2; later tasks will edit it in place):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Run from repository root.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

ARTIFACTS_DIR="artifacts"
BUILD_DIR="$ARTIFACTS_DIR/build"
SLICES_DIR="$ARTIFACTS_DIR/slices"
XCFRAMEWORK_DIR="$ARTIFACTS_DIR/libgit2.xcframework"
XCFRAMEWORK_ZIP="$ARTIFACTS_DIR/libgit2.xcframework.zip"

MACOS_DEPLOYMENT_TARGET="13.0"
IOS_DEPLOYMENT_TARGET="15.0"

# (slice_name, system_name, sdk, arch, deployment_target)
SLICES=(
    "macos-arm64|Darwin|macosx|arm64|$MACOS_DEPLOYMENT_TARGET"
    "macos-x86_64|Darwin|macosx|x86_64|$MACOS_DEPLOYMENT_TARGET"
    "ios-arm64|iOS|iphoneos|arm64|$IOS_DEPLOYMENT_TARGET"
    "iossim-arm64|iOS|iphonesimulator|arm64|$IOS_DEPLOYMENT_TARGET"
    "iossim-x86_64|iOS|iphonesimulator|x86_64|$IOS_DEPLOYMENT_TARGET"
)

echo "==> [1/8] Preflight checks"
for tool in cmake ninja xcodebuild lipo xcrun zip; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: required tool '$tool' not found in PATH" >&2
        echo "hint: brew install cmake ninja  (xcodebuild/lipo/xcrun/zip come with Xcode)" >&2
        exit 1
    fi
done
if [ ! -f "libgit2/CMakeLists.txt" ]; then
    echo "error: libgit2/CMakeLists.txt not found" >&2
    echo "hint: run 'git submodule update --init --recursive'" >&2
    exit 1
fi

echo "==> [2/8] Clean"
rm -rf "$BUILD_DIR" "$SLICES_DIR" "$XCFRAMEWORK_DIR"
rm -f "$XCFRAMEWORK_ZIP"
mkdir -p "$BUILD_DIR" "$SLICES_DIR"

echo "==> Done (skeleton only — remaining phases not yet implemented)"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/build-xcframework.sh
```

- [ ] **Step 3: Run it, verify preflight + clean succeed**

```bash
./scripts/build-xcframework.sh
```
Expected output contains:
```
==> [1/8] Preflight checks
==> [2/8] Clean
==> Done (skeleton only — remaining phases not yet implemented)
```
Expected `artifacts/build/` and `artifacts/slices/` directories exist and are empty.

- [ ] **Step 4: Negative test — simulate a missing submodule**

```bash
mv libgit2 libgit2.bak && ./scripts/build-xcframework.sh; echo "exit=$?"; mv libgit2.bak libgit2
```
Expected: script prints the submodule hint and exits non-zero, something like `exit=1`.

- [ ] **Step 5: Commit**

```bash
git add scripts/build-xcframework.sh
git commit -m "build: add XCFramework build script skeleton (preflight + clean)"
```

---

## Task 3: Add per-slice CMake build phase

**Files:**
- Modify: `scripts/build-xcframework.sh`

- [ ] **Step 1: Replace the `==> Done (skeleton only...` echo line with the per-slice build loop**

Open `scripts/build-xcframework.sh`. Locate the line:
```
echo "==> Done (skeleton only — remaining phases not yet implemented)"
```

Replace it with:

```bash
echo "==> [3/8] Per-slice CMake + Ninja build"
for entry in "${SLICES[@]}"; do
    IFS='|' read -r slice system sdk arch target <<< "$entry"
    sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
    build_subdir="$BUILD_DIR/$slice"
    mkdir -p "$build_subdir"

    echo "---- building $slice (system=$system sdk=$sdk arch=$arch target=$target)"
    cmake -S libgit2 -B "$build_subdir" -G Ninja \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_CLI=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DUSE_SSH=OFF \
        -DUSE_HTTPS=SecureTransport \
        -DUSE_SHA1=builtin \
        -DUSE_REGEX=builtin \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_SYSTEM_NAME="$system" \
        -DCMAKE_OSX_SYSROOT="$sdk_path" \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$target"

    cmake --build "$build_subdir" --config Release

    if [ ! -f "$build_subdir/libgit2.a" ]; then
        # libgit2 may place the static lib under a subdirectory depending on
        # CMake version. Search for it under the build dir and fail loudly
        # if it's missing.
        found="$(find "$build_subdir" -name 'libgit2.a' -maxdepth 3 | head -n1)"
        if [ -z "$found" ]; then
            echo "error: libgit2.a not found under $build_subdir" >&2
            exit 1
        fi
        cp "$found" "$build_subdir/libgit2.a"
    fi
done

echo "==> Done (build phase — remaining phases pending)"
```

- [ ] **Step 2: Run it**

```bash
./scripts/build-xcframework.sh
```
Expected: five `---- building <slice>` sections complete without error. Build may take several minutes the first time.

- [ ] **Step 3: Verify all five `.a` files exist**

```bash
ls artifacts/build/*/libgit2.a
```
Expected: five paths printed, one per slice.

- [ ] **Step 4: Spot-check an architecture**

```bash
lipo -info artifacts/build/ios-arm64/libgit2.a
lipo -info artifacts/build/iossim-x86_64/libgit2.a
```
Expected first: architecture is `arm64`.
Expected second: architecture is `x86_64`.

- [ ] **Step 5: Commit**

```bash
git add scripts/build-xcframework.sh
git commit -m "build: compile libgit2 for all five Apple slices"
```

---

## Task 4: Universalize per-platform archives with lipo

**Files:**
- Modify: `scripts/build-xcframework.sh`

- [ ] **Step 1: Add the lipo phase**

In `scripts/build-xcframework.sh`, replace the line:
```
echo "==> Done (build phase — remaining phases pending)"
```

with:

```bash
echo "==> [4/8] Universalize per platform (lipo)"
mkdir -p "$SLICES_DIR/macos" "$SLICES_DIR/ios" "$SLICES_DIR/iossim"

lipo -create \
    "$BUILD_DIR/macos-arm64/libgit2.a" \
    "$BUILD_DIR/macos-x86_64/libgit2.a" \
    -output "$SLICES_DIR/macos/libgit2.a"

cp "$BUILD_DIR/ios-arm64/libgit2.a" "$SLICES_DIR/ios/libgit2.a"

lipo -create \
    "$BUILD_DIR/iossim-arm64/libgit2.a" \
    "$BUILD_DIR/iossim-x86_64/libgit2.a" \
    -output "$SLICES_DIR/iossim/libgit2.a"

echo "==> Done (lipo phase — remaining phases pending)"
```

- [ ] **Step 2: Run the script**

```bash
./scripts/build-xcframework.sh
```
Expected: completes without error (will re-run the full build from clean).

- [ ] **Step 3: Verify the three platform archives**

```bash
lipo -info artifacts/slices/macos/libgit2.a
lipo -info artifacts/slices/ios/libgit2.a
lipo -info artifacts/slices/iossim/libgit2.a
```
Expected:
- macos: `Architectures in the fat file: ... are: x86_64 arm64` (order may vary)
- ios: `Non-fat file: ... is architecture: arm64`
- iossim: `Architectures in the fat file: ... are: x86_64 arm64`

- [ ] **Step 4: Commit**

```bash
git add scripts/build-xcframework.sh
git commit -m "build: lipo-combine per-platform universal archives"
```

---

## Task 5: Collect headers and generate `module.modulemap`

**Files:**
- Modify: `scripts/build-xcframework.sh`

- [ ] **Step 1: Add the headers phase**

In `scripts/build-xcframework.sh`, replace:
```
echo "==> Done (lipo phase — remaining phases pending)"
```

with:

```bash
echo "==> [5/8] Collect headers"
for platform in macos ios iossim; do
    headers_dst="$SLICES_DIR/$platform/Headers"
    mkdir -p "$headers_dst"
    # Copy source headers (git2.h and the git2/ subdirectory)
    cp "libgit2/include/git2.h" "$headers_dst/git2.h"
    rm -rf "$headers_dst/git2"
    cp -R "libgit2/include/git2" "$headers_dst/git2"
done

# Overlay CMake-generated headers (e.g. git2_features.h) from any of the
# five build dirs — they are identical across slices for public headers.
representative_build="$BUILD_DIR/macos-arm64"
if [ -d "$representative_build/include" ]; then
    for platform in macos ios iossim; do
        headers_dst="$SLICES_DIR/$platform/Headers"
        # Copy each file found under the build include dir, preserving
        # relative paths.
        (cd "$representative_build/include" && find . -type f) | while read -r rel; do
            src="$representative_build/include/$rel"
            dst="$headers_dst/$rel"
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
        done
    done
fi

echo "==> [6/8] Emit module.modulemap"
for platform in macos ios iossim; do
    cat > "$SLICES_DIR/$platform/Headers/module.modulemap" <<'MODMAP'
module Cgit2 {
    umbrella header "git2.h"
    export *
    module * { export * }
}
MODMAP
done

echo "==> Done (headers + modulemap phase — remaining phases pending)"
```

- [ ] **Step 2: Run the script**

```bash
./scripts/build-xcframework.sh
```
Expected: completes without error.

- [ ] **Step 3: Verify headers and modulemap in each platform**

```bash
for p in macos ios iossim; do
    test -f "artifacts/slices/$p/Headers/git2.h" && echo "$p: git2.h ok"
    test -d "artifacts/slices/$p/Headers/git2" && echo "$p: git2/ dir ok"
    test -f "artifacts/slices/$p/Headers/module.modulemap" && echo "$p: modulemap ok"
done
```
Expected: nine `ok` lines (three platforms × three checks).

- [ ] **Step 4: Commit**

```bash
git add scripts/build-xcframework.sh
git commit -m "build: collect headers and emit Cgit2 module.modulemap"
```

---

## Task 6: Create the XCFramework and run final verification

**Files:**
- Modify: `scripts/build-xcframework.sh`

- [ ] **Step 1: Add xcframework phase and verification**

In `scripts/build-xcframework.sh`, replace:
```
echo "==> Done (headers + modulemap phase — remaining phases pending)"
```

with:

```bash
echo "==> [7/8] Create XCFramework"
xcodebuild -create-xcframework \
    -library "$SLICES_DIR/macos/libgit2.a"   -headers "$SLICES_DIR/macos/Headers" \
    -library "$SLICES_DIR/ios/libgit2.a"     -headers "$SLICES_DIR/ios/Headers" \
    -library "$SLICES_DIR/iossim/libgit2.a"  -headers "$SLICES_DIR/iossim/Headers" \
    -output "$XCFRAMEWORK_DIR"

echo "==> [8/8] Final verification"
if [ ! -f "$XCFRAMEWORK_DIR/Info.plist" ]; then
    echo "error: $XCFRAMEWORK_DIR/Info.plist missing" >&2
    exit 1
fi

# Check that each expected slice directory exists inside the XCFramework.
for needle in "macos-arm64_x86_64" "ios-arm64" "ios-arm64_x86_64-simulator"; do
    if ! ls "$XCFRAMEWORK_DIR" | grep -q "$needle"; then
        echo "error: expected slice '$needle' not found under $XCFRAMEWORK_DIR" >&2
        ls "$XCFRAMEWORK_DIR" >&2
        exit 1
    fi
done

# Architecture checks via lipo -info on the staged slice archives.
check_arches() {
    local path="$1"; shift
    local info
    info="$(lipo -info "$path")"
    for arch in "$@"; do
        if ! echo "$info" | grep -q "$arch"; then
            echo "error: $path missing expected arch '$arch' (got: $info)" >&2
            exit 1
        fi
    done
}
check_arches "$SLICES_DIR/macos/libgit2.a"   arm64 x86_64
check_arches "$SLICES_DIR/ios/libgit2.a"     arm64
check_arches "$SLICES_DIR/iossim/libgit2.a"  arm64 x86_64

# Header + modulemap existence checks.
for platform in macos ios iossim; do
    for required in "Headers/git2.h" "Headers/module.modulemap"; do
        test -f "$SLICES_DIR/$platform/$required" || {
            echo "error: $SLICES_DIR/$platform/$required missing" >&2
            exit 1
        }
    done
done

echo "==> Success: $XCFRAMEWORK_DIR"
du -sh "$XCFRAMEWORK_DIR"
```

- [ ] **Step 2: Run the full script end-to-end**

```bash
./scripts/build-xcframework.sh
```
Expected: exits 0, prints `==> Success: artifacts/libgit2.xcframework` and a size line.

- [ ] **Step 3: Verify the XCFramework layout**

```bash
ls artifacts/libgit2.xcframework
```
Expected: three directories (`ios-arm64`, `ios-arm64_x86_64-simulator`, `macos-arm64_x86_64`) plus `Info.plist`.

- [ ] **Step 4: Commit**

```bash
git add scripts/build-xcframework.sh
git commit -m "build: create XCFramework and verify slices, arches, headers"
```

---

## Task 7: Add the release script

**Files:**
- Create: `scripts/release-xcframework.sh`

- [ ] **Step 1: Write the script**

Create `scripts/release-xcframework.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

XCFRAMEWORK_DIR="artifacts/libgit2.xcframework"
XCFRAMEWORK_ZIP="artifacts/libgit2.xcframework.zip"

if [ ! -d "$XCFRAMEWORK_DIR" ]; then
    echo "error: $XCFRAMEWORK_DIR not found" >&2
    echo "hint: run ./scripts/build-xcframework.sh first" >&2
    exit 1
fi

echo "==> Zipping $XCFRAMEWORK_DIR"
rm -f "$XCFRAMEWORK_ZIP"
# Zip with paths relative to artifacts/ so the zip extracts cleanly.
(cd artifacts && zip -r -q "$(basename "$XCFRAMEWORK_ZIP")" "$(basename "$XCFRAMEWORK_DIR")")

size_bytes="$(stat -f%z "$XCFRAMEWORK_ZIP")"
checksum="$(swift package compute-checksum "$XCFRAMEWORK_ZIP")"

echo
echo "zip:       $XCFRAMEWORK_ZIP"
echo "size:      ${size_bytes} bytes"
echo "checksum:  $checksum"
echo
echo "Package.swift snippet (replace <owner>/<repo>/<tag>):"
cat <<SNIPPET
.binaryTarget(
    name: "Cgit2",
    url: "https://github.com/<owner>/<repo>/releases/download/<tag>/libgit2.xcframework.zip",
    checksum: "$checksum"
),
SNIPPET
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/release-xcframework.sh
```

- [ ] **Step 3: Run it**

```bash
./scripts/release-xcframework.sh
```
Expected: prints zip path, a nonzero size, a 64-hex-char checksum, and a snippet.

- [ ] **Step 4: Verify the zip**

```bash
test -f artifacts/libgit2.xcframework.zip
unzip -l artifacts/libgit2.xcframework.zip | head -5
```
Expected: zip exists; listing shows `libgit2.xcframework/` entries.

- [ ] **Step 5: Commit**

```bash
git add scripts/release-xcframework.sh
git commit -m "build: add release script (zip + compute-checksum)"
```

---

## Task 8: Write the smoke test first (red)

We write the test before wiring `Cgit2` into `Package.swift` so the test goes red first, then green when the binary target is hooked up.

**Files:**
- Modify: `Tests/libgit2.swiftTests/libgit2_swiftTests.swift`

- [ ] **Step 1: Replace the test file content**

Overwrite `Tests/libgit2.swiftTests/libgit2_swiftTests.swift` with:

```swift
import Testing
@testable import libgit2_swift

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

Note: Swift derives the module name from the target name by replacing `.` with `_`, so the target named `libgit2.swift` becomes the Swift module `libgit2_swift` (matches the existing file's import).

- [ ] **Step 2: Run the tests — should fail to build**

```bash
swift test 2>&1 | tail -20
```
Expected: compilation error because `git_libgit2_init` is undefined (no `Cgit2` yet). This is the expected red state.

- [ ] **Step 3: Commit the failing test**

```bash
git add Tests/libgit2.swiftTests/libgit2_swiftTests.swift
git commit -m "test: add smoke test for libgit2 init/shutdown/version"
```

---

## Task 9: Replace source scaffold with `Cgit2` re-export

**Files:**
- Modify: `Sources/libgit2.swift/libgit2_swift.swift`

- [ ] **Step 1: Overwrite the file**

Replace the contents of `Sources/libgit2.swift/libgit2_swift.swift` with:

```swift
@_exported import Cgit2
```

- [ ] **Step 2: Commit**

```bash
git add Sources/libgit2.swift/libgit2_swift.swift
git commit -m "feat: re-export Cgit2 from libgit2.swift"
```

---

## Task 10: Wire `Cgit2` binary target into `Package.swift` (local path, interim)

We use a local path `.binaryTarget` until a GitHub Release exists. The URL/checksum variant is introduced in Task 12 after a release has been cut.

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Replace `Package.swift` wholesale**

Overwrite the file with:

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
        .library(
            name: "libgit2.swift",
            targets: ["libgit2.swift"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "Cgit2",
            path: "artifacts/libgit2.xcframework"
        ),
        .target(
            name: "libgit2.swift",
            dependencies: ["Cgit2"]
        ),
        .testTarget(
            name: "libgit2.swiftTests",
            dependencies: ["libgit2.swift"]
        ),
    ]
)
```

- [ ] **Step 2: Run the tests — should now build and pass**

```bash
swift test
```
Expected: two tests pass (`initAndShutdown`, `reportsExpectedVersion`).

If the build fails with "missing required module 'Cgit2'", confirm `artifacts/libgit2.xcframework` exists (run `./scripts/build-xcframework.sh` if not).

- [ ] **Step 3: Commit**

```bash
git add Package.swift
git commit -m "feat: wire Cgit2 binaryTarget (local path) into Package.swift"
```

---

## Task 11: Document the operator workflow in the spec location

**Files:**
- Modify: `docs/superpowers/specs/2026-04-19-libgit2-xcframework-design.md`

- [ ] **Step 1: Append a short "Operator Runbook" section**

Append the following section (leave a blank line before it) to the end of the spec file:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-04-19-libgit2-xcframework-design.md
git commit -m "docs: add operator runbook to XCFramework design spec"
```

---

## Task 12 (post-release, manual): Switch `Package.swift` to URL binary target

This task happens once the first GitHub Release exists.

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Publish the Release**

Upload `artifacts/libgit2.xcframework.zip` (generated by Task 7) to a new GitHub Release under this repository. Record the download URL.

- [ ] **Step 2: Update `Package.swift`**

Replace this block:
```swift
        .binaryTarget(
            name: "Cgit2",
            path: "artifacts/libgit2.xcframework"
        ),
```

with:
```swift
        .binaryTarget(
            name: "Cgit2",
            url: "https://github.com/<owner>/<repo>/releases/download/<tag>/libgit2.xcframework.zip",
            checksum: "<sha256-from-release-xcframework.sh>"
        ),
```

Use the actual owner, repo, tag, and checksum.

- [ ] **Step 3: Verify a clean consumer build works**

```bash
rm -rf .build
swift build
swift test
```
Expected: `swift build` succeeds (SwiftPM downloads the zip from the Release), `swift test` passes both tests.

- [ ] **Step 4: Commit**

```bash
git add Package.swift
git commit -m "chore: point Cgit2 binaryTarget at published Release zip"
```

---

## Acceptance Verification (after Task 12)

- [ ] Fresh clone smoke test (optional but recommended)

```bash
cd $(mktemp -d)
git clone https://github.com/<owner>/<repo>.git && cd <repo>
swift build
swift test
```
Expected: build and test both pass **without** needing `git submodule update --init` — the binary target is self-contained.
