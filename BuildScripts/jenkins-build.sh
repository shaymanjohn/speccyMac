#!/bin/bash
set -e

SCHEME=$1

rm -rf build

BUILD_SCRIPTS_DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$BUILD_SCRIPTS_DIR/.."

echo "=== Building speccyMac ==="
set -o pipefail && xcodebuild -scheme $SCHEME -configuration Debug build -destination "platform=macOS,arch=x86_64"

cd - >> /dev/null
