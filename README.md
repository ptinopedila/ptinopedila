# Ptinopedila

[![Build images](https://github.com/ptinopedila/ptinopedila/actions/workflows/build.yml/badge.svg)](https://github.com/ptinopedila/ptinopedila/actions/workflows/build.yml)

> [!WARNING]
> Ptinopedila is an experimental personal project, not an official Fedora,
> Universal Blue, or Bluefin image. Keep a working rollback deployment and test
> it in a virtual machine before relying on it.

The project provides a streamlined workstation for economists and data
scientists, with an emphasis on reproducible academic workflows.

## Images

### Home

Both published images follow [Bluefin](https://projectbluefin.io/)'s `stable`
stream:

| Image | Intended hardware |
|---|---|
| `ptinopedila-home` | Systems using the standard Bluefin image |
| `ptinopedila-home-nvidia` | Systems requiring Bluefin's NVIDIA image |

Both images are scheduled to build daily at 04:00 in `Europe/Athens`,
with automatic adjustment for daylight saving time.
GitHub Actions may delay the start, and images are published after a successful build.

Each build upgrades installed RPM packages from the enabled repositories,
subject to dependency constraints, repository exclusions, and version locks.
Bluefin's kernel, external kernel modules, and matched NVIDIA driver packages
stay at the versions supplied by the base image to preserve their compatibility.
Any inherited ZFS packages and their companion libraries stay matched too.
These exclusions apply to the build's upgrade command.
Excluded packages receive fixes through newer Bluefin base images.
NVIDIA container tooling, GPU firmware, `kernel-tools`, and `kernel-headers`
remain eligible for upgrades.
Homebrew and Flatpak applications update separately on the installed system.

## Documentation

This project is based on [Universal Blue](https://universal-blue.org/) and
[Bluefin](https://projectbluefin.io/). It aims to remain close to upstream
while documenting Ptinopedila-specific changes.

For economics-specific tools and programs, open an issue in this repository.

For upstream concepts and administration, see the
[Universal Blue website](https://universal-blue.org/) and
[Bluefin documentation](https://docs.projectbluefin.io/).

Ptinopedila-specific guides:

- [Install and manage applications](docs/install-applications.md)
- [Run CUDA containers on Ptinopedila NVIDIA](docs/cuda-containers.md)
- [Choose a tmux session when connecting over SSH](docs/ssh-tmux-sessions.md)
- [Install dotfiles](docs/install-dotfiles.md)
- [Install Conda](docs/install-conda.md)
- [Install Dynare for Octave](docs/install-dynare.md)
- [Install R and Quarto for VS Code](docs/install-r-vscode.md)
- [Install RStudio and Positron in an R workbench](docs/install-r-workbench.md)
- [Install Julia](docs/install-julia.md)
- [Install LanguageTool](docs/install-languagetool.md)
- [Look up words from Raffi](docs/use-word-lookup.md)
- [Configure LaTeX projects](docs/configure-latex.md)
- [Use a Ptinopedila PC as a Tailscale exit node](docs/use-tailscale-exit-node.md)
- [Manage login lockouts](docs/manage-faillock.md)
- [Use and customize Zsh](docs/zsh.md)

## Installation

> [!IMPORTANT]
> Switching to Ptinopedila changes the system-wide Flatpak configuration.
> Bluefin removes the Fedora Flatpak remote and configures Flathub.
> Ptinopedila installs its default applications through `flatpak preinstall`.

<details>
<summary>How Ptinopedila manages Flatpaks</summary>

Bluefin's `flatpak-preinstall.service` runs on each boot. It reads
Ptinopedila's [main defaults](files/shared/usr/share/flatpak/preinstall.d/ptinopedila.preinstall)
and [home variant defaults](files/home/usr/share/flatpak/preinstall.d/ptinopedila-home.preinstall),
then installs missing applications from Flathub. For an application installed by
this service, Flatpak remembers if you uninstall it and does not reinstall it.

When Ptinopedila removes an application from its default list, Flatpak may
also remove an application that it preinstalled. Applications previously
installed by BlueBuild are not automatically adopted into Flatpak's
preinstalled set. For those applications, uninstalling alone may not opt out;
add a local `Install=false` override first. See the
[application guide](docs/install-applications.md#customize-preinstalled-flatpaks).
Inspect any existing system Flatpaks before switching because Bluefin removes
the Fedora remote that may provide some of them:

```sh
flatpak list --system --app --columns=application,origin
```

To check the service after switching, run:

```sh
systemctl status flatpak-preinstall.service
```

See the [Flatpak preinstall documentation](https://docs.flatpak.org/en/latest/flatpak-command-reference.html#flatpak-preinstall)
for the application-list and opt-out behavior.

</details>

The following example switches an existing Fedora Atomic Desktop or Bluefin
installation to the standard Ptinopedila image. For an NVIDIA system, replace
`ptinopedila-home` with `ptinopedila-home-nvidia` in both commands.

The first switch cannot yet enforce Ptinopedila's signing policy because the
public key and policy are delivered by the image itself:

```sh
sudo bootc switch ghcr.io/ptinopedila/ptinopedila-home:latest
sudo systemctl reboot
```

After booting Ptinopedila, stage the same image again with signature
verification enforced, then reboot:

```sh
sudo bootc switch \
    ghcr.io/ptinopedila/ptinopedila-home:latest \
    --enforce-container-sigpolicy
sudo systemctl reboot
```

Both published images are signed with the key in `cosign.pub`.

<details>
<summary>rpm-ostree compatibility commands</summary>

BlueBuild also documents the older `rpm-ostree` syntax for systems where
`bootc switch` is not available:

```sh
sudo rpm-ostree rebase \
    ostree-unverified-registry:ghcr.io/ptinopedila/ptinopedila-home:latest
sudo systemctl reboot
```

After booting the image:

```sh
sudo rpm-ostree rebase \
    ostree-image-signed:docker://ghcr.io/ptinopedila/ptinopedila-home:latest
sudo systemctl reboot
```

</details>

### Image tags

- `latest` points to the newest successful Ptinopedila build.
- A Fedora-major tag such as `44` follows Ptinopedila builds for that Fedora
  release without crossing into the next major release.
- Date tags such as `20260811` and `20260811-44` select a particular build.
- An image digest provides the strongest immutable pin.

The recipes consume Bluefin's moving `stable` stream. Consequently,
Ptinopedila's `latest` tag can move to a new Fedora major release when Bluefin
promotes it to `stable`; `latest` is not a Fedora-major pin. Available tags can
be inspected with:

```sh
skopeo list-tags docker://ghcr.io/ptinopedila/ptinopedila-home
```
