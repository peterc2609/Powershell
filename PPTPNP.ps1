# Define the source URL of the template on SharePoint Online
$sourceUrl = "https://yoursharepointdomain.sharepoint.com/sites/yoursite/Shared%20Documents/templates/blank.potx"

# Define the local path where you want to save the template
$localPath = "C:\Users\$env:USERNAME\AppData\Roaming\Microsoft\Templates\blank.potx"

# Connect to SharePoint Online; this command might prompt for credentials
# If your organization uses MFA, this prompt will handle it
Connect-PnPOnline -Url "https://yoursharepointdomain.sharepoint.com/sites/yoursite" -UseWebLogin

# Download the file
Get-PnPFile -Url "/sites/yoursite/Shared Documents/templates/blank.potx" -Path $localPath -AsFile -Force

# Optional: Check if the file was downloaded successfully
If (Test-Path $localPath) {
    Write-Output "Template 'blank.potx' has been updated successfully."
} Else {
    Write-Output "Failed to download the template."
}
