#!/bin/bash
set -e

# show path...
echo $PATH

if which jenkins_unlock_keychain >/dev/null; then
    jenkins_unlock_keychain
else
    echo "unlock-keychain: not running from Jenkins"
fi
