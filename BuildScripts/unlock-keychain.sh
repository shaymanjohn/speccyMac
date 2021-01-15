#!/bin/bash
set -e

if which jenkins_unlock_keychain >/dev/null; then
    jenkins_unlock_keychain
else
    echo "unlock-keychain: not running from Jenkins"
fi
