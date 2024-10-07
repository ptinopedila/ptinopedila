#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

# Enable RPMFusion
# https://github.com/ublue-os/bluefin/commit/b9cf82c3fa5760b6e29308ce4da6a048feeb9cf9
# https://github.com/ublue-os/bluefin/pull/1748/files

rpm-ostree install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
