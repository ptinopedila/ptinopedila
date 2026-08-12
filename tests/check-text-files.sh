#!/usr/bin/env bash

set -euo pipefail

repository_root=$(git rev-parse --show-toplevel)
cd "$repository_root"

failed=false
mapfile -d '' repository_files < <(
  {
    git ls-files -z
    git ls-files --others --exclude-standard -z
  } | sort -zu
)

for file_name in "${repository_files[@]}"; do
  [[ -f $file_name && -s $file_name ]] || continue

  # Skip binary files. An empty expression matches every non-binary text file.
  if ! LC_ALL=C grep -Iq '' "$file_name"; then
    continue
  fi

  if LC_ALL=C grep -nE '[[:blank:]]+$' "$file_name"; then
    echo "Trailing whitespace found in $file_name" >&2
    failed=true
  fi

  last_byte=$(tail -c 1 -- "$file_name" | od -An -tx1 | tr -d '[:space:]')
  if [[ $last_byte != 0a ]]; then
    echo "Missing final newline: $file_name" >&2
    failed=true
  fi
done

if [[ $failed == true ]]; then
  exit 1
fi
