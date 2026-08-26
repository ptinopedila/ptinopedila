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
- [Install Julia](docs/install-julia.md)
- [Install LanguageTool](docs/install-languagetool.md)
- [Use and customize Zsh](docs/zsh.md)

## Installation

> [!IMPORTANT]
> Switching to Ptinopedila changes the system-wide Flatpak configuration.
> Ptinopedila uses BlueBuild's `default-flatpaks` module, which removes the
> Fedora Flatpak remote by default, configures Flathub, and installs
> Ptinopedila's configured applications automatically.

<details>
<summary>How Ptinopedila manages Flatpaks</summary>

The Flatpak setup runs on the first boot and checks the configuration again on
subsequent boots. Missing applications from Ptinopedila's
[system Flatpak list](recipes/common_modules/workstation.yml) are installed
system-wide.

The current `default-flatpaks` v2 module does not automatically uninstall
existing Flatpak applications. This differs from v1, which removed Flatpaks
installed from Fedora when replacing that remote. Nevertheless, inspect any
existing system Flatpaks before switching because the Fedora remote that
provided them will no longer be configured by default:

```sh
flatpak list --system --app --columns=application,origin
```

BlueBuild provides `bluebuild-flatpak-manager` for inspecting the image's
configuration, running the setup manually, and disabling or re-enabling the
automatic setup. Run the following command for its available operations:

```sh
bluebuild-flatpak-manager --help
```

See BlueBuild's
[`default-flatpaks` documentation](https://blue-build.org/reference/modules/default-flatpaks/)
for the current module behavior.

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
