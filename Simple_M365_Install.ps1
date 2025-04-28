[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][String]$ConfigurationXMLFile = "configuration.xml"
)

$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Stop'

# Create log file
$LogFile = Join-Path $PSScriptRoot "M365InstallLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
  param ([string]$Message)
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  "$timestamp - $Message" | Tee-Object -FilePath $LogFile -Append
}

try {
  $SetupExePath = Join-Path $PSScriptRoot "Setup.exe"
  $ConfigXMLPath = Join-Path $PSScriptRoot $ConfigurationXMLFile

  Write-Log "Starting Office installation using configuration file: $ConfigXMLPath"
  $process = Start-Process $SetupExePath -ArgumentList "/configure `"$ConfigXMLPath`"" -Wait -PassThru
  Write-Log "Office installation process exited with code: $($process.ExitCode)"

  switch ($process.ExitCode) {
    0 {
      Write-Log "Office installation completed successfully."
      exit 0
    }
    17002 {
      Write-Log "Office installation requires a reboot to complete. Exit code: 17002"
      exit 0
    }
    30102 {
      Write-Log "Office installation completed successfully, reboot required. Exit code: 30102"
      exit 0
    }
    default {
      Write-Log "ERROR: Office installation failed with exit code $($process.ExitCode)"
      exit $process.ExitCode
    }
  }
} catch {
  Write-Log "ERROR: Exception occurred during Office installation: $_"
  exit 1
}
