#!/usr/bin/env bash

# Tell build process to exit if there are any errors.
set -oue pipefail

git clone https://github.com/zdharma-continuum/fast-syntax-highlighting /usr/share/fsh

echo 'source /usr/share/fsh/fast-syntax-highlighting.plugin.zsh' >> /etc/zshrc
