$registrySettings = @(
    @{Path = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Windows PowerShell"; Name = "MaxSize"; Value = 1073741824},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Powershell\Operational"; Name = "MaxSize"; Value = 1073741824},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-TaskScheduler\Operational"; Name = "MaxSize"; Value = 274066954}
)

$remediationRequired = $false
$logFile = "C:\temp\log.txt"

foreach ($setting in $registrySettings) {
    if (Test-Path $setting.Path) {
        try {
            $currentValue = Get-ItemPropertyValue -Path $setting.Path -Name $setting.Name -ErrorAction Stop
            if ($currentValue -ne $setting.Value) {
                Add-Content -Path $logFile -Value "Remediation required for $($setting.Path). Current value: $currentValue. Expected value: $($setting.Value)."
                $remediationRequired = $true
            } else {
                Add-Content -Path $logFile -Value "No remediation required for $($setting.Path). Current value matches expected value: $($setting.Value)."
            }
        } catch {
            Add-Content -Path $logFile -Value "MaxSize key does not exist at $($setting.Path). Remediation required."
            $remediationRequired = $true
        }
    }
    else {
        Add-Content -Path $logFile -Value "Path $($setting.Path) does not exist. Remediation required."
        $remediationRequired = $true
    }
}

if ($remediationRequired) {
    Add-Content -Path $logFile -Value "Remediation is required for one or more settings."
    exit 1
}
else {
    Add-Content -Path $logFile -Value "All settings are correct. No remediation required."
    exit 0
}
