# Install the Ptinopedila Homebrew bundle after switching images
[group('System')]
install-ptinopedila-brew:
    #!/usr/bin/env bash
    set -euo pipefail
    BREWFILE="/usr/share/ublue-os/homebrew/preinstall.d/ptinopedila-cli.Brewfile"

    if command -v brew >/dev/null 2>&1; then
        BREW="$(command -v brew)"
    elif [ -x /var/home/linuxbrew/.linuxbrew/bin/brew ]; then
        BREW="/var/home/linuxbrew/.linuxbrew/bin/brew"
    else
        echo "Homebrew is not available on this image." >&2
        exit 1
    fi

    if [ ! -f "${BREWFILE}" ]; then
        echo "Missing ${BREWFILE}" >&2
        exit 1
    fi

    "${BREW}" bundle --file="${BREWFILE}"

    echo
    echo "Ptinopedila Homebrew bundle installed."
    echo "Open a new terminal if newly installed commands are not yet on PATH."

# Configure the current project to build LaTeX documents with latexmk.
[group('Development')]
configure-latex aux_dir="build-latex" pdf_dir=".":
    #!/usr/bin/env bash
    set -euo pipefail

    # Usage:
    #   ujust configure-latex                     # Aux: build-latex/, PDF: project root
    #   ujust configure-latex .latex-build        # Override only the auxiliary directory
    #   ujust configure-latex .latex-build output # Override both directories
    AUX_DIR={{ quote(aux_dir) }}
    PDF_DIR={{ quote(pdf_dir) }}

    preserve_mode() {
        local destination="$1"
        local replacement="$2"
        if [[ -f "${destination}" ]]; then
            chmod --reference="${destination}" "${replacement}"
        else
            chmod 0644 "${replacement}"
        fi
    }

    for dir in "${AUX_DIR}" "${PDF_DIR}"; do
        if [[ -z "${dir}" || "${dir}" = /* || ! "${dir}" =~ ^[A-Za-z0-9._/-]+$ || "/${dir}/" = *"/../"* ]]; then
            echo "LaTeX output directories must be safe, relative project paths: ${dir}" >&2
            exit 1
        fi
    done
    if [[ "${AUX_DIR}" = "." ]]; then
        echo "AUX_DIR must not be the project root." >&2
        exit 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo "jq is required to merge .vscode/settings.json safely." >&2
        exit 1
    fi

    AUX_DIR="${AUX_DIR%/}"
    PDF_DIR="${PDF_DIR%/}"
    [[ -n "${PDF_DIR}" ]] || PDF_DIR="."

    mkdir -p .vscode
    settings_tmp="$(mktemp .vscode/settings.json.XXXXXX)"
    if [[ -f .vscode/settings.json ]]; then
        settings_input=".vscode/settings.json"
    else
        settings_input="/dev/null"
        printf '{}\n' > "${settings_tmp}.new"
        settings_input="${settings_tmp}.new"
    fi

    if ! jq --indent 2 \
        --arg out_dir "%DIR%/${AUX_DIR}" \
        --arg tool_name "latexmk-project-config" \
        '
        .["latex-workshop.latex.outDir"] = $out_dir
        | .["latex-workshop.latex.tools"] = (
            [{
                "name": $tool_name,
                "command": "latexmk",
                "args": [
                    "-pdf",
                    "-synctex=1",
                    "-interaction=nonstopmode",
                    "-file-line-error",
                    "%DOC%"
                ]
            }]
            + ((.["latex-workshop.latex.tools"] // []) | map(select(.name != $tool_name)))
        )
        | .["latex-workshop.latex.recipes"] = (
            [{"name": "latexmk (project config)", "tools": [$tool_name]}]
            + ((.["latex-workshop.latex.recipes"] // [])
                | map(select(.name != "latexmk (project config)")))
        )
        | .["latex-workshop.latex.recipe.default"] = "first"
        ' "${settings_input}" > "${settings_tmp}"; then
        rm -f "${settings_tmp}" "${settings_tmp}.new"
        echo ".vscode/settings.json must contain valid JSON before it can be merged." >&2
        exit 1
    fi
    preserve_mode .vscode/settings.json "${settings_tmp}"
    mv "${settings_tmp}" .vscode/settings.json
    rm -f "${settings_tmp}.new"

    gitignore_begin="# >>> ptinopedila latex build >>>"
    gitignore_end="# <<< ptinopedila latex build <<<"
    gitignore_tmp="$(mktemp .gitignore.XXXXXX)"
    [[ -f .gitignore ]] || : > .gitignore
    awk -v begin="${gitignore_begin}" -v end="${gitignore_end}" '
        $0 == begin { managed = 1; next }
        $0 == end { managed = 0; next }
        !managed { print }
    ' .gitignore > "${gitignore_tmp}"
    printf '\n%s\n/%s/\n%s\n' \
        "${gitignore_begin}" "${AUX_DIR}" "${gitignore_end}" >> "${gitignore_tmp}"
    preserve_mode .gitignore "${gitignore_tmp}"
    mv "${gitignore_tmp}" .gitignore

    latexmk_begin="# >>> ptinopedila latex build >>>"
    latexmk_end="# <<< ptinopedila latex build <<<"
    latexmk_tmp="$(mktemp .latexmkrc.XXXXXX)"
    [[ -f .latexmkrc ]] || : > .latexmkrc
    awk -v begin="${latexmk_begin}" -v end="${latexmk_end}" '
        $0 == begin { managed = 1; next }
        $0 == end { managed = 0; next }
        !managed { print }
    ' .latexmkrc > "${latexmk_tmp}"
    printf '\n%s\n' "${latexmk_begin}" >> "${latexmk_tmp}"
    printf '%s\n' \
        '# Keep auxiliary files and the intermediate PDF together.' \
        "\$aux_dir = '${AUX_DIR}';" \
        "\$out_dir = '${AUX_DIR}';" \
        '# Copy only the final PDF to the separately configured destination.' \
        "\$out2_dir = '${PDF_DIR}';" \
        "@out2_exts = ('pdf');" \
        "${latexmk_end}" >> "${latexmk_tmp}"
    preserve_mode .latexmkrc "${latexmk_tmp}"
    mv "${latexmk_tmp}" .latexmkrc

    echo "LaTeX project configured: auxiliary files -> ${AUX_DIR}/, PDFs -> ${PDF_DIR}"

enable-cups:
    firewall-cmd --permanent --add-port=631/tcp
    firewall-cmd --permanent --add-port=631/udp 
    firewall-cmd --reload 
    systemctl unmask cups
    systemctl enable cups
    systemctl start cups
