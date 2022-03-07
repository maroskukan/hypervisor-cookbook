# Hyper-V

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


## Networking

### WSL Forwarding

The communication from `Default Network` to outside is enabled using default NAT. However in order to allow traffic to WSL Network you need to enable it from Windows Host.

```powershell
Get-NetIPInterface | where {$_.InterfaceAlias -eq 'vEthernet (WSL)' -or $_.InterfaceAlias -eq 'vEthernet (Default Switch)'} | Set-NetIPInterface -Forwarding Enabled
```