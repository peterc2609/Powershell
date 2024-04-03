$registrySettings = @(
    @{Path = "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Windows PowerShell"; Name = "MaxSize"; Value = 1073741824},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Powershell\Operational"; Name = "MaxSize"; Value = 1073741824},
    @{Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-TaskScheduler\Operational"; Name = "MaxSize"; Value = 274066954}
)

foreach ($setting in $registrySettings) {
    # Check if the key exists; if not, create it and its parents as needed
    if (-not (Test-Path $setting.Path)) {
        $null = New-Item -Path $setting.Path -Force
    }

    # Set the value
    Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value

    Write-Host "Set $($setting.Name) to $($setting.Value) in $($setting.Path)"
}
