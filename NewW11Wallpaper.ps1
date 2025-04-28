# Variables
$StorageAccountName = "yourStorageAccountName"  # <-- CHANGE THIS
$ContainerName = "yourContainerName"            # <-- CHANGE THIS
$SasToken = "?yourSasToken"                     # <-- CHANGE THIS (starts with ?sv=...)
$WallpaperFolder = "C:\OspreyWallpaper"
$WallpaperFileName = "1.jpg"
$WallpaperPath = Join-Path -Path $WallpaperFolder -ChildPath $WallpaperFileName

# Ensure Az module
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -Scope CurrentUser -Force
}
Import-Module Az

# Create wallpaper folder if not exist
if (-not (Test-Path -Path $WallpaperFolder)) {
    New-Item -ItemType Directory -Path $WallpaperFolder -Force
}

# Create Azure storage context
$Context = New-AzStorageContext -StorageAccountName $StorageAccountName -SasToken $SasToken

# Download all jpg files
$Blobs = Get-AzStorageBlob -Container $ContainerName -Context $Context
foreach ($Blob in $Blobs) {
    if ($Blob.Name -like "*.jpg") {
        $Destination = Join-Path -Path $WallpaperFolder -ChildPath $Blob.Name
        Get-AzStorageBlobContent -Blob $Blob.Name -Container $ContainerName -Destination $Destination -Context $Context -Force
    }
}

# Function: Set wallpaper registry values
function Set-WallpaperRegistry {
    param (
        [string]$HivePath
    )
    try {
        Set-ItemProperty -Path "$HivePath\Control Panel\Desktop" -Name Wallpaper -Value $WallpaperPath -Force
        Set-ItemProperty -Path "$HivePath\Control Panel\Desktop" -Name WallpaperStyle -Value "10" -Force  # 10 = Fill
    } catch {
        Write-Warning "Failed to set wallpaper at $HivePath"
    }
}

# STEP 1: Update Default User (C:\Users\Default\NTUSER.DAT)
$DefaultUserProfile = "C:\Users\Default"
$DefaultUserNTUser = Join-Path -Path $DefaultUserProfile -ChildPath "NTUSER.DAT"
$TempHiveName = "DefaultTempHive"

if (Test-Path $DefaultUserNTUser) {
    # Load the Default User NTUSER.DAT if not already loaded
    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
    }
    reg load "HKU\$TempHiveName" "$DefaultUserNTUser" | Out-Null

    try {
        Set-WallpaperRegistry -HivePath "HKU:\$TempHiveName"
    } catch {
        Write-Warning "Failed to update Default User wallpaper."
    } finally {
        reg unload "HKU\$TempHiveName" | Out-Null
    }
}

# STEP 2: If someone is already logged in, update HKCU
try {
    if (Test-Path "HKCU:\Control Panel\Desktop") {
        Set-WallpaperRegistry -HivePath "HKCU:"
        # Refresh user desktop
        rundll32.exe user32.dll, UpdatePerUserSystemParameters ,1 ,True
    }
} catch {
    Write-Warning "HKCU not available, skipping current user wallpaper."
}
