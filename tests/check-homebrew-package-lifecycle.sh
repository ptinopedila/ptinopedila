#!/usr/bin/env bash

set -euo pipefail

repository_root=$(git rev-parse --show-toplevel)
brewfile_directory="$repository_root/files/shared/usr/share/ublue-os/homebrew/preinstall.d"

for command_name in brew jq; do
  if ! command -v "$command_name" >/dev/null; then
    echo "$command_name is required to check Homebrew package lifecycle metadata." >&2
    exit 1
  fi
done

mapfile -t formulae < <(
  sed -nE 's/^[[:space:]]*brew[[:space:]]+"([^"]+)".*/\1/p' \
    "$brewfile_directory"/*.Brewfile | sort -u
)
mapfile -t casks < <(
  sed -nE 's/^[[:space:]]*cask[[:space:]]+"([^"]+)".*/\1/p' \
    "$brewfile_directory"/*.Brewfile | sort -u
)

if (( ${#formulae[@]} == 0 && ${#casks[@]} == 0 )); then
  echo "No preinstalled Homebrew packages were found." >&2
  exit 1
fi

formula_metadata='{"formulae":[]}'
cask_metadata='{"casks":[]}'

if (( ${#formulae[@]} > 0 )); then
  formula_metadata=$(brew info --json=v2 "${formulae[@]}")
fi
if (( ${#casks[@]} > 0 )); then
  cask_metadata=$(brew info --json=v2 --cask "${casks[@]}")
fi

mapfile -t lifecycle_issues < <(
  jq -r '
    .formulae[]
    | select((.deprecated // false) or (.disabled // false))
    | [
        "formula",
        (.full_name // .name),
        (if .disabled then "disabled" else "deprecated" end),
        (if .disabled
         then (.disable_reason // "no reason provided")
         else (.deprecation_reason // "no reason provided")
         end),
        (.disable_replacement_formula
         // .disable_replacement_cask
         // .deprecation_replacement_formula
         // .deprecation_replacement_cask
         // "none")
      ]
    | @tsv
  ' <<< "$formula_metadata"
  jq -r '
    .casks[]
    | select((.deprecated // false) or (.disabled // false))
    | [
        "cask",
        (.full_token // .token),
        (if .disabled then "disabled" else "deprecated" end),
        (if .disabled
         then (.disable_reason // "no reason provided")
         else (.deprecation_reason // "no reason provided")
         end),
        (.disable_replacement_formula
         // .disable_replacement_cask
         // .deprecation_replacement_formula
         // .deprecation_replacement_cask
         // "none")
      ]
    | @tsv
  ' <<< "$cask_metadata"
)

if (( ${#lifecycle_issues[@]} > 0 )); then
  echo "Preinstalled Homebrew packages need attention:" >&2
  for issue in "${lifecycle_issues[@]}"; do
    IFS=$'\t' read -r package_type package_name status reason replacement <<< "$issue"
    printf '  - %s %s is %s: %s; replacement: %s\n' \
      "$package_type" "$package_name" "$status" "$reason" "$replacement" >&2
  done
  exit 1
fi

printf 'Checked %d formulae and %d casks; none are deprecated or disabled.\n' \
  "${#formulae[@]}" "${#casks[@]}"
