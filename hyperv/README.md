# Hyper-V

- [Hyper-V](#hyper-v)
  - [VM Operation](#vm-operation)
    - [Creation](#creation)
    - [Properties](#properties)
    - [State](#state)
    - [Removal](#removal)
  - [Linux Guest](#linux-guest)
    - [Virtual Hardware Settings](#virtual-hardware-settings)
    - [Virtualization Extensions](#virtualization-extensions)
    - [Integration Services](#integration-services)
    - [Screen Resolution](#screen-resolution)
  - [Networking](#networking)
    - [WSL Forwarding](#wsl-forwarding)
    - [VM Network Adapters](#vm-network-adapters)
    - [Hyper-V Broken DHCP](#hyper-v-broken-dhcp)
  - [Storage](#storage)
    - [Converting Disk](#converting-disk)
  - [WSL](#wsl)
    - [Installation](#installation)
    - [Import custom distribution](#import-custom-distribution)


## VM Operation

### Creation

```powershell
# Set VM Name, Switch Name, and Installation Media Path.
$VMName = 'kvm_efi'
$Switch = 'Default Switch'
$InstallMedia = 'C:\iso\rhel-8.5-x86_64-dvd.iso'

# Create new Virtual Machine and Virtual Hard Drive
New-VM -Name $VMName `
       -Generation 2 `
       -MemoryStartupBytes 4GB `
       -NewVHDPath "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\$VMName\$VMName.vhdx" `
       -NewVHDSizeBytes 20GB
       -Path "C:\ProgramData\Microsoft\Windows\Hyper-V\$VMName" `
       -Switch $Switch

# Disable Dynamic Memory
Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $false

# Set processor count and dynamic memory
Set-VMProcessor -VMName $VMName -Count 2

# Enable Virtualization Extensions
Set-VMProcessor -VMName "kvm01" -ExposeVirtualizationExtensions $true

# Disable Secure Boot
Set-VMFirmware -VMName $VMName -EnableSecureBoot Off

# Add DVD Drive to Virtual Machine
Add-VMScsiController -VMName $VMName
Add-VMDvdDrive -VMName $VMName -ControllerNumber 1 -ControllerLocation 0 -Path $InstallMedia

# Mount Installation Media
$DVDDrive = Get-VMDvdDrive -VMName $VMName

# Configure Virtual Machine to Boot from DVD
Set-VMFirmware -VMName $VMName -FirstBootDevice $DVDDrive

# Start VM
Start-VM -Name $VMName
```


### Properties

```powershell
Get-VM -Name $VMName | Select-Object *
```

### State

```powershell
# List all Registered VMs
Get-VM

# Start VM
Start-VM $VMName

# Stop VM
Stop-VM $VMName
```

### Removal

```powershell
# Retrieve the VHDX path
$VHDX = Get-VM $VMName | Select-Object -ExpandProperty HardDrives | Select-Object Path

# Stop VM and Remove VHDX and VM
Stop-VM $VMName
Remove-Item -Path $VHDX.Path
Remove-VM $VMName -Force
```



## Linux Guest

### Virtual Hardware Settings

Recommendations

- Generation 2
- Enable Secure Boot with Microsoft EUFI Certificate Authority

### Virtualization Extensions

Virtualization extensions unlock additional CPU features for Guest VM such as Intel VMX or AMD SVM. These are required if you want to have nested virtualization, meaning running VM inside another VM.

```powershell
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true
```

### Integration Services

From Windows Host

```powershell
# Get list of running integration Services
Get-VMIntegrationService -VMName $VMName

# Turn on Guest Service Interface
Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
```

From Linux Guest, the integration services are provided through kernel. The driver name is `hv_utils`.

```bash
# Verify if the driver is loaded
lsmod | grep hv_utils
hv_utils               45056  3
hv_vmbus              122880  7 hv_balloon,hv_utils,hv_netvsc,hid_hyperv,hv_storvsc,hyperv_keyboard,hyperv_fb

# Verify if related daemons are running
ps -ef | grep hv | grep -v grep
root         469       2  0 10:00 ?        00:00:00 [hv_vmbus_con]
root         477       2  0 10:00 ?        00:00:00 [hv_pri_chan]
root         478       2  0 10:00 ?        00:00:00 [hv_sub_chan]
root         768       2  0 10:00 ?        00:00:00 [hv_balloon]
```

### Screen Resolution

With default GRUB arguments the maximum screen resolution will be set to `1024 x 768`. In order to enable HD resolutions you need to edit the `/etc/default/grub` file and add `video=hyperv_fb:1920x1080` argument to the `GRUB_CMDLINE_LINUX_DEFAULT` line.

Afterwards run `sudo update-grub` and `reboot`.

An alternative option is to use `grubby`

```bash
# Check the current Grub entries configuration
grubby --info=ALL

# Add new argument at the end for all entries
grubby --update-kernel=ALL --args="video=hyperv_fb:1920x1080"
```

In order to set resolution in Desktop environment, you can use the `xrandr --size 1920x1080` command.

## Networking

### WSL Forwarding

The communication from `Default Network` to outside is enabled using default NAT. However in order to allow traffic to WSL Network you need to enable it from Windows Host.

```powershell
Get-NetIPInterface | where {$_.InterfaceAlias -eq 'vEthernet (WSL)' -or $_.InterfaceAlias -eq 'vEthernet (Default Switch)'} | Set-NetIPInterface -Forwarding Enabled
```

### VM Network Adapters

```powershell
# Retrieve VM IP Address
Get-VM -Name $VMName `
| select -ExpandProperty networkadapters `
| select vmname, ipaddresses

VMName IPAddresses
------ -----------
kvm01  {172.25.139.59, fe80::215:5dff:fe73:d133}
```


### Hyper-V Broken DHCP

From time to time, it happens that Hyper-V VMs will not receive any IP address via DHCP.

A full host restart usually solves the issues, however I have found out that restarting the following service is also sufficient.

```powershell
Restart-Service -DisplayName "Internet Connection Sharing (ICS)"
```


## Storage

### Converting Disk

Convert `vmdk` to `vhdx`.

```powershell
qemu-img convert .\Metasploitable.vmdk -O vhdx -o subformat=dynamic .\Metasploitable.vhdx
```


## WSL

This section describes WSL specific configuration.

### Installation

The latest [WSL package](https://devblogs.microsoft.com/commandline/the-windows-subsystem-for-linux-in-the-microsoft-store-is-now-generally-available-on-windows-10-and-11/) can now be installed via Windows Store. In order to do so on older Windows releases, you need to make sure you have [KB5020030](https://www.catalog.update.microsoft.com/Search.aspx?q=KB5020030) applied first.


### Import custom distribution

In the following example, we are going to create a custom WSL2 distribution based on Arch Linux. Lets start by creating a new container.


```bash
docker run -it --name arch archlinux
```

Once the container is running, update packages and perform base system customizations.

```bash
pacman -Syu --noconfirm
pacman -Sy  --noconfirm \
            base-devel \
            sudo \
            vim \
            wget \
            iproute2 \
            uzip \
            jq \
            exa \
            bind
```

```bash
echo 'mkukan ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/99_mkukan
chmod 440 /etc/sudoers.d/99_mkukan

useradd -G wheel,users -m mkukan
echo "mkukan:archrocks"|chpasswd
```

```bash
cat <<EOF > /etc/wsl.conf
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"

[user]
default=mkukan

[network]
generateResolvConf = false
EOF
```


Exit the container, export the image.

```bash
docker export --output /tmp/arch.tar arch
```

> **Note**: The exported container image will not contain the Kernel as it is shared between all WSL2 instances. The release information can be retrieved with `wsl --status`. And can be update with `wsl --update`.

From Windows environment, import the distribution.

```powershell
wsl --import arch C:\wsl\arch \\wsl$\Ubuntu-work\tmp\arch.tar
```

Once the import has been successful you can run the instance with `wsl -d arch`.

