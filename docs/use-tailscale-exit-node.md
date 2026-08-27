> **Created:** `2026-08-27T23:30+03:00` · **Last updated:**
> `2026-08-28T00:02+03:00`

# Use a Ptinopedila PC as a Tailscale exit node

> [!WARNING]
> Read Tailscale's official [Exit nodes](https://tailscale.com/docs/features/exit-nodes)
> documentation before running this recipe. The recipe enables kernel IP
> forwarding and can change the PC's firewall settings.

A Tailscale exit node routes another tailnet device's internet traffic through
your Ptinopedila PC. The PC must stay powered on and connected to Tailscale
while another device uses it.

## Configure the PC

Before you start, install Tailscale and connect the PC to your tailnet. The
recipe stops without changing the system if Tailscale is missing or is not
connected. Then run:

```sh
ujust toggle-exitnode
```

Choose `enable`. The recipe:

1. Enables IPv4 and IPv6 forwarding in
   `/etc/sysctl.d/60-ptinopedila-tailscale-exit-node.conf`.
2. Enables masquerading when `firewalld` is running.
3. Advertises the PC as an exit node and connects Tailscale.
4. Prints the remaining approval step.

You can skip the prompt with:

```sh
ujust toggle-exitnode enable
```

## Approve the exit node

Open the [Machines page](https://login.tailscale.com/admin/machines) in the
Tailscale admin console. Select this PC, open **Edit route settings**, enable
**Use as exit node**, and select **Save**.

Tailscale can approve the exit node automatically when the device's user is an
exit-node `autoApprover`. Otherwise, you need tailnet administrator access for
this step.

If your tailnet uses the default access policy, its members can use approved
exit nodes. If you replaced that policy, grant the intended users access to
`autogroup:internet`.

## Use the exit node

On another tailnet device, open Tailscale and select the Ptinopedila PC under
**Exit Node**. Leave **Allow Local Network Access** disabled unless you also
need access to the client device's local network.

On GNOME, the community-built
[Tailscale extension](https://extensions.gnome.org/extension/10017/tailscale/)
with UUID `tailscale-gnome@diskmth.fr` adds Tailscale controls to the Quick
Settings menu. You can connect to Tailscale, select an exit node, and manage
supported settings without opening a terminal. The extension uses the
installed Tailscale client and is not affiliated with Tailscale Inc.

To stop advertising the PC as an exit node, run:

```sh
ujust toggle-exitnode disable
```

The disable action withdraws the Tailscale advertisement and asks whether to
keep the persistent routing settings. Keep them if another routing setup uses
IP forwarding or firewalld masquerading. If you remove them, the recipe
deletes its sysctl file, reapplies the remaining sysctl configuration, and
removes firewalld masquerading if the recipe originally enabled it. If
firewalld is not running, the recipe preserves its ownership marker and tells
you to start firewalld before you retry the cleanup.

## References

Tailscale documents the forwarding, firewalld, approval, access-policy, and
client steps in [Exit nodes](https://tailscale.com/docs/features/exit-nodes).
See the [`tailscale set` reference](https://tailscale.com/docs/reference/tailscale-cli#set)
for the advertisement flags used by the recipe.
