> **Created:** `2026-08-26T05:43+03:00` · **Last updated:**
> `2026-10-30T04:37+02:00`

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

The [main application list](../files/shared/usr/share/flatpak/preinstall.d/ptinopedila.preinstall)
and [home variant defaults](../files/home/usr/share/flatpak/preinstall.d/ptinopedila-home.preinstall)
use Flatpak preinstall. You can change these defaults for your own computer
without editing the image-managed list; see [Customize preinstalled Flatpaks](#customize-preinstalled-flatpaks).

To search Flathub and install another application system-wide from the
terminal, use its application ID:

```sh
flatpak search APPLICATION_NAME
flatpak install --system flathub APPLICATION_ID
```

The installation may request administrator authentication. Bazaar is usually
more convenient when the application ID is not already known.

When switching from Fedora or another image, first read the
[Flatpak migration warning](../README.md#installation). Bluefin configures
Flathub and removes the Fedora Flatpak remote by default.

### Customize preinstalled Flatpaks

Create a local preinstall file in `/etc/flatpak/preinstall.d/`. It survives
image updates and takes priority over Ptinopedila's list in `/usr/share`.
Create the directory and open the file as an administrator:

```sh
sudo install -d -m 0755 /etc/flatpak/preinstall.d
sudoedit /etc/flatpak/preinstall.d/99-local.preinstall
```

To **exclude** an image default, add a group with its application ID:

```ini
[Flatpak Preinstall APPLICATION_ID]
Install=false
```

If it is already installed, remove it with
`flatpak uninstall --system APPLICATION_ID`. Add the override before removing
an app installed under the earlier BlueBuild setup: those installations are not
automatically recorded as Flatpak preinstall opt-outs. An app installed by
Flatpak preinstall normally stays opted out when you uninstall it, even without
an override.

To **add** an application to your local defaults, add another group to the same
file:

```ini
[Flatpak Preinstall ANOTHER_APPLICATION_ID]
Branch=stable
```

Replace the example IDs with real Flatpak application IDs. Check the app and
its branch with `flatpak remote-info --system --show-ref flathub APPLICATION_ID`;
use the branch at the end of the returned ref instead of `stable` if needed.
Add one group per app. The new default is applied on the next boot, provided
the Flathub remote is available. To apply all preinstall files immediately,
run `sudo flatpak preinstall -y`; this also reconciles any other defaults and
exclusions in those files. Uninstalling an app that Flatpak preinstall added
opts out of that default.

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

Ptinopedila builds daily at 04:00 Athens time, with daylight saving adjustment.
Each image build refreshes repository metadata and upgrades installed RPMs
from enabled repositories, subject to dependency constraints, repository
exclusions, and version locks.
The upgrade command excludes Bluefin's kernel, external modules, matched NVIDIA
driver packages, and any inherited ZFS packages and their companion libraries.
These exclusions retain the versions supplied by the base image.
They do not select newer compatible combinations.
Fixes for excluded packages arrive through newer Bluefin base images.
NVIDIA container tooling, GPU firmware, `kernel-tools`, `kernel-headers`, and
the `kmod` utility remain eligible for upgrades.
The exclusions apply only to the build's upgrade command.

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
