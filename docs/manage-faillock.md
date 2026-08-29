# Manage login lockouts

Ptinopedila uses PAM faillock to slow repeated password guessing. The default
policy locks a local user for 10 minutes after 10 failed attempts within 15
minutes. It does not lock the root account.

Faillock is enabled in the image's authselect configuration during the build.
A fresh installation receives that configuration automatically. An existing
installation can retain an older `/etc/authselect` configuration, so check the
effective state after switching to Ptinopedila:

```sh
ujust set-faillock status
```

The command reports the current authselect profile and enabled features. It
also verifies that `pam_faillock.so` agrees with the reported feature state in
both effective PAM files.

## Enable faillock on an existing installation

Run:

```sh
ujust set-faillock on
```

The command creates a named authselect backup and enables only the
`with-faillock` feature. It does not replace the selected profile or remove
features such as fingerprint authentication. After the change, it runs
`authselect check` and verifies the generated PAM files. If either check fails,
it restores the backup automatically.

Keep the backup name printed by the command. To undo the complete authselect
change later, run:

```sh
sudo authselect backup-restore BACKUP_NAME
```

List available backups with `authselect backup-list`.

## Disable faillock

Run:

```sh
ujust set-faillock off
```

This operation also creates a backup, changes only the `with-faillock` feature,
and validates the result. It does not erase existing failure counters. Reset a
counter separately if necessary.

## Recover from a lockout

Sign in through another administrator account or a recovery console, then
reset the affected user's counter:

```sh
sudo faillock --user USERNAME --reset
```

The default tally directory is under `/run`, so rebooting normally clears the
counters as well. An authselect backup restores the PAM configuration, but it
does not reset a user's failure counter.

## Security and usability trade-off

The lockout limits repeated online guesses against PAM authentication. An
attacker who knows a username can also trigger the lockout deliberately. The
10-minute duration limits that denial of service. Ptinopedila does not lock
root because losing every administrative authentication path would make
recovery harder.

Faillock does not protect an exposed service by itself. Keep remote services
behind appropriate firewall rules and use their own connection rate limits.
