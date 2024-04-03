$registrySettings = @(
    @{Path = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Windows PowerShell"; Name = "MaxSize"; Value = 1073741824},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Powershell\Operational"; Name = "MaxSize"; Value = 1073741824},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-TaskScheduler\Operational"; Name = "MaxSize"; Value = 274066954}
)

$remediationRequired = $false

foreach ($setting in $registrySettings) {
    if (Test-Path $setting.Path) {
        $currentValue = Get-ItemPropertyValue -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
        if ($currentValue -ne $setting.Value) {
            Write-Host "Remediation required for $($setting.Path)"
            $remediationRequired = $true
        }
    }
    else {
        Write-Host "Path $($setting.Path) does not exist. Remediation required."
        $remediationRequired = $true
    }
}

if ($remediationRequired) {
    exit 1
}
else {
    Write-Host "All settings are correct. No remediation required."
    exit 0
}
