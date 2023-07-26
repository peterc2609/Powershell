# Detect the folders
$folders = @(
    "c:\Program Files (x86)\Online Services\Amazon",
    "c:\Program Files (x86)\Online Services\Adobe",
    "c:\Program Files (x86)\Online Services\Bing"
)

# Delete each folder and contents silently
foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Remove-Item $folder -Recurse -Force -Confirm:$false
    }
}
