#!/usr/bin/env bash
# Build XrayKit.xcframework from the Go wrapper in ../XrayKit using gomobile.
#
# Prereqs (one-time):
#   brew install go
#   go install golang.org/x/mobile/cmd/gomobile@latest
#   go install golang.org/x/mobile/cmd/gobind@latest
#   export PATH="$PATH:$(go env GOPATH)/bin"
#   gomobile init
#
# Output:
#   Frameworks/XrayKit.xcframework  (drop into Xcode -> General -> Frameworks)
#
# Notes:
#   - gomobile produces an Objective-C framework; Swift imports via `import Xraykit`.
#   - The exported API lives in XrayKit/xraykit.go. Public package-level funcs
#     with primitive / []byte / string types become Swift functions.

set -euo pipefail

cd "$(dirname "$0")/.."
REPO_ROOT="$PWD"
XRAYKIT_DIR="$REPO_ROOT/XrayKit"
OUT_DIR="$REPO_ROOT/Frameworks"
OUT_FRAMEWORK="$OUT_DIR/XrayKit.xcframework"

command -v go        >/dev/null || { echo "ERROR: install Go (brew install go)"; exit 1; }
command -v gomobile  >/dev/null || { echo "ERROR: install gomobile (go install golang.org/x/mobile/cmd/gomobile@latest)"; exit 1; }

mkdir -p "$OUT_DIR"
rm -rf "$OUT_FRAMEWORK"

pushd "$XRAYKIT_DIR" >/dev/null

echo "→ go mod tidy"
go mod tidy

# Newer gomobile (>= Go 1.25) requires golang.org/x/mobile to be tracked
# as a tool dependency in this module. Idempotent — safe to re-run.
echo "→ go get -tool golang.org/x/mobile/cmd/gobind"
go get -tool golang.org/x/mobile/cmd/gobind

echo "→ gomobile bind (ios,iossimulator)"
# -target=ios produces device arm64 + simulator arm64+x86_64 inside one xcframework.
# -iosversion matches your Xcode IPHONEOS_DEPLOYMENT_TARGET (project uses 26.0).
gomobile bind \
    -target=ios,iossimulator \
    -iosversion=15.0 \
    -trimpath \
    -ldflags="-s -w" \
    -o "$OUT_FRAMEWORK" \
    .

popd >/dev/null

echo "✓ Built $OUT_FRAMEWORK"
echo
echo "Next: in Xcode, drag $OUT_FRAMEWORK into the project (target: PacketTunnel),"
echo "      set 'Embed & Sign' on the main app target and 'Do Not Embed' on the extension."
