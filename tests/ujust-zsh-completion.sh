#!/usr/bin/env bash

set -euo pipefail

readonly repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly override="${repository_root}/files/shared/usr/share/zsh/site-functions/_ujust"
readonly system_completion="${SYSTEM_UJUST_COMPLETION:-/usr/share/zsh/site-functions/_ujust}"
readonly guard="${repository_root}/files/scripts/assert-inherited-ujust-completion.sh"
readonly test_directory="$(mktemp -d)"
trap 'rm -rf -- "${test_directory}"' EXIT

# Before the override exists, exercise the inherited completion so this test
# reproduces the original failure. Once the override exists, test that file.
completion="${override}"
if [[ ! -f ${completion} ]]; then
  completion="${system_completion}"
fi
if [[ ! -f ${completion} ]]; then
  echo "Missing ujust Zsh completion: ${completion}" >&2
  exit 1
fi

completion_context="$(COMPLETION_FILE="${completion}" zsh -f -c '
  compdef() { :; }
  words=(ujust install-r-wor)
  CURRENT=2
  _just() {
    print -r -- "${(j:|:)words}:$CURRENT"
  }
  source "$COMPLETION_FILE"
')"
expected_context='just|--justfile|/usr/share/ublue-os/just/00-entry.just|install-r-wor:4'
if [[ ${completion_context} != "${expected_context}" ]]; then
  echo "The ujust completion did not delegate with the expected context." >&2
  echo "Expected: ${expected_context}" >&2
  echo "Actual:   ${completion_context:-<empty>}" >&2
  exit 1
fi

if [[ ! -x ${guard} ]]; then
  echo "Missing executable inherited-completion guard: ${guard}" >&2
  exit 1
fi

printf '%s\n' \
  '#compdef ujust' \
  'source <(JUST_COMPLETE=zsh ujust)' \
  'if [ "$funcstack[1]" = "_ujust" ]; then' \
  '  _clap_dynamic_completer_ujust "$@"' \
  'fi' \
  > "${test_directory}/broken-_ujust"

UJUST_COMPLETION="${test_directory}/broken-_ujust" "${guard}"

printf '%s\n' \
  '#compdef ujust' \
  '_ujust() {' \
  '  _just' \
  '}' \
  '_ujust "$@"' \
  > "${test_directory}/changed-_ujust"

if UJUST_COMPLETION="${test_directory}/changed-_ujust" "${guard}" \
    > "${test_directory}/guard-output" 2>&1; then
  echo "The guard accepted a changed inherited completion." >&2
  exit 1
fi
grep -Fq 'The inherited ujust Zsh completion has changed.' \
  "${test_directory}/guard-output"

echo "ujust Zsh completion tests passed."
