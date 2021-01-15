#!/bin/bash
set -e

if which swiftlint >/dev/null; then
    echo "skip unlock keychain"
else
    echo "running unlock keychain"
    ./~/scripts/jenkins_unlock_keychain
fi
