#!/usr/bin/env bash

set -euo pipefail

repository_root=$(git rev-parse --show-toplevel)
justfile="$repository_root/files/shared/usr/share/ublue-os/just/60-custom.just"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-latex-test.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

project_directory="$test_root/project"
runtime_directory="$test_root/runtime"
mkdir -p "$project_directory/.vscode" "$runtime_directory"
printf '{"editor.tabSize": 4}\n' > "$project_directory/.vscode/settings.json"
printf '/existing-entry\n' > "$project_directory/.gitignore"
printf '\$pdf_mode = 1;\n' > "$project_directory/.latexmkrc"

run_configurator() {
  XDG_RUNTIME_DIR="$runtime_directory" just --unstable --justfile "$justfile" \
    --working-directory "$project_directory" configure-latex
}

run_configurator

jq --exit-status '
  .["editor.tabSize"] == 4 and
  .["latex-workshop.latex.outDir"] == "%DIR%/build-latex" and
  .["latex-workshop.latex.recipe.default"] == "first"
' "$project_directory/.vscode/settings.json" >/dev/null
grep -Fxq '/existing-entry' "$project_directory/.gitignore"
grep -Fxq '/build-latex/' "$project_directory/.gitignore"
grep -Fxq '\$pdf_mode = 1;' "$project_directory/.latexmkrc"
grep -Fxq "\$out2_dir = '.';" "$project_directory/.latexmkrc"

first_checksum=$(sha256sum \
  "$project_directory/.vscode/settings.json" \
  "$project_directory/.gitignore" \
  "$project_directory/.latexmkrc")
run_configurator
second_checksum=$(sha256sum \
  "$project_directory/.vscode/settings.json" \
  "$project_directory/.gitignore" \
  "$project_directory/.latexmkrc")
[[ $first_checksum == "$second_checksum" ]]

if XDG_RUNTIME_DIR="$runtime_directory" just --unstable --justfile "$justfile" \
  --working-directory "$project_directory" configure-latex ../outside \
  >/dev/null 2>&1; then
  echo "Configurator unexpectedly accepted a parent-directory path." >&2
  exit 1
fi

echo "LaTeX configurator tests passed."
