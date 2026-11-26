# Virtualization

Ptinopedila offers desktop virtual machines as an optional feature.
Virtual Machine Manager provides the graphical interface.
Its QEMU extension runs guests under your account using the host’s KVM driver.
Each account has its own connections and guest definitions.

The first Classic and Utah trial release (November 26, 2026) preinstalled
both Flatpaks. On that release you can open Virtual Machine Manager directly
and follow the manual connection steps below. Some older images lack the
shared VM recipes. Run `ujust --list` to see which commands your image provides.

## Install Virtual Machine Manager

Run this command as your desktop user:

```sh
ujust setup-vms
```

The recipe installs Virtual Machine Manager and its QEMU extension from Flathub
for all accounts on the computer. Approve the system installation if prompted.
Open **Virtual Machine Manager** from the application menu.
Select your **QEMU/KVM user session** connection to create a VM or open one
that belongs to your account.

## Set or change your connection

On images with the automatic connection setup, a fresh profile connects to
the **QEMU/KVM user session** when the manager opens.
If you have already saved connections or changed your autoconnect preference,
the manager keeps your choices.

To add the local connection manually, including on earlier images:

1. In **Virtual Machine Manager**, choose **File → Add Connection**.
2. Under **Hypervisor**, choose **QEMU/KVM user session**.
3. Select **Autoconnect** and click **Connect**.

If the connection is already listed, open its **Connection Details** and
change **Autoconnect** there. You can keep other local or remote connections.
The user session (`qemu:///session`) and the system connection
(`qemu:///system`) have separate guest lists.
If an existing VM seems to be missing, open the connection where you created it.

## Remove or reinstall the VM tools

Shut down your running guests and close Virtual Machine Manager, then run:

```sh
ujust toggle-vms
```

Confirm the removal of the system-wide Flatpaks. Guest disk images and
Virtual Machine Manager’s saved data stay on disk.
To use the tools again, run `ujust setup-vms`.
