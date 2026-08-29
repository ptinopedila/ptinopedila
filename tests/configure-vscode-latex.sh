#!/usr/bin/env bash

set -euo pipefail

repository_root=$(git rev-parse --show-toplevel)
justfile="$repository_root/files/shared/usr/share/ublue-os/just/60-custom.just"
configurator="$repository_root/files/shared/usr/libexec/ptinopedila/configure-vscode-latex"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/ptinopedila-vscode-latex-test.XXXXXXXX")
trap 'rm -rf -- "$test_root"' EXIT

project_directory="$test_root/project"
offline_project_directory="$test_root/offline-project"
runtime_directory="$test_root/runtime"
bin_directory="$test_root/bin"
code_state="$runtime_directory/code-extensions"
code_log="$runtime_directory/code.log"
curl_mode="$runtime_directory/curl-mode"
curl_log="$runtime_directory/curl.log"
latex_config_log="$runtime_directory/configure-latex.log"
mkdir -p \
  "$project_directory/.vscode" \
  "$offline_project_directory/.vscode" \
  "$runtime_directory" \
  "$bin_directory"

cat > "$project_directory/.vscode/settings.json" <<'EOF'
{
  "editor.tabSize": 4,
  "latex-workshop.latex.tools": [
    {"name": "custom", "command": "custom", "args": []}
  ],
  "latex-workshop.latex.recipes": [
    {"name": "custom", "tools": ["custom"]}
  ],
  "[latex]": {
    "editor.wordWrap": "on"
  }
}
EOF
cat > "$project_directory/.vscode/extensions.json" <<'EOF'
{
  "recommendations": [
    "james-yu.latex-workshop",
    "example.other-extension"
  ],
  "unwantedRecommendations": ["example.unwanted-extension"]
}
EOF
printf '{}\n' > "$offline_project_directory/.vscode/settings.json"
printf 'james-yu.latex-workshop\n' > "$code_state"
printf 'success\n' > "$curl_mode"

cat > "$bin_directory/configure-latex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$LATEX_CONFIG_LOG"
EOF

cat > "$bin_directory/code" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  --list-extensions)
    cat "$CODE_STATE"
    ;;
  --install-extension)
    printf '%s\n' "$2" >> "$CODE_LOG"
    printf '%s\n' "$2" >> "$CODE_STATE"
    ;;
  *)
    exit 2
    ;;
esac
EOF

cat > "$bin_directory/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$CURL_LOG"
if [[ $(cat "$CURL_MODE") == success ]]; then
  printf '{"matches": []}\n'
else
  exit 7
fi
EOF

for command_name in latexmk chktex latexindent; do
  cat > "$bin_directory/$command_name" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
done
chmod +x "$bin_directory"/*

run_configurator() {
  local working_directory=$1
  shift
  (
    cd "$working_directory"
    CODE_LOG="$code_log" CODE_STATE="$code_state" \
      CURL_LOG="$curl_log" CURL_MODE="$curl_mode" \
      LATEX_CONFIG_LOG="$latex_config_log" \
      PTINOPEDILA_LATEX_CONFIGURATOR="$bin_directory/configure-latex" \
      PTINOPEDILA_VSCODE_LATEX_CONFIGURATOR="$configurator" \
      PATH="$bin_directory:$PATH" XDG_RUNTIME_DIR="$runtime_directory" \
      just --unstable --justfile "$justfile" \
      configure-vscode-latex "$@"
  )
}

run_configurator "$project_directory"

[[ $(cat "$code_log") == "ltex-plus.vscode-ltex-plus" ]]
[[ $(wc -l < "$code_state") -eq 2 ]]
[[ $(cat "$latex_config_log") == "--aux-dir build-latex --pdf-dir ." ]]
grep -Fq 'http://localhost:8081/v2/check' "$curl_log"

jq --exit-status '
  .["editor.tabSize"] == 4 and
  .["latex-workshop.latex.outDir"] == "%WORKSPACE_FOLDER%/build-latex/%RELATIVE_DIR%" and
  .["latex-workshop.latex.recipe.default"] == "first" and
  .["latex-workshop.linting.chktex.enabled"] == true and
  .["latex-workshop.linting.run"] == "onSave" and
  .["latex-workshop.formatting.latex"] == "latexindent" and
  .["[latex]"]["editor.defaultFormatter"] == "James-Yu.latex-workshop" and
  .["[latex]"]["editor.formatOnSave"] == true and
  .["[latex]"]["editor.wordWrap"] == "on" and
  .["ltex.languageToolHttpServerUri"] == "http://localhost:8081" and
  (.["latex-workshop.latex.tools"] | map(.name)) == ["latexmk-project-config", "custom"] and
  (.["latex-workshop.latex.recipes"] | map(.name)) == ["latexmk (project config)", "custom"]
' "$project_directory/.vscode/settings.json" >/dev/null

jq --exit-status '
  .recommendations == [
    "James-Yu.latex-workshop",
    "ltex-plus.vscode-ltex-plus",
    "example.other-extension"
  ] and
  .unwantedRecommendations == ["example.unwanted-extension"]
' "$project_directory/.vscode/extensions.json" >/dev/null

first_checksum=$(sha256sum \
  "$project_directory/.vscode/settings.json" \
  "$project_directory/.vscode/extensions.json")
run_configurator "$project_directory"
second_checksum=$(sha256sum \
  "$project_directory/.vscode/settings.json" \
  "$project_directory/.vscode/extensions.json")
[[ $first_checksum == "$second_checksum" ]]
[[ $(wc -l < "$code_log") -eq 1 ]]
[[ $(wc -l < "$latex_config_log") -eq 2 ]]

printf 'failure\n' > "$curl_mode"
run_configurator \
  "$offline_project_directory" \
  --languagetool-host=grammar.example \
  --languagetool-port=8082

jq --exit-status '
  has("ltex.languageToolHttpServerUri") | not
' "$offline_project_directory/.vscode/settings.json" >/dev/null
tail -n 1 "$curl_log" | grep -Fq 'http://grammar.example:8082/v2/check'
[[ $(wc -l < "$code_log") -eq 1 ]]

latex_config_count=$(wc -l < "$latex_config_log")
if run_configurator \
  "$offline_project_directory" \
  --languagetool-port=0 >/dev/null 2>&1; then
  echo "VS Code configurator unexpectedly accepted port 0." >&2
  exit 1
fi
[[ $(wc -l < "$latex_config_log") -eq "$latex_config_count" ]]

echo "VS Code LaTeX configurator tests passed."
