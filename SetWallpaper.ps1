$LogPath = "C:\ProgramData\Microsoft\IntuneApps\OspreyWallpaper\WallpaperDeploy.log"
function Write-Log { param($msg); "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg" | Out-File -Append -FilePath $LogPath }

Write-Log "=== Scheduled Task Started ==="
Start-Sleep -Seconds 30
Write-Log "Waited 30 seconds after logon"

$Wallpaper = "C:\OspreyWallpaper\img1.jpg"
if (-not (Test-Path $Wallpaper)) {
    Write-Log "Wallpaper not found at $Wallpaper"
    exit 1
}

try {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $Wallpaper -Force
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "10" -Force
    Write-Log "Wallpaper registry values set"
    rundll32.exe user32.dll,UpdatePerUserSystemParameters ,1 ,True
    Write-Log "Wallpaper refresh triggered"
} catch {
    Write-Log "Error setting wallpaper: $_"
    exit 1
}

schtasks /Delete /TN "SetOspreyWallpaper" /F
Write-Log "Scheduled Task deleted"
Write-Log "=== Scheduled Task Completed ==="
