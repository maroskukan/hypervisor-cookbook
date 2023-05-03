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
    - [Name Resolution](#name-resolution)
  - [Storage](#storage)
    - [Converting Disk](#converting-disk)
  - [Tips](#tips)
    - [Permissions](#permissions)
  - [WSL](#wsl)
    - [Installation](#installation)
    - [Systemd](#systemd)
    - [Import custom distribution](#import-custom-distribution)
    - [Integration](#integration)
      - [Vagrant](#vagrant)
    - [Tips](#tips-1)
      - [Logon failure](#logon-failure)


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

To go beyond HD resolution, you need to also update the VM settings while it is powered off. Therefore start by updating the `GRUB_CMDLINE_LINUX_DEFAULT` value by appending `video=2560x1440`. Afterwards update configuration with `sudo update-grub` and shutdown the VM.

Then, check the display the current settings from host.

```powershell
Get-VMVideo $VMName
```

To set 2K resolution support:

```powershell
Set-VMVideo -VMName $VMName `
            -HorizontalResolution 2560 `
            -VerticalResolution 1440 `
            -ResolutionType Single
```

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


### Name Resolution

It is common that virtual networks used by Hyper-V change their IP subnet range during host reboots. This makes difficult to maintain a static mapping between IP addresses and hostnames (e.g. in `$Env:WinDir\System32\Drivers\etc\hosts`). However you can leverage the reserved domain `mshome.net` in order to resolve a VM name to its IP address.

```powershell
curl http://rhel9.mshome.net:8080/
It Works!
```

## Storage

### Converting Disk

Convert `vmdk` to `vhdx`.

```powershell
qemu-img convert .\Metasploitable.vmdk -O vhdx -o subformat=dynamic .\Metasploitable.vhdx
```


## Tips

### Permissions

```powershell
net localgroup 'Hyper-V Administrators' $(whoami) /add
```


## WSL

This section describes WSL specific configuration.

### Installation

The latest [WSL package](https://devblogs.microsoft.com/commandline/the-windows-subsystem-for-linux-in-the-microsoft-store-is-now-generally-available-on-windows-10-and-11/) can now be installed via Windows Store. In order to do so on older Windows releases, you need to make sure you have [KB5020030](https://www.catalog.update.microsoft.com/Search.aspx?q=KB5020030) applied first.


### Systemd

The support for systemd framerwork was [introduced](https://devblogs.microsoft.com/commandline/systemd-support-is-now-available-in-wsl/) in version WSL 0.67.6. Applications such as [docker engine](https://docs.docker.com/engine/install/), [minikube](https://minikube.sigs.k8s.io/docs/start/), [snap](https://ubuntu.com/core/services/guide/snaps-intro), [systemctl](https://www.freedesktop.org/software/systemd/man/systemctl.html) which are dependend on it can natively run inside WSL instance without any workarounds.

In order to enable this support, you need to include following lines in the `/etc/wsl.conf` configuration file inside the WSL instance and then restart it with `wsl.exe --shotdown` from host machine.

An example of `wsl.conf` file:

```ini
[boot]
systemd = true

[automount]
enabled = true
options = "metadata,umask=22,fmask=11"

[user]
default=mkukan

[network]
generateResolvConf = true
```


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


### Integration

#### Vagrant

In order to allow Vagrant intergration between WSL2 instance and Host running Hyper-V. You first need ensure that installed Vagrant version in Windows is same as in WSL2 instance.

If you are managing packages in Windows using `chocolatey`, it may happen that the available Vagrant version will be behind the one available through `apt`. For this reason, it may be feasible to lock the version in WSL2 instance to prevent automatic upgrades.

```bash
sudo apt-mark hold vagrant
```

To show and unhold:

```bash
sudo apt-mark showhold
```

```bash
sudo apt-mark unhold vagrant
```

Next, to enable the actual integration I recommend to add following code block to your [rc](https://raw.githubusercontent.com/maroskukan/dotfiles/main/.zshrc) file.

```bash
# Custom configuration for Vagrant
kernel=$(uname -r) 
chkvag=$(which vagrant)
if [[ "$kernel" == *"WSL2"* && -f $chkvag ]]; then
  # Enable Vagrant integration
  export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH="/mnt/c/Users/maros_kukan"
  export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=1
  export VAGRANT_DEFAULT_PROVIDER=hyperv
  # Enable forwarding between WSL network and Default Hyper-V Switch
  powershell.exe -c "Get-NetIPInterface | where {\$_.InterfaceAlias -eq 'vEthernet (WSL)' -or \$_.InterfaceAlias -eq 'vEthernet (Default Switch)'} | Set-NetIPInterface -Forwarding Enabled 2> \$null"
fi
```


### Tips

#### Logon failure

Issue

```powershell
Logon failure: the user has not been granted the requested logon type at this computer.
Error code: Wsl/Service/CreateInstance/CreateVm/0x80070569
```

Resolution #1

```powershell
powershell restart-service vmms
```

Resolution #2

```powershell
gpupdate /force
```

