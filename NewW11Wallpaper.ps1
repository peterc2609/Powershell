# Variables
$StorageAccountName = "yourStorageAccountName"  # <-- CHANGE
$ContainerName = "yourContainerName"            # <-- CHANGE
$SasToken = "?yourSasToken"                     # <-- CHANGE
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

# STEP 2: If someone is logged in, set their wallpaper correctly

function Set-LoggedOnUserWallpaper {
    try {
        # Find explorer.exe owner
        $Explorer = Get-Process explorer -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($Explorer) {
            $SessionId = $Explorer.SessionId
            $UserName = (Get-CimInstance Win32_SessionProcess | Where-Object { $_.SessionId -eq $SessionId -and $_.Name -eq 'explorer.exe' }).Antecedent | ForEach-Object {
                ($_ -split '"')[1]
            }

            if ($UserName) {
                Write-Output "Detected logged-in user: $UserName"

                # Create a script block to run as user
                $ScriptBlock = {
                    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value "C:\OspreyWallpaper\1.jpg"
                    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "10"
                    rundll32.exe user32.dll, UpdatePerUserSystemParameters ,1 ,True
                }

                # Run in user's session
                Invoke-Command -ScriptBlock $ScriptBlock
            } else {
                Write-Warning "Could not detect username from explorer.exe"
            }
        } else {
            Write-Warning "No explorer.exe process found, likely no user logged in."
        }
    } catch {
        Write-Warning "Failed to detect logged-in user wallpaper: $_"
    }
}

Set-LoggedOnUserWallpaper
