# KVM

## Installation

### Packages

```bash
sudo yum install -y qemu-kvm libvirt virt-manager libvirt-client

# The group contains packages such as:
# gnome-boxes, virt-install, virt-manager, virt-viewer
# qemu-img, libvirt, libvirt-python, libvirt-client
sudo yum group install -y "Virtualization Client"

sudo yum group list hidden
```

If you use Cockpit Web UI, you can install `cockpit-machines` to manage Virtual Machines through same interface.

```bash
sudo yum install -y cockpit-machines
```

### Services

```bash
sudo systemctl start libvirtd
sudo systemctl enable libvirtd
sudo reboot
```

### Permissions


## Domain Operation


### Creation

### Deletion

```bash
# List the available Domains
virsh list [--all]

# Save the VHD location
VHD=$(virsh dumpxml --domain <domain-name> | grep 'source file' | cut -f2 -d"'")

# Shutdown the Domain
virsh shutdown <domain-name>

# Delete the Domain
virsh undefine <domain-name>

# Remove the VHD
rm -rf $VHD
```