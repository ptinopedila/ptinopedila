# Apply all image-managed Ptinopedila Homebrew bundles after switching images.
[group('System')]
install-ptinopedila-brew:
    #!/usr/bin/env bash
    set -euo pipefail
    BREWFILE_DIR="/usr/share/ublue-os/homebrew/preinstall.d"

    if command -v brew >/dev/null 2>&1; then
        BREW="$(command -v brew)"
    elif [ -x /var/home/linuxbrew/.linuxbrew/bin/brew ]; then
        BREW="/var/home/linuxbrew/.linuxbrew/bin/brew"
    else
        echo "Homebrew is not available on this image." >&2
        exit 1
    fi

    shopt -s nullglob
    BREWFILES=("${BREWFILE_DIR}"/*.Brewfile)
    if [ "${#BREWFILES[@]}" -eq 0 ]; then
        echo "No Brewfiles found under ${BREWFILE_DIR}." >&2
        exit 1
    fi

    "${BREW}" trust --tap ublue-os/tap
    "${BREW}" trust --tap frostyard/tap
    for brewfile in "${BREWFILES[@]}"; do
        "${BREW}" bundle --file="${brewfile}"
    done

    echo
    echo "Ptinopedila Homebrew bundles installed."
    echo "Open a new terminal if newly installed commands are not yet on PATH."

# Report unmanaged Homebrew packages, Flatpaks, and layered RPMs.
[arg('config', long='config')]
[arg('help', long='help', short='h', value='true')]
[arg('output', long='output')]
[arg('save', long='save', value='true')]
[group('System')]
[positional-arguments]
package-audit save="false" output="" config="" help="false":
    #!/usr/bin/env bash
    set -euo pipefail

    AUDITOR="${PTINOPEDILA_PACKAGE_AUDITOR:-/usr/libexec/ptinopedila/package-audit}"
    ARGS=()

    if [[ $1 == "true" ]]; then
        ARGS+=(--save)
    fi
    if [[ -n $2 ]]; then
        ARGS+=(--output "$2")
    fi
    if [[ -n $3 ]]; then
        ARGS+=(--config "$3")
    fi
    if [[ $4 == "true" ]]; then
        ARGS+=(--help)
    fi

    exec "$AUDITOR" "${ARGS[@]}"

# Install a bare dotfiles repository into the current user's home directory.
[group('Setup')]
install-dotfiles source second="" third="":
    #!/usr/bin/env bash
    set -euo pipefail

    SOURCE={{ quote(source) }}
    SECOND={{ quote(second) }}
    THIRD={{ quote(third) }}
    INSTALLER="${PTINOPEDILA_DOTFILES_INSTALLER:-/usr/libexec/ptinopedila/install-dotfiles}"

    if [[ "${SOURCE}" == "--github" ]]; then
        if [[ -z "${SECOND}" || -z "${THIRD}" ]]; then
            echo "Usage: ujust install-dotfiles --github <username> <repository>" >&2
            exit 1
        fi
        exec "${INSTALLER}" "${SOURCE}" "${SECOND}" "${THIRD}"
    fi

    if [[ -n "${SECOND}" || -n "${THIRD}" ]]; then
        echo "Usage: ujust install-dotfiles <repository-url>" >&2
        exit 1
    fi
    exec "${INSTALLER}" "${SOURCE}"

# Install Miniconda (default) or Anaconda without modifying shell startup files.
[group('Setup')]
install-conda distribution="miniconda":
    #!/usr/bin/env bash
    set -euo pipefail

    # Usage:
    #   ujust install-conda          # Install Miniconda (default)
    #   ujust install-conda anaconda # Install the Anaconda distribution
    DISTRIBUTION={{ quote(distribution) }}
    INSTALLER="${PTINOPEDILA_CONDA_INSTALLER:-/usr/libexec/ptinopedila/install-conda}"

    exec "${INSTALLER}" --distribution "${DISTRIBUTION}"

# Install Dynare with Homebrew Octave and configure it for the current user.
[group('Setup')]
install-dynare:
    #!/usr/bin/env bash
    set -euo pipefail

    INSTALLER="${PTINOPEDILA_DYNARE_INSTALLER:-/usr/libexec/ptinopedila/install-dynare}"

    exec "${INSTALLER}"

# Install a local LanguageTool server with the shared English n-gram model.
[arg('no_service', long='no-service', value='true')]
[arg('port', long='port')]
[group('Setup')]
[positional-arguments]
install-languagetool no_service="false" port="":
    #!/usr/bin/env bash
    set -euo pipefail

    INSTALLER="${PTINOPEDILA_LANGUAGETOOL_INSTALLER:-/usr/libexec/ptinopedila/install-languagetool}"
    ARGS=()

    if [[ $1 == "true" ]]; then
        ARGS+=(--no-service)
    fi
    if [[ -n $2 ]]; then
        ARGS+=("--port=$2")
    fi

    exec "${INSTALLER}" "${ARGS[@]}"

# Configure the current project to build LaTeX documents with latexmk.
[group('Development')]
[no-cd]
configure-latex aux_dir="build-latex" pdf_dir=".":
    #!/usr/bin/env bash
    set -euo pipefail

    # Usage:
    #   ujust configure-latex                     # Aux: build-latex/<source dir>/, PDF: beside source
    #   ujust configure-latex .latex-build        # Override only the auxiliary base directory
    #   ujust configure-latex .latex-build output # Mirror source directories under both bases
    AUX_DIR={{ quote(aux_dir) }}
    PDF_DIR={{ quote(pdf_dir) }}
    CONFIGURATOR="${PTINOPEDILA_LATEX_CONFIGURATOR:-/usr/libexec/ptinopedila/configure-latex}"

    exec "${CONFIGURATOR}" --aux-dir "${AUX_DIR}" --pdf-dir "${PDF_DIR}"

# Configure the current LaTeX project for VS Code with LaTeX Workshop and LTeX+.
[arg('languagetool_host', long='languagetool-host')]
[arg('languagetool_port', long='languagetool-port')]
[group('Development')]
[no-cd]
[positional-arguments]
configure-vscode-latex aux_dir="build-latex" pdf_dir="." languagetool_host="localhost" languagetool_port="8081":
    #!/usr/bin/env bash
    set -euo pipefail

    # Usage:
    #   ujust configure-vscode-latex
    #   ujust configure-vscode-latex .latex-build output
    #   ujust configure-vscode-latex --languagetool-host=localhost --languagetool-port=8082
    AUX_DIR={{ quote(aux_dir) }}
    PDF_DIR={{ quote(pdf_dir) }}
    LANGUAGETOOL_HOST={{ quote(languagetool_host) }}
    LANGUAGETOOL_PORT={{ quote(languagetool_port) }}
    CONFIGURATOR="${PTINOPEDILA_VSCODE_LATEX_CONFIGURATOR:-/usr/libexec/ptinopedila/configure-vscode-latex}"

    exec "${CONFIGURATOR}" \
        --aux-dir "${AUX_DIR}" \
        --pdf-dir "${PDF_DIR}" \
        --languagetool-host "${LANGUAGETOOL_HOST}" \
        --languagetool-port "${LANGUAGETOOL_PORT}"

# Enable or disable this PC's Tailscale exit-node advertisement.
[group('System')]
toggle-exitnode action="":
    #!/usr/bin/env bash
    set -euo pipefail

    ACTION={{ quote(action) }}
    TOGGLER="${PTINOPEDILA_EXITNODE_TOGGLER:-/usr/libexec/ptinopedila/toggle-exitnode}"

    if [[ -n "${ACTION}" ]]; then
        exec "${TOGGLER}" "${ACTION}"
    fi
    exec "${TOGGLER}"

# Enable CUPS and open the IPP ports in the persistent firewall configuration.
[confirm("Enable CUPS and open its firewall ports?")]
enable-cups:
    sudo firewall-cmd --permanent --add-port=631/tcp
    sudo firewall-cmd --permanent --add-port=631/udp
    sudo firewall-cmd --reload
    sudo systemctl unmask cups.service cups.socket
    sudo systemctl enable --now cups.service cups.socket
    echo "CUPS enabled. Automatic network-printer discovery remains disabled."

# Disable CUPS and reverse the firewall changes made by `ujust enable-cups`.
[confirm("Disable CUPS and remove its firewall rules?")]
disable-cups:
    sudo systemctl disable --now cups.service cups.socket
    sudo systemctl mask --now cups.service cups.socket cups-browsed.service
    sudo firewall-cmd --permanent --remove-port=631/tcp
    sudo firewall-cmd --permanent --remove-port=631/udp
    sudo firewall-cmd --reload
