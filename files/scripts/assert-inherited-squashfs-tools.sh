#!/usr/bin/env bash

set -euo pipefail

# Ptinopedila uses Bluefin's squashfs-tools RPM. Run this before downstream DNF
# modules so an upstream removal fails the image build and prompts an explicit
# decision about adding Homebrew's squashfs formula.
if ! rpm -q squashfs-tools >/dev/null; then
    echo "Required upstream package is missing: squashfs-tools" >&2
    echo "Review whether Ptinopedila should add Homebrew's squashfs formula." >&2
    exit 1
fi
