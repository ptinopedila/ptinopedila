# Use Homebrew fonts across accounts

The first account on the workstation owns the shared Homebrew installation.
Its automatic research-font bundle installs Carlito in
`/usr/local/share/fonts/homebrew`.
Once installed, Carlito is available to every desktop account, including accounts created later.
When a document requests Calibri and that font is unavailable, Fontconfig selects Carlito.

Ptinopedila uses the same shared directory for new Homebrew font casks.
The Homebrew discussion explains how the font directory setting works
and why existing casks need a one-time reinstall.
[How can one Homebrew owner install Carlito for all users on Linux?](https://github.com/orgs/Homebrew/discussions/7211)

## Move a previously installed font

If the Homebrew owner previously installed Carlito in their personal font directory,
Ptinopedila moves it on the next managed font installation.
For another font, run the following command as the Homebrew owner.
Replace `font-inter` with the cask you want to move.

```sh
brew reinstall --cask --fontdir=/usr/local/share/fonts/homebrew font-inter
```

Reopen applications that were running during the install to refresh their font lists.
