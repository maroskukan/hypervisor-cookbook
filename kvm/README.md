# KVM

## Installation

### Prerequisites

```bash
grep -Eoc '(vmx|svm)' /proc/cpuinfo
```

#### APT

```bash
sudo apt install cpu-checker
kvm-ok
```

The output should be following:

```bash
INFO: /dev/kvm exists
KVM acceleration can be used
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
sudo apt install qemu-kvm qemu-efi libvirt-daemon-system libvirt-clients bridge-utils virtinst
sudo apt install virt-manager

# For vagrant-libvirt plugin
sudo apt install qemu libvirt-dev ruby-libvirt libxslt-dev libxml2-dev zlib1g-dev ruby-dev  ebtables dnsmasq-base
```

```bash
apt-cache show libvirt-daemon libvirt-daemon-system | sed -ne '/^Package/p;/^Description-en: /,/^[^ ]/{/^[^ ]/{/^Description-en: /!d};p}'
```

### Services

```bash
sudo systemctl is-active libvirtd
sudo systemctl enable --now libvirtd
```

### Permissions

After installing `libvirt-daemon-system`, the user used to manage virtual machines will need to be added to the `libvirt` group. This is done automatically for members of the sudo group, but needs to be done in additon for anyone else that should access system wide libvirt resources. Doing so will grant the user access to the advanced networking options.

```bash
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
```

### Networking

```bash
brctl show
```

## Domain Operation

### Creation

Install from ISO with VM that supports BIOS:

Example with Arch Linux:

```bash
virt-install \
    --name=arch_bios \
    --description "Arch x64 bios VM" \
    --os-type=Linux \
    --os-variant=archlinux \
    --ram=2048 \
    --vcpus=2 \
    --disk path=/var/lib/libvirt/images/arch_bios.qcow2,bus=virtio,size=20 \
    --graphics vnc,port=5999 \
    --console pty,target_type=serial \
    --cdrom /home/$USER/iso/archlinux-2022.09.03-x86_64.iso \
    --network bridge:virbr0
```

Example with Ubuntu:

```bash
virt-install \
    --name ubuntu_bios \
    --os-variant ubuntu20.04 \
    --vcpus 2 \
    --ram 2048 \
    --location http://ftp.ubuntu.com/ubuntu/dists/focal/main/installer-amd64/ \
    --network bridge=virbr0 \
    --graphics none \
    --extra-args='console=ttyS0,115200n8 serial'
```


Install from ISO with VM that supports EFI:

```bash
virt-install \
    --name arch_efi \
    --description "Arch x64 efi VM" \
    --os-type=Linux \
    --os-variant=archlinux \
    --boot loader=/usr/share/OVMF/OVMF_CODE.fd \
    --ram=2048 \
    --vcpus=2 \
    --disk path=/var/lib/libvirt/images/arch_efi.qcow2,bus=virtio,size=20 \
    --graphics vnc,port=5998 \
    --console pty,target_type=serial \
    --cdrom /home/$USER/Downloads/iso/archlinux-2022.09.03-x86_64.iso \
    --network bridge:virbr0
```

> **Info**: The list of supported OS variants can be retrieved by using `osinfo-query os` command, which is available through `libosinfo-bin` package.


### Interaction


Retrieve the VNC port. :0 corresponds to 5900

```bash
virsh vncdisplay arch_efi
```

Rerieve domain MAC and IP address.

```bash
DOMAIN_NAME=archlinux

DOMAIN_MAC=$(virsh dumpxml --domain "$DOMAIN_NAME" | grep 'mac address' | cut -f2 -d"'")

DOMAIN_IP=$(virsh net-dhcp-leases default | grep "$DOMAIN_IP" | awk '{ print $5}' | cut -f1 -d"/")

echo $DOMAIN_IP
```


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
