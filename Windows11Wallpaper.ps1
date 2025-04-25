# Ensure the Azure PowerShell module is installed
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -Scope CurrentUser -Force
}

# Import the Az module
Import-Module Az

# Variables – Replace these with your actual values
$StorageAccountName = "yourStorageAccountName"
$StorageAccountKey = "yourStorageAccountKey"
$ContainerName = "yourContainerName"
$LocalWallpaperDir = "C:\OspreyWallpaper"
$WallpaperFileName = "1.jpg"
$WallpaperStyle = "10"  # Fill

# Create the local directory if it doesn't exist
if (-not (Test-Path -Path $LocalWallpaperDir)) {
    New-Item -ItemType Directory -Path $LocalWallpaperDir -Force
}

# Create the storage context
$Context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

# Retrieve all blobs in the container
$Blobs = Get-AzStorageBlob -Container $ContainerName -Context $Context

# Download each .jpg file to the local directory
foreach ($Blob in $Blobs) {
    if ($Blob.Name -like "*.jpg") {
        $Destination = Join-Path -Path $LocalWallpaperDir -ChildPath $Blob.Name
        Get-AzStorageBlobContent -Blob $Blob.Name -Container $ContainerName -Destination $Destination -Context $Context -Force
    }
}

# Function to set wallpaper for a given user profile
function Set-WallpaperForUser {
    param (
        [string]$UserHive,
        [string]$UserSID
    )

    $WallpaperPath = Join-Path -Path $LocalWallpaperDir -ChildPath $WallpaperFileName

    # Set the wallpaper path
    Set-ItemProperty -Path "$UserHive\Control Panel\Desktop" -Name Wallpaper -Value $WallpaperPath

    # Set the wallpaper style
    Set-ItemProperty -Path "$UserHive\Control Panel\Desktop" -Name WallpaperStyle -Value $WallpaperStyle

    # Refresh the desktop to apply changes
    $null = Start-Process -FilePath "rundll32.exe" -ArgumentList "user32.dll,UpdatePerUserSystemParameters" -NoNewWindow -Wait
}

# Get all user profiles from the registry
$UserProfiles = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'

foreach ($Profile in $UserProfiles) {
    $SID = $Profile.PSChildName
    $ProfilePath = (Get-ItemProperty -Path $Profile.PSPath).ProfileImagePath

    # Skip system profiles
    if ($ProfilePath -like "*System32*") {
        continue
    }

    # Load the user's registry hive
    $UserHivePath = "$ProfilePath\NTUSER.DAT"
    $TempHiveName = "TempHive_$SID"

    if (Test-Path $UserHivePath) {
        reg load "HKU\$TempHiveName" "$UserHivePath" | Out-Null

        try {
            # Set the wallpaper for the user
            Set-WallpaperForUser -UserHive "HKU:\$TempHiveName" -UserSID $SID
        } catch {
            Write-Warning "Failed to set wallpaper for user with SID $SID"
        } finally {
            # Unload the user's registry hive
            reg unload "HKU\$TempHiveName" | Out-Null
        }
    }
}
