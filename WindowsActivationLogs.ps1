# Set the output directory (ensure this path is accessible or synced for easy retrieval)
$outputDir = "C:\IntuneOutputs"
New-Item -ItemType Directory -Path $outputDir -Force -ErrorAction SilentlyContinue

# Log file for tracking script execution issues
$logFile = "$outputDir\ScriptExecutionLog.txt"

# Function to check for GVLK and retrieve OEM Digital License Key if present
Write-Output "Checking for Generic Volume License Key (GVLK) and OEM Digital License Key..." | Out-File -FilePath "$outputDir\GVLK_Check.txt"
$CheckForGVLK = Get-WmiObject SoftwareLicensingProduct -Filter "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f' and LicenseStatus = '5'"
$CheckForGVLK = $CheckForGVLK.ProductKeyChannel

if ($CheckForGVLK -eq 'Volume:GVLK') {
    Write-Output "GVLK detected. Attempting to retrieve OEM Digital License Key..." | Out-File -Append -FilePath "$outputDir\GVLK_Check.txt"
    $GetDigitalLicence = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
    Write-Output "OEM Digital License Key: $GetDigitalLicence" | Out-File -Append -FilePath "$outputDir\GVLK_Check.txt"
} else {
    Write-Output "GVLK not detected, or system is not volume-licensed." | Out-File -Append -FilePath "$outputDir\GVLK_Check.txt"
}

# Attempt to retrieve the MAK/OEM key from firmware if available
$OEMKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
if ($OEMKey) {
    Write-Output "OEM Product Key from Firmware: $OEMKey" | Out-File -FilePath "$outputDir\ProductKey_Firmware.txt"
} else {
    Write-Output "No OEM key found in firmware." | Out-File -FilePath "$outputDir\ProductKey_Firmware.txt"
}

# 1. Attempt Activation with slmgr.vbs /ato
Write-Output "Attempting to activate Windows using slmgr.vbs /ato..." | Out-File -FilePath "$outputDir\Activation_Attempt.txt"
& cscript.exe //nologo C:\Windows\System32\slmgr.vbs /ato | Out-File -Append -FilePath "$outputDir\Activation_Attempt.txt"

# 2. slmgr.vbs Commands - Activation and Licensing Information
Write-Output "Running slmgr.vbs commands..." | Out-File -FilePath "$outputDir\Activation_Details.txt"
& cscript.exe //nologo C:\Windows\System32\slmgr.vbs /dlv | Out-File -Append -FilePath "$outputDir\Activation_Details.txt"
& cscript.exe //nologo C:\Windows\System32\slmgr.vbs /dli | Out-File -Append -FilePath "$outputDir\Activation_Details.txt"
& cscript.exe //nologo C:\Windows\System32\slmgr.vbs /xpr | Out-File -Append -FilePath "$outputDir\Activation_Details.txt"

# Logging for LicensingDiag.exe
Write-Output "Checking for LicensingDiag.exe presence and execution." | Out-File -Append -FilePath $logFile
$LicensingDiagPath = "$env:SystemRoot\SysNative\LicensingDiag.exe"  # Use SysNative to bypass redirection
if (Test-Path $LicensingDiagPath) {
    Write-Output "LicensingDiag.exe found at $LicensingDiagPath. Attempting to run..." | Out-File -Append -FilePath $logFile
    try {
        Start-Process -FilePath $LicensingDiagPath -ArgumentList "-report $outputDir\LicensingDiag.xml -log $outputDir\LicensingDiag.log" -NoNewWindow -Wait -ErrorAction Stop
        Write-Output "LicensingDiag.exe executed successfully." | Out-File -Append -FilePath $logFile
    } catch {
        Write-Output "LicensingDiag.exe failed to execute. Error: $_" | Out-File -Append -FilePath $logFile
    }
} else {
    Write-Output "LicensingDiag.exe not found at $LicensingDiagPath." | Out-File -Append -FilePath $logFile
}

# 3. Event Logs - Activation Events using Get-WinEvent
Write-Output "Gathering activation-related event logs..." | Out-File -FilePath "$outputDir\ActivationEvents.txt"
$filterHash = @{
    LogName   = 'Application'
    ProviderName = 'Software Protection Platform Service'
    Id        = 12288, 8198
}
try {
    Get-WinEvent -FilterHashtable $filterHash | Out-File -Append -FilePath "$outputDir\ActivationEvents.txt"
    Write-Output "Activation events collected successfully." | Out-File -Append -FilePath $logFile
} catch {
    Write-Output "Failed to collect activation events. Error: $_" | Out-File -Append -FilePath $logFile
}

# 4. KMS Configuration Check
Write-Output "Checking KMS configuration with nslookup..." | Out-File -FilePath "$outputDir\KMS_Config.txt"
nslookup -type=all _vlmcs._tcp | Out-File -Append -FilePath "$outputDir\KMS_Config.txt"

# 5. Network Connectivity to Activation Server
Write-Output "Testing connectivity to Microsoft activation server..." | Out-File -FilePath "$outputDir\Network_Test.txt"
Test-NetConnection -ComputerName activation.sls.microsoft.com -Port 443 | Out-File -Append -FilePath "$outputDir\Network_Test.txt"

# 6. Windows Update Status - Checking for Pending Updates
Write-Output "Checking for pending Windows updates..." | Out-File -FilePath "$outputDir\WindowsUpdateStatus.txt"
$UpdateSearcher = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
$Updates = $UpdateSearcher.Search("IsInstalled=0").Updates
foreach ($Update in $Updates) {
    $Update.Title | Out-File -Append -FilePath "$outputDir\WindowsUpdateStatus.txt"
}

# 7. System Information for Context
Write-Output "Gathering system information..." | Out-File -FilePath "$outputDir\SystemInfo.txt"
systeminfo | Out-File -Append -FilePath "$outputDir\SystemInfo.txt"

# Compress all output files into a single ZIP file named after the hostname
$hostname = $env:COMPUTERNAME
$zipPath = "$outputDir\$hostname.zip"
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($outputDir, $zipPath)
    Write-Output "Files successfully compressed into $zipPath." | Out-File -Append -FilePath $logFile
} catch {
    Write-Output "Failed to compress files. Error: $_" | Out-File -Append -FilePath $logFile
}

# Define Azure Blob Storage variables
$storageAccountName = "mystorageaccount"     # Replace with your storage account name
$containerName = "mycontainer"               # Replace with your blob container name
$storageAccountKey = "your_storage_account_key"  # Replace with your storage account key

# Authenticate and create the context for the storage account
try {
    $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
    Write-Output "Azure storage context created successfully." | Out-File -Append -FilePath $logFile
} catch {
    Write-Output "Failed to create Azure storage context. Error: $_" | Out-File -Append -FilePath $logFile
}

# Upload the ZIP file to the specified container
try {
    $blobName = "$hostname.zip"  # Set the blob name to the hostname ZIP file
    Set-AzStorageBlobContent -File $zipPath -Container $containerName -Blob $blobName -Context $storageContext
    Write-Output "ZIP file uploaded to Azure Blob Storage successfully as $blobName." | Out-File -Append -FilePath $logFile
} catch {
    Write-Output "Failed to upload ZIP file to Azure Blob Storage. Error: $_" | Out-File -Append -FilePath $logFile
}
