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

    [Parameter(HelpMessage="Specify the name of the virtual switch to connect to.")]
    [string]$Network = "Default Switch"
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
New-VM -Name $Name `
       -Generation 2 `
       -MemoryStartupBytes $vMem `
       -NewVHDPath "$VMPath\Virtual Machines\$Name\Virtual Hard Disks\$Name.vhdx" `
       -NewVHDSizeBytes $vHdd `
       -Switch $Network `
       -Path "$VMPath\Virtual Machines"

# Disable Dynamic Memory
Set-VMMemory -VMName $Name -DynamicMemoryEnabled $false

# Set the virtual machine processor count
Set-VMProcessor -VMName $Name -Count $vCpu

# Enable Virtualization Extensions
Set-VMProcessor -VMName $Name -ExposeVirtualizationExtensions $true

# Enable Secure Boot and update the template settings
Set-VMFirmware -VMName $Name -EnableSecureBoot On
Set-VMFirmware -VMName $Name -SecureBootTemplate MicrosoftUEFICertificateAuthority

# Turn on Guest Service Interface
Enable-VMIntegrationService -VMName $Name -Name "Guest Service Interface"

# Add DVD Drive to Virtual Machine
Add-VMScsiController -VMName $Name
Add-VMDvdDrive -VMName $Name -ControllerNumber 1 -ControllerLocation 0 -Path $isoPath

# Mount Installation Media
$DVDDrive = Get-VMDvdDrive -VMName $Name

# Configure Virtual Machine to Boot from DVD
Set-VMFirmware -VMName $Name -FirstBootDevice $DVDDrive

# Disable Automatic Checkpoints
Set-VM -Name $Name -AutomaticCheckpointsEnabled $false

# Start the virtual machine
Start-VM -Name $Name

# Open the virtual machine console
vmconnect.exe localhost $Name