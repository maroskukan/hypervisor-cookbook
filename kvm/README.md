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

#### Dnf

```bash
dnf install -y qemu-kvm libvirt virt-manager libvirt-client

# The group contains packages such as:
# gnome-boxes, virt-install, virt-manager, virt-viewer
# qemu-img, libvirt, libvirt-python, libvirt-client
dnf group install -y "Virtualization Client"

dnf group list hidden
```

If you use Cockpit Web UI, you can install `cockpit-machines` to manage Virtual Machines through same interface.

```bash
dnf install -y cockpit-machines
```

#### Apt

```bash
# Mandatory packages
apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst 

# Optional packages for EUFI-based firmware
apt install -y qemu-efi ovmf

# Optional packages for GUI-based management
apt install virt-manager

# Optional packages for vagrant-libvirt plugin
apt install qemu libvirt-dev ruby-libvirt libxslt-dev libxml2-dev zlib1g-dev ruby-dev  ebtables dnsmasq-base
```

In order to quickly display a package description, you can use the following command:

```bash
apt-cache show libvirt-daemon libvirt-daemon-system | sed -ne '/^Package/p;/^Description-en: /,/^[^ ]/{/^[^ ]/{/^Description-en: /!d};p}'
```

### Services

```bash
# Enable and start libvirtd if not running
systemctl is-active libvirtd || systemctl enable --now libvirtd
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
    --os-variant=archlinux \
    --vcpus=2 \
    --ram=2048 \
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
    --description "Ubuntu x64 bios VM" \
    --os-variant ubuntu20.04 \
    --vcpus 2 \
    --ram 2048 \
    --location http://ftp.ubuntu.com/ubuntu/dists/focal/main/installer-amd64/ \
    --network bridge=virbr0 \
    --graphics none \
    --extra-args='console=ttyS0,115200n8 serial'
```

The following code snipped can be used to perform manual installation of Arch Linux running on OVMF EUFI firmware.

```bash
# Arch Linux Rolling Release
vm_name=arch
loader="/usr/share/OVMF/OVMF_CODE.fd"

# Domain Creation
virt-install \
    --name=${vm_name} \
    --description "Arch x64 efi VM" \
    --os-variant=archlinux \
    --boot loader=${loader} \
    --ram=2048 \
    --vcpus=2 \
    --disk path=/var/lib/libvirt/images/${vm_name}_efi.qcow2,bus=virtio,size=20 \
    --graphics vnc,port=5998 \
    --console pty,target_type=serial \
    --cdrom /var/lib/libvirt/images/iso/iso/archlinux-2022.09.03-x86_64.iso \
    --network bridge:virbr0
```

The following code snipped can be used to perform manual installation of Ubuntu 23.04 Linux running on OVMF EUFI firmware.

```bash
# Ubuntu 23.04
vm_name="ubuntu2304"
loader="/usr/share/OVMF/OVMF_CODE.fd"

# Domain Creation
virt-install \
    --name=${vm_name} \
    --description "Ubuntu 23.04 x64 efi VM" \
    --os-variant=ubuntu23.04 \
    --boot loader=${loader} \
    --ram=3072 \
    --vcpus=2 \
    --disk path=/var/lib/libvirt/images/${vm_name}_efi.qcow2,bus=virtio,size=20 \
    --graphics vnc,port=5998 \
    --console pty,target_type=serial \
    --cdrom /var/lib/libvirt/images/iso/ubuntu-23.04-live-server-amd64.iso \
    --network bridge:virbr0
```


> **Info**: The list of supported OS variants can be retrieved by using `osinfo-query os` command, which is available through `libosinfo-bin` package.


### Interaction

Run graphical console

```bash
virt-viewer --connect qemu:///system --wait ${vm_name}
```

Retrieve the VNC port. :0 corresponds to 5900

```bash
virsh vncdisplay ${vm_name}
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
vm_disk_path=$(virsh dumpxml --domain ${vm_name} | grep 'source file' | cut -f2 -d"'")

# Gracefully Shutdown the Domain
virsh shutdown ${vm_name}

# Forcefully Shutdown the Domain
virsh destroy ${vm_name}

# Delete the Domain
virsh undefine ${vm_name}

# Remove the VHD
rm -rf ${vm_disk_path}
```
