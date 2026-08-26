> **Created:** `2026-08-15T03:27+03:00` · **Last updated:**
> `2026-08-26T07:35+03:00`

# Install dotfiles

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

## Per-machine configuration after cloning

Some applications need a small amount of configuration that differs between
computers. A laptop and desktop might share nearly all settings while needing
different device, display, performance, or path values.

Prefer keeping the tracked main configuration identical and sourcing a small
machine-local file. One possible layout is:

```text
~/.config/example-app/config
~/.config/example-app/machines/laptop.conf
~/.config/example-app/machines/desktop.conf
~/.config/example-app/machines/current.conf -> laptop.conf
```

If the application supports configuration fragments, the tracked main config
can include the stable local path using the application's own syntax. For
example:

```text
include ~/.config/example-app/machines/current.conf
```

After installing the dotfiles, select the correct tracked machine fragment by
creating an untracked symlink:

```sh
ln -s laptop.conf ~/.config/example-app/machines/current.conf
```

Use `desktop.conf` on the desktop. Do not track `current.conf`; each computer
owns that selection. The installer configures the bare repository not to show
untracked files, so this local symlink does not clutter normal dotfiles status
output.

### Fallback for an indivisible tracked config

If an application cannot load machine-local configuration fragments, its
tracked config may need a local edit after cloning. Git can suppress normal
change detection for that path with:

```sh
git --git-dir="$HOME/.cfg" --work-tree="$HOME" \
    update-index --assume-unchanged -- .config/example-app/config
```

`git update-index` changes Git's index metadata. The `--assume-unchanged` flag
tells Git to avoid its normal working-tree checks for that tracked path, so a
local edit usually disappears from `git status`. It does not add the path to an
ignore file, create a machine-specific branch, or guarantee that later Git
operations can safely overwrite or merge the file.

Inspect the flag with:

```sh
git --git-dir="$HOME/.cfg" --work-tree="$HOME" \
    ls-files -v -- .config/example-app/config
```

A lowercase `h` prefix indicates `assume-unchanged`. Clear it before reviewing
local changes or reconciling an upstream edit:

```sh
git --git-dir="$HOME/.cfg" --work-tree="$HOME" \
    update-index --no-assume-unchanged -- .config/example-app/config

git --git-dir="$HOME/.cfg" --work-tree="$HOME" \
    status --short -- .config/example-app/config
```

This flag is useful as a temporary compatibility measure for an existing
dotfiles layout. A shared config plus an untracked machine-local include is
clearer and less likely to cause surprises during updates.
