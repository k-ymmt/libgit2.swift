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
