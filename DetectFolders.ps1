# Detect the folders
$folders = @(
    "c:\Program Files (x86)\Online Services\Amazon",
    "c:\Program Files (x86)\Online Services\Adobe",
    "c:\Program Files (x86)\Online Services\Bing"
)

# Return a 1 if any of the folders are found
$success = $false
foreach ($folder in $folders) {
    if (Test-Path $folder) {
        $success = $true
        break
    }
}

# Return the success status as an integer
Write-Output $success ? 1 : 0
