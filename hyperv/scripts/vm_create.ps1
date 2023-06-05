# Define the input arguments
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true, HelpMessage="Specify the name of the virtual machine.")]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage="Specify the path to the source ISO file.")]
    [string]$IsoPath,

    [Parameter(Mandatory=$true, HelpMessage="Specify the size of the virtual machine (S, M, or L).")]
    [ValidateSet("S","M","L")]
    [string]$Size,

    [Parameter(HelpMessage="Specify the firmware of the virtual machine (BIOS or EUFI).")]
    [ValidateSet("BIOS", "UEFI")]
    [string]$Firmware = "UEFI",

    [Parameter(HelpMessage="Specify the name of the virtual switch to connect to.")]
    [string]$Network = "Default Switch",

    [Parameter(HelpMessage="Specify the state of the virtual machine (start or create).")]
    [ValidateSet("start", "create")]
    [string]$State = "start"
)

# Retrieve the virtual machine path
$VMPath = (Get-VMHost).VirtualMachinePath

# Check that the source ISO file exists
if (!(Test-Path $IsoPath)) {
    Write-Error "The specified ISO file '$IsoPath' does not exist."
    return
}

# Check that the destination virtual machine already exists
if ((Test-Path "$VMPath\Virtual Machines\$Name")) {
    Write-Error "The specified virtual machine '$Name' does already exist."
    return
}

# Define the virtual machine settings based on the T-shirt size
$vmSettings = @{
    "S" = @(2, 4GB, 50GB)
    "M" = @(4, 8GB, 100GB)
    "L" = @(8, 16GB, 200GB)
}

$vCpu, $vMem, $vHdd = $vmSettings[$Size]

# Create the virtual machine
if ($Firmware -eq "BIOS") {
    New-VM -Name $Name `
           -Generation 1 `
           -MemoryStartupBytes $vMem `
           -NewVHDPath "$VMPath\Virtual Machines\$Name\Virtual Hard Disks\$Name.vhdx" `
           -NewVHDSizeBytes $vHdd `
           -Switch $Network `
           -Path "$VMPath\Virtual Machines" | `
           Out-Null
    
    # Add DVD Drive to Virtual Machine
    Set-VMDvdDrive -VMName $Name -ControllerNumber 1 -ControllerLocation 0 -Path $isoPath

} elseif ($Firmware -eq "UEFI") {
    New-VM -Name $Name `
           -Generation 2 `
           -MemoryStartupBytes $vMem `
           -NewVHDPath "$VMPath\Virtual Machines\$Name\Virtual Hard Disks\$Name.vhdx" `
           -NewVHDSizeBytes $vHdd `
           -Switch $Network `
           -Path "$VMPath\Virtual Machines" | `
           Out-Null
    
    # Enable Secure Boot and update the template settings
    Set-VMFirmware -VMName $Name -EnableSecureBoot On
    Set-VMFirmware -VMName $Name -SecureBootTemplate MicrosoftUEFICertificateAuthority

    # Add DVD Drive to Virtual Machine
    Add-VMScsiController -VMName $Name
    Add-VMDvdDrive -VMName $Name -ControllerNumber 1 -ControllerLocation 0 -Path $isoPath

    # Mount Installation Media
    $DVDDrive = Get-VMDvdDrive -VMName $Name

    # Configure Virtual Machine to Boot from DVD
    Set-VMFirmware -VMName $Name -FirstBootDevice $DVDDrive
}

# Disable Dynamic Memory
Set-VMMemory -VMName $Name -DynamicMemoryEnabled $false

# Set the virtual machine processor count
Set-VMProcessor -VMName $Name -Count $vCpu

# Enable Virtualization Extensions
Set-VMProcessor -VMName $Name -ExposeVirtualizationExtensions $true


# Turn on Guest Service Interface
Enable-VMIntegrationService -VMName $Name -Name "Guest Service Interface"

# Disable Automatic Checkpoints
Set-VM -Name $Name -AutomaticCheckpointsEnabled $false

if ($State -eq "create") {
    # Print the machine serial number
    $vmInfo = Get-WmiObject -ComputerName localhost `
                            -Namespace root\virtualization\v2 `
                            -Class Msvm_VirtualSystemSettingData | `
                            Where-Object { $_.ElementName -eq $Name -and $_.BIOSSerialNumber } | `
                            Select-Object ElementName, BIOSSerialNumber | `
                            ConvertTo-Json
    Write-Output $vmInfo

}
if ($State -eq "start") {
    # Start the virtual machine
    Start-VM -Name $Name
    # Open the virtual machine console
    vmconnect.exe localhost $Name
}