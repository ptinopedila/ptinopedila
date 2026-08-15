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
