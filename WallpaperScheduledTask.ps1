# Variables
$StorageAccountName = "yourStorageAccountName"  # <-- CHANGE
$ContainerName = "yourContainerName"            # <-- CHANGE
$SasToken = "?yourSasToken"                     # <-- CHANGE
$WallpaperFolder = "C:\OspreyWallpaper"
$WallpaperFileName = "1.jpg"
$WallpaperPath = Join-Path -Path $WallpaperFolder -ChildPath $WallpaperFileName
$TaskName = "SetOspreyWallpaper"
$LogFolder = "C:\ProgramData\Microsoft\IntuneApps\OspreyWallpaper"
$LogFile = Join-Path $LogFolder "WallpaperDeploy.log"

# Function: Write log
function Write-Log {
    param ([string]$Message)
    if (-not (Test-Path $LogFolder)) {
        New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
    }
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -FilePath $LogFile -Encoding utf8 -Append -Force
}

# Start logging
Write-Log "=== Starting Osprey Wallpaper Deployment ==="

# Ensure Az module
try {
    if (-not (Get-Module -ListAvailable -Name Az)) {
        Install-Module -Name Az -Scope CurrentUser -Force
    }
    Import-Module Az
    Write-Log "Az module loaded successfully."
} catch {
    Write-Log "Failed to load Az module: $_"
}

# Create wallpaper folder
if (-not (Test-Path -Path $WallpaperFolder)) {
    New-Item -ItemType Directory -Path $WallpaperFolder -Force
    Write-Log "Created wallpaper folder: $WallpaperFolder"
}

# Create Azure storage context
try {
    $Context = New-AzStorageContext -StorageAccountName $StorageAccountName -SasToken $SasToken
    Write-Log "Created Azure storage context."
} catch {
    Write-Log "Failed to create Azure storage context: $_"
}

# Download all jpg files
try {
    $Blobs = Get-AzStorageBlob -Container $ContainerName -Context $Context
    foreach ($Blob in $Blobs) {
        if ($Blob.Name -like "*.jpg") {
            $Destination = Join-Path -Path $WallpaperFolder -ChildPath $Blob.Name
            Get-AzStorageBlobContent -Blob $Blob.Name -Container $ContainerName -Destination $Destination -Context $Context -Force
            Write-Log "Downloaded $($Blob.Name) to $Destination"
        }
    }
} catch {
    Write-Log "Failed to download blobs: $_"
}

# Function: Set wallpaper in Default User
function Set-DefaultUserWallpaper {
    $DefaultUserProfile = "C:\Users\Default"
    $DefaultUserNTUser = Join-Path -Path $DefaultUserProfile -ChildPath "NTUSER.DAT"
    $TempHiveName = "DefaultTempHive"

    if (Test-Path $DefaultUserNTUser) {
        if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
            New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
        }
        reg load "HKU\$TempHiveName" "$DefaultUserNTUser" | Out-Null
        Write-Log "Loaded Default User NTUSER.DAT"

        try {
            Set-ItemProperty -Path "HKU:\$TempHiveName\Control Panel\Desktop" -Name Wallpaper -Value $WallpaperPath -Force
            Set-ItemProperty -Path "HKU:\$TempHiveName\Control Panel\Desktop" -Name WallpaperStyle -Value "10" -Force
            Write-Log "Default User wallpaper set successfully."
        } catch {
            Write-Log "Failed to update Default User wallpaper: $_"
        } finally {
            reg unload "HKU\$TempHiveName" | Out-Null
            Write-Log "Unloaded Default User NTUSER.DAT"
        }
    } else {
        Write-Log "Default User NTUSER.DAT not found, skipping."
    }
}

# Call Default User update
Set-DefaultUserWallpaper

# STEP 2: Create a scheduled task to run as user and set wallpaper
function Create-SetWallpaperTask {
    try {
        $WallpaperScript = @"
powershell.exe -ExecutionPolicy Bypass -Command `
    "Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -Value '$WallpaperPath'; `
     Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'; `
     rundll32.exe user32.dll,UpdatePerUserSystemParameters ,1 ,True; `
     schtasks /Delete /TN '$TaskName' /F"
"@

        $TempScriptPath = "$env:ProgramData\SetWallpaper.ps1"
        $WallpaperScript | Out-File -FilePath $TempScriptPath -Encoding UTF8 -Force
        Write-Log "Created temp script to set wallpaper: $TempScriptPath"

        $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$TempScriptPath`""
        $Trigger = New-ScheduledTaskTrigger -AtLogOn
        $Principal = New-ScheduledTaskPrincipal -UserId "INTERACTIVE" -RunLevel Limited

        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Force
        Write-Log "Scheduled task '$TaskName' created successfully."
    } catch {
        Write-Log "Failed to create scheduled task: $_"
    }
}

# Create the task
Create-SetWallpaperTask

Write-Log "=== Osprey Wallpaper Deployment Completed ==="
