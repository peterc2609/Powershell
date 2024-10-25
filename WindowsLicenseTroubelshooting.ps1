# Set the output directory (ensure this path is accessible or synced for easy retrieval)
$outputDir = "C:\ProgramData\Microsoft\IntuneLicenseOutputs"
New-Item -ItemType Directory -Path $outputDir -Force -ErrorAction SilentlyContinue

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

# Function to decrypt and output the full license key if available (OEM or Retail licenses only)
function Get-ProductKey {
    $keyPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"
    $digitalProductId = (Get-ItemProperty -Path $keyPath -Name "DigitalProductId").DigitalProductId
    $key = ""

    # Decrypt the key using Windows product key decryption algorithm
    for ($i = 24; $i -ge 0; $i--) {
        $cur = 0
        for ($j = 14; $j -ge 0; $j--) {
            $cur = $cur * 256 -bxor $digitalProductId[$j + 52]
            $digitalProductId[$j + 52] = [math]::Floor([double]($cur / 24))
            $cur = $cur % 24
        }
        $key = ("BCDFGHJKMPQRTVWXY2346789"[$cur] + $key)
        if (($i % 5) -eq 0 -and $i -ne 0) {
            $key = "-" + $key
        }
    }
    Write-Output "Decrypted Windows Product Key: $key"
}

# Save the decrypted product key to output file
Get-ProductKey | Out-File -FilePath "$outputDir\ProductKey_Decrypted.txt"

# 1. Attempt Activation with slmgr.vbs /ato
Write-Output "Attempting to activate Windows using slmgr.vbs /ato..." | Out-File -FilePath "$outputDir\Activation_Attempt.txt"
& cscript.exe //nologo C:\Windows\System32\slmgr.vbs /ato | Out-File -Append -FilePath "$outputDir\Activation_Attempt.txt"

# 2. slmgr.vbs Commands - Activation and Licensing Information
Write-Output "Running slmgr.vbs commands..." | Out-File -FilePath "$outputDir\Activation_Details.txt"
& cscript.exe //nologo C:\Windows\System32\slmgr.vbs /dlv | Out-File -Append -FilePath "$outputDir\Activation_Details.txt"
& cscript.exe //nologo C:\Windows\System32\slmgr.vbs /dli | Out-File -Append -FilePath "$outputDir\Activation_Details.txt"
& cscript.exe //nologo C:\Windows\System32\slmgr.vbs /xpr | Out-File -Append -FilePath "$outputDir\Activation_Details.txt"

# 3. LicensingDiag - Detailed Licensing Information
Write-Output "Running LicensingDiag.exe..." | Out-File -FilePath "$outputDir\LicensingDiag.txt"
LicensingDiag.exe -report "$outputDir\LicensingDiag.xml" -log "$outputDir\LicensingDiag.log"

# 4. Event Logs - Activation Events
Write-Output "Gathering activation-related event logs..." | Out-File -FilePath "$outputDir\ActivationEvents.txt"
Get-EventLog -LogName Application -Source SoftwareProtectionPlatform | Out-File -Append -FilePath "$outputDir\ActivationEvents.txt"

# 5. KMS Configuration Check
Write-Output "Checking KMS configuration with nslookup..." | Out-File -FilePath "$outputDir\KMS_Config.txt"
nslookup -type=all _vlmcs._tcp | Out-File -Append -FilePath "$outputDir\KMS_Config.txt"

# 6. Network Connectivity to Activation Server
Write-Output "Testing connectivity to Microsoft activation server..." | Out-File -FilePath "$outputDir\Network_Test.txt"
Test-NetConnection -ComputerName activation.sls.microsoft.com -Port 443 | Out-File -Append -FilePath "$outputDir\Network_Test.txt"

# 7. Windows Update Status - Checking for Pending Updates
Write-Output "Checking for pending Windows updates..." | Out-File -FilePath "$outputDir\WindowsUpdateStatus.txt"
$UpdateSearcher = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
$Updates = $UpdateSearcher.Search("IsInstalled=0").Updates
foreach ($Update in $Updates) {
    $Update.Title | Out-File -Append -FilePath "$outputDir\WindowsUpdateStatus.txt"
}

# 8. System Information for Context
Write-Output "Gathering system information..." | Out-File -FilePath "$outputDir\SystemInfo.txt"
systeminfo | Out-File -Append -FilePath "$outputDir\SystemInfo.txt"

# Completion Message
Write-Output "GVLK check, license key decryption, activation attempt, and detailed troubleshooting completed. Check the $outputDir directory for output files."
