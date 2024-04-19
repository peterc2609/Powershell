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

$changesMade = $false

foreach ($setting in $registrySettings) {
    if (Test-Path $setting.Path) {
        try {
            $currentValue = Get-ItemPropertyValue -Path $setting.Path -Name $setting.Name -ErrorAction Stop
            if ($currentValue -ne $setting.Value) {
                Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value
                $logMessage = "Set $($setting.Name) to $($setting.Value) at $($setting.Path) because the current value was incorrect."
                Add-Content -Path $logFile -Value $logMessage
                Write-Host $logMessage
                $changesMade = $true
            }
        } catch {
            New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType DWord -Force
            $logMessage = "Created $($setting.Name) with value $($setting.Value) at $($setting.Path) because it did not exist."
            Add-Content -Path $logFile -Value $logMessage
            Write-Host $logMessage
            $changesMade = $true
        }
    } else {
        New-Item -Path $setting.Path -Force
        New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType DWord -Force
        $logMessage = "Created path $($setting.Path) and set $($setting.Name) with value $($setting.Value) because the path did not exist."
        Add-Content -Path $logFile -Value $logMessage
        Write-Host $logMessage
        $changesMade = $true
    }
}

$finalMessage = "Remediation script completed."
Add-Content -Path $logFile -Value $finalMessage
Write-Host $finalMessage

if ($changesMade) {
    exit 1  # Signal that changes were made
} else {
    exit 0  # Signal that no changes were needed
}
