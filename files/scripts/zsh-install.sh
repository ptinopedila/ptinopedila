#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

# Install fast-syntax-highlighting
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting /usr/share/fsh
