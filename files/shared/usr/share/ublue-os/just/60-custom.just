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

enable-cups:
    firewall-cmd --permanent --add-port=631/tcp
    firewall-cmd --permanent --add-port=631/udp 
    firewall-cmd --reload 
    systemctl unmask cups
    systemctl enable cups
    systemctl start cups
