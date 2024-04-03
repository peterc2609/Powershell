$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Windows PowerShell"
$valueName = "MaxSize"
$desiredValue = 1073741824

# Check if the key exists; if not, create it
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

# Set the value
Set-ItemProperty -Path $registryPath -Name $valueName -Value $desiredValue

Write-Host "MaxSize has been set to $desiredValue."
