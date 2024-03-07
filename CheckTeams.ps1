# Function to verify the presence of Microsoft Teams on the system
function Check-TeamsInstallation {
    return (Get-AppxPackage *MSTeams* -ErrorAction SilentlyContinue) -ne $null
}

# Function to determine if Microsoft Teams is set as the default instant messaging application
function Check-TeamsAsDefaultIM {
    $registryPath = "HKCU:\Software\IM Providers"
    $registryKey = "DefaultIMApp"
    $defaultIMAppSetting = Get-ItemProperty -Path $registryPath -Name $registryKey -ErrorAction SilentlyContinue

    return ($defaultIMAppSetting -ne $null) -and ($defaultIMAppSetting.DefaultIMApp -eq "MSTeams")
}

# Execution logic of the script
$teamsPresence = Check-TeamsInstallation
$teamsDefaultSetting = Check-TeamsAsDefaultIM

# Determine the status and set exit code accordingly
if ($teamsPresence -and $teamsDefaultSetting) {
    Write-Host "Microsoft Teams is installed and configured as the default IM app."
    exit 0 # Indicates success: Teams is installed and set as default
} elseif ($teamsPresence -or $teamsDefaultSetting) {
    Write-Host "Microsoft Teams is installed but not configured as the default IM app."
    exit 1 # Indicates partial success: Teams is installed but not set as default or vice versa
} else {
    Write-Host "Microsoft Teams is not installed."
    exit 1 # Indicates failure: Teams is not installed
}
