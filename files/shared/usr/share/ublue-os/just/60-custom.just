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
    #   ujust configure-latex                     # Aux: build-latex/, PDF: project root
    #   ujust configure-latex .latex-build        # Override only the auxiliary directory
    #   ujust configure-latex .latex-build output # Override both directories
    AUX_DIR={{ quote(aux_dir) }}
    PDF_DIR={{ quote(pdf_dir) }}
    CONFIGURATOR="${PTINOPEDILA_LATEX_CONFIGURATOR:-/usr/libexec/ptinopedila/configure-latex}"

    exec "${CONFIGURATOR}" --aux-dir "${AUX_DIR}" --pdf-dir "${PDF_DIR}"

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
