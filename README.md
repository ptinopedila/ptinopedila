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

## Installation

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

### Install dotfiles

Ptinopedila includes an opt-in helper for installing a bare dotfiles repository
into the current user's home directory:

```sh
ujust install-dotfiles git@github.com:USER/REPOSITORY.git
```

The repository URL is provider-neutral, so SSH remotes from GitLab, Codeberg,
or self-hosted Git services work as well. GitHub users can alternatively use:

```sh
ujust install-dotfiles --github USER REPOSITORY
```

The command checks out the repository as `~/.cfg`. Existing paths that would be
replaced are first moved into a uniquely named `~/.config-backup.XXXXXXXX`
directory with their relative paths preserved. The command refuses to replace
an existing `~/.cfg`.

### Install Conda

Ptinopedila includes an opt-in installer for both Miniconda and the complete
Anaconda distribution. Miniconda provides Conda and its dependencies without
the large collection of packages included with Anaconda, so it is the default:

```sh
ujust install-conda
```

To install the complete Anaconda distribution instead, run:

```sh
ujust install-conda anaconda
```

Both commands install the latest upstream Linux release for the current
architecture at `~/.local/anaconda3`. The installer downloads only over HTTPS,
verifies the download against the SHA-256 checksum published in Anaconda's
official repository index, and refuses to overwrite an existing path.

The installation does not modify shell startup files or automatically activate
the base environment. Ptinopedila's Zsh configuration initializes Conda lazily
on the first `conda` command. Until then, Conda adds nothing to `PATH`. After
initialization, only `~/.local/anaconda3/condabin` is added until an environment
is explicitly activated.

<details>
<summary>How does lazy Conda initialization work?</summary>

When Zsh starts, Ptinopedila defines a small temporary shell function named
`conda`. Defining that function does not execute Conda, evaluate its shell hook,
or modify `PATH`.

The first command beginning with `conda`—including `conda activate`—does the
following:

1. Runs the installed Conda executable by its absolute path.
2. Requests Conda's official Zsh hook with automatic `base` activation
   disabled.
3. Evaluates that hook in the current shell, replacing the temporary function
   with Conda's normal shell function.
4. Forwards the original command and its arguments to the initialized function.

The official Miniconda or Anaconda installer creates `condabin`; Ptinopedila
does not create it. This directory contains the `conda` entry point, but it does
not expose Python or other programs from the `base` environment. The Conda hook
adds `~/.local/anaconda3/condabin` to `PATH` after initialization. Running
`conda activate ENVIRONMENT` additionally adds that environment's `bin`
directory, and `conda deactivate` removes it again.

Each new terminal starts in the unloaded state, so shells that never invoke
`conda` remain unaffected.

</details>

### Install Julia

Juliaup is preinstalled as Julia's official version manager. Install and select
Julia's current release channel:

```sh
juliaup add release
juliaup default release
julia --version
```

Homebrew updates Juliaup itself, while `juliaup` installs and updates Julia
versions. To update the selected Julia channels later, run:

```sh
juliaup update
```

For a Julia project, keep its environment in the project rather than installing
all packages into a shared environment. Commit both `Project.toml` and
`Manifest.toml`, then restore the recorded dependencies with:

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Juliaup's installations and Julia's package depot live in the user's home
directory, normally under `~/.juliaup` and `~/.julia`, so they persist across
image updates. See Julia's
[installation documentation](https://docs.julialang.org/en/v1/manual/installation/)
and [package-environment documentation](https://pkgdocs.julialang.org/v1/environments/)
for details.
