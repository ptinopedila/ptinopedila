#!/usr/bin/env bash

set -euo pipefail

repository_root=$(git rev-parse --show-toplevel)
justfile="$repository_root/files/shared/usr/share/ublue-os/just/60-custom.just"
configurator="$repository_root/files/shared/usr/libexec/ptinopedila/configure-latex"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-latex-test.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

project_directory="$test_root/project"
runtime_directory="$test_root/runtime"
bin_directory="$test_root/bin"
brew_state="$runtime_directory/brew-state"
brew_log="$runtime_directory/brew.log"
mkdir -p "$project_directory/.vscode" "$runtime_directory" "$bin_directory"
printf '{"editor.tabSize": 4}\n' > "$project_directory/.vscode/settings.json"
printf '/existing-entry\n' > "$project_directory/.gitignore"
printf '\$pdf_mode = 1;\n' > "$project_directory/.latexmkrc"

cat > "$bin_directory/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ $1 == list && $2 == --formula ]]; then
  grep -Fxq "$3" "$BREW_STATE" 2>/dev/null
elif [[ $1 == install ]]; then
  printf 'install' >> "$BREW_LOG"
  shift
  for formula in "$@"; do
    printf ' %s' "$formula" >> "$BREW_LOG"
    printf '%s\n' "$formula" >> "$BREW_STATE"
  done
  printf '\n' >> "$BREW_LOG"
else
  exit 2
fi
EOF
chmod +x "$bin_directory/brew"

run_configurator() {
  (
    cd "$project_directory"
    BREW_LOG="$brew_log" BREW_STATE="$brew_state" \
      PTINOPEDILA_LATEX_CONFIGURATOR="$configurator" \
      PATH="$bin_directory:$PATH" XDG_RUNTIME_DIR="$runtime_directory" \
      just --unstable --justfile "$justfile" \
      configure-latex "$@"
  )
}

run_configurator

[[ $(cat "$brew_log") == "install biber latexdiff latexindent pandoc texlive" ]]

jq --exit-status '
  .["editor.tabSize"] == 4 and
  .["latex-workshop.latex.outDir"] == "%WORKSPACE_FOLDER%/build-latex/%RELATIVE_DIR%" and
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
[[ $(wc -l < "$brew_log") -eq 1 ]]

run_configurator .latex-build output
jq --exit-status '
  .["latex-workshop.latex.outDir"] == "%WORKSPACE_FOLDER%/.latex-build/%RELATIVE_DIR%"
' "$project_directory/.vscode/settings.json" >/dev/null
grep -Fxq '/.latex-build/' "$project_directory/.gitignore"
grep -Fxq "\$out2_dir = 'output';" "$project_directory/.latexmkrc"
[[ $(wc -l < "$brew_log") -eq 1 ]]

if (
  cd "$project_directory"
  BREW_LOG="$brew_log" BREW_STATE="$brew_state" \
    PTINOPEDILA_LATEX_CONFIGURATOR="$configurator" \
    PATH="$bin_directory:$PATH" XDG_RUNTIME_DIR="$runtime_directory" \
    just --unstable --justfile "$justfile" \
    configure-latex ../outside >/dev/null 2>&1
); then
  echo "Configurator unexpectedly accepted a parent-directory path." >&2
  exit 1
fi

echo "LaTeX configurator tests passed."
