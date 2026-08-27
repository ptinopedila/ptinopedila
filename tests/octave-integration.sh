#!/usr/bin/env bash

set -euo pipefail

# Verify that Octave remains a Homebrew-owned command and that the image does
# not expose Homebrew's shared application directory to every user.

repository_root=$(git rev-parse --show-toplevel)
environment_file="$repository_root/files/shared/usr/lib/environment.d/20-ptinopedila-homebrew.conf"
system_wrapper="$repository_root/files/shared/usr/bin/octave"

[[ ! -e $system_wrapper ]]
if grep -Eq '^XDG_DATA_DIRS=' "$environment_file"; then
    echo "The image exposes Homebrew's shared data directory globally." >&2
    exit 1
fi
if grep -Eq '^QT_PLUGIN_PATH=' "$environment_file"; then
    echo "The image sets a global Qt plugin path." >&2
    exit 1
fi

echo "Octave integration tests passed."
