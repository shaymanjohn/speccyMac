#!/bin/bash
set -e

SCHEME=$1

SCRIPTS_DIR=$(dirname "${BASH_SOURCE[0]}")
cd "$SCRIPTS_DIR/.."

# Ensure a clean build
rm -rf build
echo "\n=== Building ===\n"
set -o pipefail && xcodebuild -scheme $SCHEME -configuration Debug build test -destination "platform=macOS,arch=x86_64" | /usr/local/bin/xcpretty -r junit

cd - >> /dev/null
