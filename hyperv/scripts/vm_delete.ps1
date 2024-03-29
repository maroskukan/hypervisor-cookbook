# Define the input arguments
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true, HelpMessage="Specify the name of the virtual machine.")]
    [string]$Name
)

# Retrieve the virtual machine path
$VMPath = (Get-VMHost).VirtualMachinePath

# Check if you have access to the Virtual Machine folder
if (-not $(Get-ChildItem $VMPath -ErrorAction SilentlyContinue)) {
    explorer $VMPath
    Read-host "Once you gain access to $VMPath, press ENTER to continue..."
}

# Check that the destination virtual machine already exists
if (!(Test-Path "$VMPath\Virtual Machines\$Name")) {
    Write-Error "The specified virtual machine '$Name' does not exist."
    return
} else {
    Write-Host "Stopping virtual machine '$Name'..."
    # Stop Virtual Machine and delete it
    Stop-VM $Name -Force -WarningAction SilentlyContinue
    Write-Host "Removing virtual machine '$Name'..."
    Remove-VM $Name -Force
    Remove-Item -Path "$VMPath\Virtual Machines\$Name" -Force -Recurse

    # Check if vmconnect is currently opened and close it
    $processName = "vmconnect"

    if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
        Write-Host "Stopping the $processName process..."
        Stop-Process -Name $processName -Force
    }
}

