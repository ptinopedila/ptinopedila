# Ptinopedila-os

[![build-ublue](https://github.com/ptinopedila/ptinopedila-os/actions/workflows/build.yml/badge.svg)](https://github.com/ptinopedila/ptinopedila-os/actions/workflows/build.yml)

> Warning! The images in this repository are not ready to be used in production. The image names and scope may change daily as long as this message is here.

The goal is to create a set of images for economists and econ-labs.

Our goal is to deliver a versatile and streamlined environment, minimizing barriers to academic work for economists and data scientists.

Current issue is the size of the images and the limited resources github provides for free.

## Images

### Home

Smaller images intended to be used with toolboxes for a light and flexible workstation at home.

Currently built on top of [Bluefin](https://github.com/projectbluefin/bluefin)'s stable image.

- ptinopedila-home
- ptinopedila-home-nvidia

## Documentation

This project is based on [Universal Blue](universal-blue.org) and [Bluefin](https://projectbluefin.io/). We will try to stay close to upstream, which is constantly improving and evolving. The changes we make will be documented in detail.

For econ-specific tools and programs please open an issue in this repository. Documentation on how to install proprietary software and work with containers will soon™ be available.

For more info, check out the [uBlue homepage](https://universal-blue.org/) and the [main uBlue repo](https://github.com/ublue-os/main/)

## Installation

> **Warning**
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable) and should not be used in production, try it in a VM for a while!

To rebase an existing Silverblue/Kinoite installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:

  ```sh
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/ptinopedila/ptinopedila-home:latest
  ```

- Reboot to complete the rebase:

  ```sh
  systemctl reboot
  ```

- Then rebase to the signed image, like so:

  ```sh
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ptinopedila/ptinopedila-home:latest
  ```

- Reboot again to complete the installation

  ```sh
  systemctl reboot
  ```

This repository builds date tags as well, so if you want to rebase to a particular day's build:

```sh
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ptinopedila/ptinopedila-home:20230403
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

This repository by default also supports signing.

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.
