# KVM

## Installation

### Prerequisites

```bash
grep -Eoc '(vmx|svm)' /proc/cpuinfo

sudo apt install cpu-checker
kvm-ok
```
### Packages

#### Yum

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

#### Apt

```bash
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
sudo apt install virt-manager virtinst
```

### Services

```bash
sudo systemctl is-active libvirtd
sudo systemctl start libvirtd
sudo systemctl enable libvirtd
sudo reboot
```

### Permissions

```bash
sudo usedmod -aG libvirt $USER
sudo usermod -aG kvm $USER
```

### Networking

```bash
brctl show
```

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