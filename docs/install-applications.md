> **Created:** `2026-08-26T05:43+03:00` · **Last updated:**
> `2026-08-26T05:43+03:00`

# Install and manage applications

Ptinopedila separates applications from the operating-system image. Choose the
installation method according to what the software does:

| Software | Preferred method |
| --- | --- |
| Graphical desktop applications | Flatpak from Flathub through Bazaar |
| Command-line applications | Homebrew |
| Project-specific tools and libraries | A project environment, such as Conda or Distrobox |
| Host system components | Add them to the Ptinopedila image |

Do not use DNF or `rpm-ostree` package layering to install software on the
host. Layered packages alter the image deployment and can interfere with image
updates. If a missing host component cannot run through Flatpak, Homebrew, or a
project environment, propose adding it to the Ptinopedila image.

## Install graphical applications with Bazaar

Bazaar is Ptinopedila's graphical application store. It installs Flatpak
applications from Flathub without modifying the operating-system image.

Ptinopedila's configured Flatpaks are installed system-wide. To inspect them
from the terminal, run:

```sh
flatpak list --system --app
```

To search Flathub and install another application system-wide from the
terminal, use its application ID:

```sh
flatpak search APPLICATION_NAME
flatpak install --system flathub APPLICATION_ID
```

The installation may request administrator authentication. Bazaar is usually
more convenient when the application ID is not already known.

When switching from Fedora or another image, first read the
[Flatpak migration warning](../README.md#installation). Ptinopedila configures
Flathub and removes the Fedora Flatpak remote by default.

## Install command-line applications with Homebrew

Use Homebrew for command-line utilities that do not need to become part of the
host image. For example:

```sh
brew search ripgrep
brew install ripgrep
```

Inspect or remove installed formulae with:

```sh
brew list --formula
brew uninstall ripgrep
```

Homebrew casks are not the normal way to install graphical Linux applications
on Ptinopedila; use Flatpak instead.

## Updates

When the computer is connected to AC power and its hardware and network checks
pass, Ptinopedila automatically checks for and installs system-image, Flatpak,
and Homebrew updates, and attempts to upgrade existing Distroboxes. Flatpak and
Homebrew updates do not require an operating-system reboot, although running
applications may need to be restarted. A staged system-image update takes
effect after rebooting.

To request an update check manually, run:

```sh
ujust update
```

## Adjust Flatpak permissions

Flatpak applications are sandboxed. They normally access files, devices, and
desktop services through portals, so most applications do not need manual
permission changes.

When an application cannot access something it genuinely needs, use Flatseal
to inspect its permissions and apply the narrowest necessary override. Broad
filesystem or device access weakens the sandbox and can hide an application or
portal bug. Remove an override again if it does not solve the problem.

See the official [Flatpak concepts](https://docs.flatpak.org/en/latest/basic-concepts.html)
for an explanation of applications, runtimes, repositories, sandboxes, and
portals.

## Temporarily downgrade a broken Flatpak

Warehouse provides a graphical interface for managing installed Flatpaks and
available older versions. Flatpak also supports an explicit terminal workflow.

First, close the application and list the commits available from Flathub:

```sh
flatpak remote-info --system --log flathub APPLICATION_ID
```

Copy the commit identifier for the version to restore, then deploy it:

```sh
sudo flatpak update --system --commit=COMMIT APPLICATION_ID
```

Automatic updates would otherwise reinstall the latest release. Temporarily
mask the application after downgrading it:

```sh
sudo flatpak mask --system APPLICATION_ID
```

List active masks with `flatpak mask --system`. After the upstream problem is
fixed, remove the mask and update normally:

```sh
sudo flatpak mask --system --remove APPLICATION_ID
sudo flatpak update --system APPLICATION_ID
```

Do not leave applications masked indefinitely, because a mask also prevents
security and bug-fix updates. See Flatpak's official
[downgrade and masking instructions](https://docs.flatpak.org/en/latest/tips-and-tricks.html#downgrading)
for additional detail.
