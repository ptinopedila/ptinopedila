> **Created:** `2026-08-26T05:15+03:00` · **Last updated:**
> `2026-08-26T05:26+03:00`

# Use and customize Zsh

Ptinopedila includes a configured system Zsh at `/usr/bin/zsh`.

## Start Zsh without changing the login shell

Do not use `chsh` to make Zsh the system-wide login shell. Following
[Bluefin's shell guidance](https://docs.projectbluefin.io/command-line/),
configure the terminal emulator to start the preferred interactive shell while
leaving the login shell unchanged.

In Ptinopedila's default Terminal application, open the profile preferences,
enable its custom-command option, and use:

```text
/usr/bin/zsh
```

The same command can be configured in another terminal emulator. Use the
system Zsh path above—not a separately installed Homebrew Zsh—so Ptinopedila's
global Zsh configuration is loaded.

## User configuration files

Ptinopedila's `/etc/zshenv` sets:

```sh
ZDOTDIR="$HOME/.config/zsh"
```

Consequently, Zsh reads user configuration from `~/.config/zsh/` rather than
placing its files directly in the home directory. Ptinopedila creates this
directory when its interactive configuration loads, but does not create a user
`.zshrc` or other user startup file.

For an interactive shell, Zsh loads Ptinopedila's `/etc/zshrc` first and then
loads `~/.config/zsh/.zshrc` when that user file exists. Personal settings can
therefore be placed in `.zshrc` without explicitly sourcing `/etc/zshrc`.
Ptinopedila's global file configures the Homebrew environment, completion,
history behavior, the Starship prompt, lazy Conda initialization, and the SSH
tmux prompt.

The standard user startup files all live under `~/.config/zsh/`:

- `.zshenv` is read for every Zsh invocation.
- `.zprofile` is read for login-shell setup before `.zshrc`.
- `.zshrc` is read for interactive shells.
- `.zlogin` is read for login-shell setup after `.zshrc`.

See the official [Zsh startup-file documentation](https://zsh.sourceforge.io/Doc/Release/Files.html)
for the complete startup order.

### Opt out of Ptinopedila's global Zsh configuration

The global configuration is optional. To keep using Zsh while skipping
Ptinopedila's global startup files, create `~/.config/zsh/.zshenv` containing:

```sh
unsetopt GLOBAL_RCS
```

Zsh always reads `/etc/zshenv` first, which sets `ZDOTDIR`, and then reads the
user's `.zshenv`. Unsetting `GLOBAL_RCS` there prevents subsequent global files
such as `/etc/zprofile`, `/etc/zshrc`, and `/etc/zlogin` from loading. User
startup files under `~/.config/zsh/` continue to load normally.

## Optional interactive plugins

Ptinopedila's managed Homebrew packages include `zsh-autosuggestions` and
`zsh-fast-syntax-highlighting`. The global configuration does not currently
activate these plugins automatically. To enable them, add the following to
`~/.config/zsh/.zshrc`:

```sh
brew_prefix=${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}

autosuggestions="$brew_prefix/opt/zsh-autosuggestions/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
highlighting="$brew_prefix/opt/zsh-fast-syntax-highlighting/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"

[[ -r $autosuggestions ]] && source "$autosuggestions"
[[ -r $highlighting ]] && source "$highlighting"

unset autosuggestions brew_prefix highlighting
```

Conda setup is documented separately in [Install Conda](install-conda.md).
