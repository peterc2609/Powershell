# Detect-WU983.ps1
# Detects recent Windows Update failures with 0x800F0983 and flags if a reboot is pending.

$ErrorActionPreference = 'Stop'

# Simple log
$logDir = 'C:\ProgramData\IntuneRemediation\WURepair'
$null = New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue
$log = Join-Path $logDir 'detect.log'
"[$(Get-Date -Format s)] Starting detection" | Out-File -FilePath $log -Append

# 1) Check Windows UpdateClient failures in last 7 days for 0x800F0983
$needRemediate = $false
try {
    $filter = @{
        LogName = 'Microsoft-Windows-WindowsUpdateClient/Operational'
        Id      = 20 # Installation failure
        StartTime = (Get-Date).AddDays(-7)
    }
    $events = Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue
    if ($events) {
        foreach ($e in $events) {
            $xml = [xml]$e.ToXml()
            $msg = $e.Message
            if ($msg -match '0x800F0983') {
                "Found failure 0x800F0983 at $($e.TimeCreated): $msg" | Out-File $log -Append
                $needRemediate = $true
                break
            }
        }
    }
} catch {
    "WinEvent query failed: $_" | Out-File $log -Append
}

# 2) Reboot pending blocks installs anyway
function Test-PendingReboot {
    try {
        $reboot = $false
        $paths = @(
          'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
          'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
          'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' # PendingFileRenameOperations
        )
        foreach ($p in $paths) {
            if (Test-Path $p) {
                if ($p -like '*Session Manager') {
                    $val = (Get-ItemProperty $p -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue).PendingFileRenameOperations
                    if ($val) { $reboot = $true }
                } else {
                    $reboot = $true
                }
            }
        }
        return $reboot
    } catch { return $false }
}

$pendingReboot = Test-PendingReboot
"PendingReboot = $pendingReboot" | Out-File $log -Append

# Exit code semantics for Intune:
# 0 = compliant (no remediation)
# 1 = not compliant (run remediation)
# 2+ = error
if ($needRemediate -or $pendingReboot) {
    "Detection: non-compliant (needs remediation)" | Out-File $log -Append
    exit 1
} else {
    "Detection: compliant" | Out-File $log -Append
    exit 0
}
