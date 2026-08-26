#!/usr/bin/env bash

set -euo pipefail

# Ptinopedila's CUDA container support relies on this package from the upstream
# Bluefin NVIDIA image. Fail the image build if upstream stops providing it.
if ! rpm -q nvidia-container-toolkit-base >/dev/null; then
    echo "Required upstream package is missing: nvidia-container-toolkit-base" >&2
    exit 1
fi
