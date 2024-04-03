$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Windows PowerShell"
$valueName = "MaxSize"
$correctValue = 1073741824

$value = Get-ItemPropertyValue -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue

if ($value -ne $correctValue) {
    Write-Host "Remediation is required."
    exit 1
}
else {
    Write-Host "No remediation required."
    exit 0
}
