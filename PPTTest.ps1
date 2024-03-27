$sourceUrl = "https://yoursharepointdomain.sharepoint.com/sites/yoursite/Shared%20Documents/templates/blank.potx"
$localPath = "C:\Users\$env:USERNAME\AppData\Roaming\Microsoft\Templates\blank.potx"

try {
    $response = Invoke-WebRequest -Uri $sourceUrl -UseDefaultCredentials -ErrorAction Stop
    $response.Content | Out-File -FilePath $localPath
    Write-Output "Download succeeded. File size: $(Get-Item $localPath).Length bytes."
} catch {
    Write-Error "Download failed: $_"
}
