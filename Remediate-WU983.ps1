# Remediate-WU983.ps1
# Repairs component store, resets WU services/cache, and triggers a fresh scan/install.

$ErrorActionPreference = 'Stop'

# Prep logging
$logDir = 'C:\ProgramData\IntuneRemediation\WURepair'
$null = New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue
$log = Join-Path $logDir 'remediate.log'
"[$(Get-Date -Format s)] Starting remediation" | Out-File $log -Append

# Ensure 64-bit PowerShell for DISM/SFC accuracy (when Intune runs 32-bit)
if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -and $env:PROCESSOR_ARCHITEW6432 -eq 'AMD64') {
    "Re-launching in 64-bit PowerShell" | Out-File $log -Append
    $sysNative = "$env:WINDIR\SysNative\WindowsPowerShell\v1.0\powershell.exe"
    & $sysNative -ExecutionPolicy Bypass -File $PSCommandPath
    exit $LASTEXITCODE
}

# 0) If a reboot is pending, set a RunOnce and return (updates can’t proceed cleanly)
function Test-PendingReboot {
    try {
        $paths = @(
          'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
          'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
          'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        )
        foreach ($p in $paths) {
            if (Test-Path $p) {
                if ($p -like '*Session Manager') {
                    $val = (Get-ItemProperty $p -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue).PendingFileRenameOperations
                    if ($val) { return $true }
                } else {
                    return $true
                }
            }
        }
        return $false
    } catch { return $false }
}

if (Test-PendingReboot) {
    "Reboot is pending; scheduling scan post-restart" | Out-File $log -Append
    New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'WUScanPostReboot' -PropertyType String -Value 'powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep 30; UsoClient StartScan; UsoClient StartDownload; UsoClient StartInstall"' -Force | Out-File $log -Append
    exit 1
}

# 1) Stop WU services
$services = 'wuauserv','bits','cryptsvc','msiserver'
foreach ($s in $services) {
    try {
        "Stopping $s" | Out-File $log -Append
        Stop-Service $s -Force -ErrorAction SilentlyContinue
    } catch { "Stop $s failed: $_" | Out-File $log -Append }
}

# 2) Clear SoftwareDistribution + catroot2
try {
    "Clearing SoftwareDistribution" | Out-File $log -Append
    Remove-Item -Recurse -Force 'C:\Windows\SoftwareDistribution' -ErrorAction SilentlyContinue
    "Resetting catroot2" | Out-File $log -Append
    Rename-Item 'C:\Windows\System32\catroot2' "catroot2.bak.$([DateTime]::Now.ToString('yyyyMMddHHmmss'))" -ErrorAction SilentlyContinue
} catch {
    "Cache reset error: $_" | Out-File $log -Append
}

# 3) Start services back
foreach ($s in $services) {
    try {
        "Starting $s" | Out-File $log -Append
        Start-Service $s -ErrorAction SilentlyContinue
    } catch { "Start $s failed: $_" | Out-File $log -Append }
}

# 4) Component store repair (can be lengthy)
try {
    "Running DISM /RestoreHealth" | Out-File $log -Append
    $dism = Start-Process -FilePath DISM.exe -ArgumentList '/Online','/Cleanup-Image','/RestoreHealth' -Wait -PassThru -WindowStyle Hidden
    "DISM exit code: $($dism.ExitCode)" | Out-File $log -Append
} catch {
    "DISM failed: $_" | Out-File $log -Append
}

# 5) System file check
try {
    "Running SFC /scannow" | Out-File $log -Append
    $sfc = Start-Process -FilePath 'sfc.exe' -ArgumentList '/scannow' -Wait -PassThru -WindowStyle Hidden
    "SFC exit code: $($sfc.ExitCode)" | Out-File $log -Append
} catch {
    "SFC failed: $_" | Out-File $log -Append
}

# 6) Trigger a fresh scan & install attempt
try {
    "Triggering scan/download/install via UsoClient" | Out-File $log -Append
    Start-Process -FilePath "$env:WINDIR\System32\UsoClient.exe" -ArgumentList 'StartScan' -WindowStyle Hidden -Wait
    Start-Process -FilePath "$env:WINDIR\System32\UsoClient.exe" -ArgumentList 'StartDownload' -WindowStyle Hidden -Wait
    Start-Process -FilePath "$env:WINDIR\System32\UsoClient.exe" -ArgumentList 'StartInstall' -WindowStyle Hidden -Wait
} catch {
    "USO trigger failed: $_" | Out-File $log -Append
}

"[$(Get-Date -Format s)] Remediation complete" | Out-File $log -Append
# Exit 0 to mark remediated. If Intune re-runs detect next cycle it should flip to compliant.
exit 0
