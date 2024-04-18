$registrySettings = @(
    @{Path = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Windows PowerShell"; Name = "MaxSize"; Value = 1073741824},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Powershell\Operational"; Name = "MaxSize"; Value = 1073741824},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-TaskScheduler\Operational"; Name = "MaxSize"; Value = 274066954}
)

$logFile = "C:\temp\remediation_log.txt"

foreach ($setting in $registrySettings) {
    if (Test-Path $setting.Path) {
        try {
            $currentValue = Get-ItemPropertyValue -Path $setting.Path -Name $setting.Name -ErrorAction Stop
            if ($currentValue -ne $setting.Value) {
                Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value
                Add-Content -Path $logFile -Value "Set $($setting.Name) to $($setting.Value) at $($setting.Path) because the current value was incorrect."
            }
        } catch {
            New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType DWord -Force
            Add-Content -Path $logFile -Value "Created $($setting.Name) with value $($setting.Value) at $($setting.Path) because it did not exist."
        }
    }
    else {
        New-Item -Path $setting.Path -Force
        New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType DWord -Force
        Add-Content -Path $logFile -Value "Created path $($setting.Path) and set $($setting.Name) with value $($setting.Value) because the path did not exist."
    }
}

Add-Content -Path $logFile -Value "Remediation script completed."
