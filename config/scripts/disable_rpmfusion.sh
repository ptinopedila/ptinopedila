#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

for i in /etc/yum.repos.d/rpmfusion-*; do
    sed -i 's@enabled=1@enabled=0@g' "$i"
done
