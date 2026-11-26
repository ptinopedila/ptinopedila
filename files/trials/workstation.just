# Keep inherited commands while Ptinopedila recipes take precedence.
_default:
    @ujust --list

import "/usr/share/ublue-os/just/00-ptinopedila-upstream.just"
import "/usr/share/ublue-os/just/90-ptinopedila.just"
import "/usr/share/ublue-os/just/91-ptinopedila-report.just"

# Apply the downstream package selection rather than Bluefin CLI defaults.
bluefin-cli: install-ptinopedila-brew

# The trial images publish only their own latest channel.
toggle-testing:
    @echo "This trial has no stable/testing channel switch. Use the explicit trial image reference."
    @exit 1

# Open the downstream source history.
changelogs:
    xdg-open https://github.com/ptinopedila/ptinopedila/commits/main/
