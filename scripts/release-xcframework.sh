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
