$registrySettings = @(
    @{Path = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Windows PowerShell"; Name = "MaxSize"; Value = 1073741824},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-Powershell/Operational"; Name = "MaxSize"; Value = 1073741824},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-TaskScheduler/Operational"; Name = "MaxSize"; Value = 274066954},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-AppLocker/EXE and DLL"; Name = "MaxSize"; Value = 104857600},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-AppLocker/MSI and Script"; Name = "MaxSize"; Value = 104857600},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-AppLocker/Packaged app-Deployment"; Name = "MaxSize"; Value = 104857600},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-AppLocker/Packaged app-Execution"; Name = "MaxSize"; Value = 104857600}
)

$logFile = "C:\ProgramData\Microsoft\IntuneApps\EventLogSize\remediation_log.txt"
$logDir = Split-Path -Path $logFile

# Ensure the log directory exists
if (-Not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force
}

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
    } else {
        New-Item -Path $setting.Path -Force
        New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType DWord -Force
        Add-Content -Path $logFile -Value "Created path $($setting.Path) and set $($setting.Name) with value $($setting.Value) because the path did not exist."
    }
}

Add-Content -Path $logFile -Value "Remediation script completed."
