<#
.SYNOPSIS
    Script to check the installation and usage of Microsoft NEW Teams on a user's computer.
 
.DESCRIPTION
    This script checks whether the new Microsoft Teams app is installed and if it is set as the default
    instant messaging app (IM). It distinguishes between new Teams and classic Teams based on installation
    and registry settings.
 
.NOTES
    File Name      : Check-NewTeamsInstallationANDUsage.ps1
    Author         : Eswar KONETI (@eskonr)
    Prerequisite   : Run with User rights
    Version History:
        1.0 - Initial script
 
#>
# Function to check if Microsoft Teams is installed
function Is-NewTeamsInstalled {
    return (Get-AppxPackage *MSTeams* -ErrorAction SilentlyContinue) -ne $null
}
 
# Function to check if Microsoft Teams is the default IM app
function Is-NewTeamsDefault {
    $registryPath = "HKCU:\Software\IM Providers"
    $registryKey = "DefaultIMApp"
    $defaultValue = Get-ItemProperty -Path $registryPath -Name $registryKey -ErrorAction SilentlyContinue
 
    return ($defaultValue -ne $null) -and ($defaultValue.DefaultIMApp -eq "MSTeams")
}
 
# Main script logic
$teamsInstalled = Is-NewTeamsInstalled
$teamsDefault = Is-NewTeamsDefault
 
if ($teamsInstalled -and $teamsDefault) {
    Write-Host "New Teams installed and is set Default!"
} elseif ($teamsInstalled -or $teamsDefault) {
    Write-Host "New Teams installed but not set Default."
} else {
    Write-Host "New Teams not installed."
}