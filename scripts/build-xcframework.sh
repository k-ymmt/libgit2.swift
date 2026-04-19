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
