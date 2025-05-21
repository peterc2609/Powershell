# Ensure log folder exists
$logFolder = "C:\Temp"
$mainLog = "$logFolder\Windows11Migration.log"
$exceptionsLog = "$logFolder\Windows11Exceptions.log"
New-Item -ItemType Directory -Force -Path $logFolder | Out-Null
New-Item -ItemType File -Force -Path $mainLog | Out-Null
New-Item -ItemType File -Force -Path $exceptionsLog | Out-Null

# Logging functions
function Write-MainLog {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $mainLog -Value "[$timestamp] $message"
}

function Write-ExceptionLog {
    param($userPrincipalName, $reason)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $userPrincipalName - $reason"
    Add-Content -Path $exceptionsLog -Value $logMessage
    Write-MainLog "⚠️ Exception: $userPrincipalName - $reason"
}

# Connect to Graph
Connect-MgGraph -Scopes "Device.Read.All","User.Read.All","Group.ReadWrite.All","Directory.Read.All"
Write-MainLog "Connected to Microsoft Graph."

# Define your target group
$targetGroupId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Replace with your group ID

# Import users from CSV
$users = Import-Csv -Path "C:\Path\To\your_users.csv"

# Track success
$addedDevices = @()

foreach ($user in $users) {
    $upn = $user.UserPrincipalName
    Write-MainLog "🔄 Processing user: $upn"

    # Get user object
    $userObject = Get-MgUser -UserId $upn -ErrorAction SilentlyContinue
    if (-not $userObject) {
        Write-ExceptionLog -userPrincipalName $upn -reason "User not found"
        continue
    }
    Write-MainLog "👤 Found user: $($userObject.DisplayName)"

    # Get Windows devices
    Write-MainLog "🔍 Discovering Windows devices (excluding Desktops)..."
    $devices = Get-MgUserManagedDevice -UserId $upn -Filter "operatingSystem eq 'Windows'" -Top 5
    $devices = $devices | Where-Object { $_.Model -notmatch 'Desktop' }

    if ($devices.Count -eq 0) {
        Write-ExceptionLog -userPrincipalName $upn -reason "No valid Windows devices found (non-Desktop)"
        continue
    }

    if ($devices.Count -ge 5) {
        Write-ExceptionLog -userPrincipalName $upn -reason "User has 5 or more Windows devices"
    }

    $deviceSummaries = $devices | ForEach-Object { "$($_.DeviceName) [$($_.Model)]" }
    Write-MainLog "💻 Devices discovered: $($deviceSummaries -join ', ')"

    # Choose the most recently synced device
    $primaryDevice = $devices | Sort-Object -Property lastSyncDateTime -Descending | Select-Object -First 1

    # Get Entra device object
    $entraDevice = Get-MgDevice -Filter "deviceId eq '$($primaryDevice.azureADDeviceId)'" -Top 1
    if (-not $entraDevice) {
        Write-ExceptionLog -userPrincipalName $upn -reason "Device not found in EntraID: $($primaryDevice.deviceName)"
        continue
    }

    # Add to group
    try {
        New-MgGroupMember -GroupId $targetGroupId -DirectoryObjectId $entraDevice.Id
        Write-MainLog "✅ Added device $($primaryDevice.deviceName) ($($entraDevice.Id)) for $upn"
        $addedDevices += $entraDevice.Id
    } catch {
        Write-ExceptionLog -userPrincipalName $upn -reason "Failed to add device to group: $_"
    }
}

# Final Summary
Write-MainLog "=== Script Completed ==="
Write-MainLog "Devices added: $($addedDevices.Count)"
Write-MainLog "Exceptions logged: $(Get-Content $exceptionsLog | Measure-Object).Count"