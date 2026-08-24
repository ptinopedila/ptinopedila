> **Created:** `2026-08-15T03:27+03:00` · **Last updated:**
> `2026-08-24T02:48+03:00`

# Choose a tmux session when connecting over SSH

Ptinopedila helps preserve terminal work across unreliable or short-lived SSH
connections. When an interactive SSH login reaches Zsh and tmux is available,
Ptinopedila displays a menu instead of automatically attaching to a particular
tmux session.

The menu lists every existing tmux session, followed by options to create a new
session or continue without tmux. If no sessions exist, only those two actions
are shown.

Selecting an existing session attaches the SSH connection to it. Programs and
shells already running in that session appear as they were left. Attaching does
not disconnect another client that is already using the same session, so more
than one SSH connection can view it simultaneously.

Selecting the creation option asks for a session name. The new session remains
available after an SSH connection drops or its tmux client is deliberately
detached. A non-empty, memorable name makes it easier to identify the session
on a later login.

Selecting the option to continue without tmux opens the ordinary Zsh prompt.
This is useful for a short task or when inspecting and repairing tmux
configuration.

## Leaving and returning

To leave a tmux session without stopping its programs, press tmux's prefix,
`Ctrl-b`, release it, and then press `d`. The SSH connection ends because tmux
replaces the outer login shell, but the selected session continues running on
the remote computer. The session appears in the chooser the next time an SSH
connection is made.

An unexpected network or SSH disconnection has the same persistence benefit:
the tmux session continues even though its client disappears. This protects
against connection loss, not a reboot or power loss on the remote computer.

The chooser is not displayed inside an existing tmux session, which prevents
tmux from starting recursively. It is also skipped when tmux is unavailable or
when the `NO_AUTO_TMUX` escape hatch is set for the login.

## Learn more about tmux

This guide explains how Ptinopedila helps you choose and preserve tmux sessions
over SSH. To learn more about using tmux itself, including windows, panes, copy
mode, and keyboard shortcuts—see the
[tmux cheat sheet](https://tmuxcheatsheet.com/).
