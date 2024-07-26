#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

echo "Link libncurses.so.5 to libncurses.so.6 to support older stata versions"

ln -s /usr/lib64/libncurses.so.6 /usr/lib64/libncurses.so.5
