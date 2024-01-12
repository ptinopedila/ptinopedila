#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

sed -i '/^PRETTY_NAME/s/Bluefin/ptinopedila/' /usr/lib/os-release
