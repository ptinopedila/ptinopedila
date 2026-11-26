# Install Virtual Machine Manager and QEMU for the user's libvirt session.
[group('System')]
setup-vms:
    /usr/libexec/ptinopedila/manage-vm-flatpaks setup

# Install or remove the system VM apps after confirmation, keeping guest data.
[group('System')]
toggle-vms:
    /usr/libexec/ptinopedila/manage-vm-flatpaks toggle
