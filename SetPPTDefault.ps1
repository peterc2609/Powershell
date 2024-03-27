# Define the SharePoint URL and the local template path
$sharePointUrl = "https://yourorganization.sharepoint.com/sites/YourSite/Shared%20Documents/blank.potx"
$localTemplatePath = "$env:APPDATA\Microsoft\Templates\Blank.potx"

# Download the template from SharePoint
Invoke-WebRequest -Uri $sharePointUrl -OutFile $localTemplatePath -UseDefaultCredentials

# Check if the download was successful
if (Test-Path $localTemplatePath) {
    Write-Output "Template 'blank.potx' successfully copied to $localTemplatePath."
} else {
    Write-Error "Failed to download 'blank.potx' from SharePoint."
}

# No further action required to set as default. Saving it as Blank.potx in the Templates folder does this automatically.
