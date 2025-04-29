# Paths
$wallpaperFolder = "C:\OspreyWallpaper"
$wallpaperFile = "img1.jpg"
$wallpaperPath = Join-Path $wallpaperFolder $wallpaperFile

$scriptFolder = "C:\ProgramData\OspreyWallpaper"
$scriptPath = Join-Path $scriptFolder "SetWallpaper.ps1"
$logPath = Join-Path $scriptFolder "WallpaperDeploy.log"
$taskName = "SetOspreyWallpaper"

# Create folders
if (-not (Test-Path $wallpaperFolder)) { New-Item $wallpaperFolder -ItemType Directory -Force }
if (-not (Test-Path $scriptFolder)) { New-Item $scriptFolder -ItemType Directory -Force }

# TODO: Copy or download img1.jpg into C:\OspreyWallpaper beforehand

# Write the wallpaper-setting script into ProgramData
@"
Start-Sleep -Seconds 20

function Log {
    param([string]`$msg)
    "`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - `$msg" | Out-File -FilePath "$logPath" -Encoding utf8 -Append -Force
}

Log "Started SetWallpaper.ps1 for user `$env:USERNAME"

if (Test-Path "$wallpaperPath") {
    try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value "$wallpaperPath"
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "10"
        rundll32.exe user32.dll,UpdatePerUserSystemParameters ,1 ,True
        Log "Wallpaper set and desktop refreshed."
    } catch {
        Log "Failed to set wallpaper: `$($_.Exception.Message)"
    }
} else {
    Log "Wallpaper not found at $wallpaperPath"
}

schtasks /Delete /TN "$taskName" /F
Log "Deleted scheduled task $taskName"
"@ | Out-File -FilePath $scriptPath -Encoding utf8 -Force

Write-Output "Created SetWallpaper.ps1"

# Create Scheduled Task to run at logon (for all users)
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId "Users" -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force

Write-Output "Registered task: $taskName"
