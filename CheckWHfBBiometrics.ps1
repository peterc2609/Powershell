# Function to check if Windows Biometric Service is running
function Get-BiometricServiceStatus {
    $service = Get-Service -Name "WbioSrvc" -ErrorAction SilentlyContinue
    if ($service.Status -eq "Running") {
        return $true
    }
    return $false
}

# Function to check for facial recognition enrollment
function Get-FacialRecognitionStatus {
    $facialRecognitionSet = $false

    try {
        # Ensure Windows Biometric Service is running
        if (Get-BiometricServiceStatus) {
            # Get the biometric information for the current user
            $biometricData = Get-WmiObject -Namespace "root\CIMv2\TerminalServices" -Class "Win32_TerminalServiceSetting"

            foreach ($data in $biometricData) {
                if ($data.IsFaceDetected -eq $true) {
                    $facialRecognitionSet = $true
                    break
                }
            }
        }
    } catch {
        Write-Error "An error occurred while checking biometric status: $_"
    }

    return $facialRecognitionSet
}

if (Get-FacialRecognitionStatus) {
    Write-Output "Windows Hello for Business face login is set up."
} else {
    Write-Output "Windows Hello for Business face login is not set up."
}
