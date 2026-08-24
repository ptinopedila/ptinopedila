> **Created:** `2026-08-24T02:24+03:00` · **Last updated:**
> `2026-08-24T02:24+03:00`

# Getting started with Distrobox

## Create a Distrobox

To create a Distrobox, choose a name for it and the Linux image you want it to
use. For example, this creates a Fedora container named `my-fedora`:

```bash
distrobox create \
    --name my-fedora \
    --image registry.fedoraproject.org/fedora-toolbox:latest
```

If you would prefer Ubuntu, Debian, Arch Linux, or another distribution, see
Distrobox's official [list of tested container images](https://distrobox.it/compatibility/#containers-distros).
The list gives you the exact image address to use after `--image`. Images marked
as "Toolbox" are generally a convenient choice for desktop use and take less
time to prepare when you first enter them.

Distrobox may need to download the image the first time you use it. When the
container is ready, enter it with:

```bash
distrobox enter my-fedora
```

You can see all your containers and their names at any time with:

```bash
distrobox list
```

### Give the container a separate home directory

By default, a Distrobox uses your normal home directory. You can instead give
it a separate home directory when you create it:

```bash
distrobox create \
    --name my-fedora \
    --image registry.fedoraproject.org/fedora-toolbox:latest \
    --home "$HOME/DistroboxHomes/my-fedora"
```

This can help keep the container's configuration files separate from your
usual configuration files. It does not turn the container into a security
sandbox or completely hide your host files from it.

## Install a desktop app and add it to the application menu

Distrobox can run graphical desktop apps as well as terminal programs. You can
even add an app installed inside a container to the host's normal application
menu. The app will look and launch much like any other desktop app, but its
program files and supporting packages remain inside the container.

The following example installs the lightweight Geany editor in the `my-fedora`
container created earlier. First, enter the container:

```bash
distrobox enter my-fedora
```

Install Geany using Fedora's package manager:

```bash
sudo dnf install geany
```

After the installation finishes, export its application launcher:

```bash
distrobox-export --app geany
```

You can now type `exit` to leave the container. Look for an entry such as
**Geany (on my-fedora)** in the host's application menu. Opening that entry
automatically starts the container and launches Geany inside it. The new entry
may take a moment to appear in the menu.

If you use a container based on Ubuntu, Debian, Arch Linux, or another
distribution, its command for installing packages will be different. The
`distrobox-export` step is the same.

To remove the application-menu entry later, enter the same container and run:

```bash
distrobox-export --app geany --delete
```

This removes the launcher from the host menu but leaves Geany installed inside
the container. See the official
[application-export documentation](https://distrobox.it/usage/distrobox-export/)
for more examples and options.

## Add the `@` shortcut

You can add the following function to your `~/.bashrc` or `~/.zshrc` file. It
creates a short `@` command for listing your Distrobox containers, entering a
container, or running a command inside one.

```bash
# List Distroboxes, enter one, or run a command in one.
function @() {
    if (( $# == 0 )); then
        distrobox list
        return
    fi

    local container
    container=$1
    shift

    if (( $# == 0 )); then
        distrobox enter --name "$container"
    else
        distrobox enter --name "$container" -- "$@"
    fi
}
```

After saving the file, open a new terminal. You can then use the shortcut like
this:

```bash
# List your Distrobox containers.
@

# Enter the container created earlier.
@ my-fedora

# List files inside the container without first entering it.
@ my-fedora ls -la

# Run a command containing spaces.
@ my-fedora printf '%s\n' "Hello from Fedora"
```

The first word after `@` is always the container name. Anything after the
container name is treated as a command to run inside that container. If you do
not provide a command, Distrobox opens the container's normal interactive
shell.

## Remove or purge a Distrobox

First, leave the container by typing `exit`. Then remove it by giving Distrobox
its name:

```bash
distrobox rm my-fedora
```

Distrobox asks for confirmation before deleting it. If the container is still
running, it also asks whether it should stop and remove it.

Removing a container deletes the programs and configuration stored inside that
container. It does not delete files from your normal, shared home directory.

If you created the container with a separate home directory using `--home`, you
can ask Distrobox to remove that directory as well:

```bash
distrobox rm --rm-home my-fedora
```

Distrobox shows the custom home directory and asks for confirmation before
removing it. This permanently deletes the files in that directory, so check the
displayed path carefully before answering yes.

Distrobox calls this operation `rm`; it does not have a separate `purge`
command. The downloaded base image may remain on the system so that it can be
reused by another container.

## A note about safety

Distrobox containers are closely connected to the host system. In particular,
they normally have access to your home directory, so a command running inside a
container can also change or delete your personal files. Treat commands and
software inside a Distrobox with the same care you would use on the host.

For more information, see the official Distrobox documentation:

- [Distrobox quick start](https://distrobox.it/)
- [Creating a Distrobox](https://distrobox.it/usage/distrobox-create/)
- [Using `distrobox enter`](https://distrobox.it/usage/distrobox-enter/)
- [Exporting applications](https://distrobox.it/usage/distrobox-export/)
- [Removing a Distrobox](https://distrobox.it/usage/distrobox-rm/)
- [Distrobox security implications](https://distrobox.it/#security-implications)
