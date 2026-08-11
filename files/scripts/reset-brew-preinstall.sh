#!/usr/bin/env bash

set -euo pipefail

# Do not inherit Bluefin's image-managed Homebrew package declarations. The
# following files module repopulates this directory with this image's Brewfiles.
rm -rf -- /usr/share/ublue-os/homebrew/preinstall.d
