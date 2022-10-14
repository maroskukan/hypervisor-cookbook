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
  - [Storage](#storage)
    - [Converting Disk](#converting-disk)


## VM Operation

### Creation

```powershell
# Create new Virtual Machine and Virtual Hard Drive
New-VM `
-Name kvm01 `
-Generation 2 `
-path "C:\ProgramData\Microsoft\Windows\Hyper-V\kvm01" `
-MemoryStartupBytes 4096MB `
-NewVHDPath "C:\Users\Public\Documents\Hyper-V\Virtual hard disks\kvm01.vhdx" `
-NewVHDSizeBytes 50GB

# Enable Virtualization Extensions
Set-VMProcessor -VMName "kvm01" -ExposeVirtualizationExtensions $true

# Attach ISO to VM
Set-VMDvDDrive -VMName kvm01 -ControllerNumber 1 -Path "C:\Users\Public\Documents\Iso\rhel-8.5-x86_64-dvd.iso"

# Start VM
Start-VM -Name kvm01
```


### Properties

```powershell
Get-VM -Name kvm01 | Select-Object *
```

### State

```powershell
# List all Registered VMs
Get-VM

# Start VM
Start-VM kvm01

# Stop VM
Stop-VM kvm01
```

### Removal

```powershell
# Retrieve the VHDX path
$VHDX = Get-VM kvm01 | Select-Object -ExpandProperty HardDrives | Select-Object Path

# Stop VM and Remove VHDX and VM
Stop-VM kvm01
Remove-Item -Path $VHDX.Path
Remove-VM kvm01 -Force
```



## Linux Guest

### Virtual Hardware Settings

Recommendations

- Generation 2
- Enable Secure Boot with Microsoft EUFI Certificate Authority

### Virtualization Extensions

Virtualization extensions unlock additional CPU features for Guest VM such as Intel VMX or AMD SVM. These are required if you want to have nested virtualization, meaning running VM inside another VM.

```powershell
Set-VMProcessor -VMName "DemoVM" -ExposeVirtualizationExtensions $true
```

### Integration Services

From Windows Host

```powershell
# Get list of running integration Services
Get-VMIntegrationService -VMName "DemoVM"

# Turn on Guest Service Interface
Enable-VMIntegrationService -VMName "DemoVM" -Name "Guest Service Interface"
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
# Check the current Grub entries configuraiton
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
Get-VM -Name kvm01 `
| select -ExpandProperty networkadapters `
| select vmname, ipaddresses

VMName IPAddresses
------ -----------
kvm01  {172.25.139.59, fe80::215:5dff:fe73:d133}
```


## Storage

### Converting Disk

Convert `vmdk` to `vhdx`.

```powershell
qemu-img convert .\Metasploitable.vmdk -O vhdx -o subformat=dynamic .\Metasploitable.vhdx
```