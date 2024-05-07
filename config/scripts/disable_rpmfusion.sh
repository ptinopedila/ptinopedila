#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

# https://github.com/ublue-os/bluefin/commit/b9cf82c3fa5760b6e29308ce4da6a048feeb9cf9
for i in /etc/yum.repos.d/rpmfusion-*; do
    sed -i 's@enabled=1@enabled=0@g' "$i"
done