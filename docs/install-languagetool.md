> **Created:** `2026-08-24T05:13+03:00` · **Last updated:**
> `2026-08-24T18:01+03:00`

# Install LanguageTool

[LanguageTool](https://languagetool.org/) checks spelling, grammar,
punctuation, and style. It can run locally, so text does not need to be sent to
LanguageTool's online service.

## Install the enhanced English server

Ptinopedila's opt-in recipe installs LanguageTool with Homebrew and adds the
official English n-gram dataset. The dataset helps LanguageTool detect some
errors involving commonly confused words that its ordinary rules can miss.
Checks for other supported languages remain available, but the added dataset
only enhances English.

The download is approximately 8 GB and needs additional free space while it is
being extracted. An SSD is recommended.

Run the recipe with:

```sh
ujust install-languagetool
```

The recipe:

- confirms that port `8081` is available before making changes;
- installs LanguageTool and its Java dependency with Homebrew;
- downloads and installs the English n-gram dataset;
- configures LanguageTool to use that dataset;
- registers a user service that starts when you log in; and
- checks that the server responds at `http://localhost:8081`.

The recipe does not download a second copy when the complete dataset is already
installed. If its service is currently running, stop it before running the
default recipe again so that port `8081` is available.

### If the port is already in use

The recipe exits before installing or downloading anything when its intended
port is occupied. It prints the program listening on the port when Linux makes
that information available.

To install and configure LanguageTool without registering or starting any
service, run:

```sh
ujust install-languagetool --no-service
```

After disabling the conflicting program, start the normal Homebrew service:

```sh
brew services start languagetool
```

Alternatively, choose another port:

```sh
ujust install-languagetool --port=8082
```

This creates and enables a dedicated systemd user service instead of using the
Homebrew service. Its default path is:

```text
~/.config/systemd/user/ptinopedila-languagetool.service
```

If `XDG_CONFIG_HOME` is set, the service is placed under its `systemd/user`
directory instead. The recipe prints the exact path when it finishes.

## Simple alternative: Eloquent

[Eloquent](https://flathub.org/apps/re.sonny.Eloquent) is the easiest way to
use a local LanguageTool server on Ptinopedila. It provides a graphical
proofreading app, starts the server automatically when you log in, and appears
in GNOME's **Quick Settings → Background Apps** menu.

Install it from GNOME Software or from a terminal:

```sh
flatpak install flathub re.sonny.Eloquent
```

Eloquent makes the server available at `http://localhost:8081`. It is a simple
alternative that does not use LanguageTool's English n-gram dataset, making it
well suited to computers with limited drive space because it avoids the
approximately 8 GB download. Eloquent conflicts with the enhanced server
because both use port `8081`, so keep only one of them active.

## Connect applications

Applications connect to the same local server whether Eloquent, the Homebrew
service, or a custom-port service is running. With the default port, use either:

```text
http://localhost:8081
http://localhost:8081/v2
```

Replace `8081` with the port passed to `--port` when using the dedicated
systemd service.

For example, the Obsidian
[LanguageTool Integration](https://github.com/Clemens-E/obsidian-languagetool-plugin)
plugin accepts the first address as a custom URL. In LibreOffice, enable
LanguageTool under **Tools → Options → Languages and Locales → LanguageTool
Server** and use the second address.

For more clients, see LanguageTool's
[list of software that supports LanguageTool](https://dev.languagetool.org/software-that-supports-languagetool-as-a-plug-in-or-add-on).

You can test the server directly with:

```sh
curl \
    --data-urlencode "language=en-US" \
    --data-urlencode "text=a simple test" \
    http://localhost:8081/v2/check
```

## Manage the Homebrew service

Manage this user service without `sudo`:

```sh
# Show its status.
brew services list

# Restart it after a configuration change.
brew services restart languagetool

# Stop it and disable login autostart.
brew services stop languagetool
```

The recipe prints the exact data and configuration paths when it finishes. To
inspect the server log later, run:

```sh
tail -f "$(brew --prefix)/var/log/languagetool/languagetool-server.log"
```

## Manage a custom-port service

For an installation created with `--port`, inspect its status and logs with:

```sh
systemctl --user status ptinopedila-languagetool.service
journalctl --user -u ptinopedila-languagetool.service
```

Stop it and disable login autostart with:

```sh
systemctl --user disable --now ptinopedila-languagetool.service
```

To return to Eloquent, first stop the Homebrew service, then re-enable
Eloquent's autostart entry and open the app. If you installed a custom-port
service, disable it with the command above instead. Keep only the server you
intend to use active.
