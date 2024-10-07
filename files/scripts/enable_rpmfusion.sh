#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

# # Renenable RPMFusion
# # https://github.com/ublue-os/bluefin/commit/b9cf82c3fa5760b6e29308ce4da6a048feeb9cf9
# sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/rpmfusion-{,non}free.repo
# sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/rpmfusion-{,non}free-updates.repo
# sed -i '0,/enabled=0/s//enabled=1/' /etc/yum.repos.d/rpmfusion-{,non}free-updates-testing.repo
