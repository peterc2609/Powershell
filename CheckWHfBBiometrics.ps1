# Import necessary Windows API functions
Add-Type @"
    using System;
    using System.Runtime.InteropServices;

    public class WinBio {
        [DllImport("Winbio.dll")]
        public static extern int WinBioEnumBiometricUnits(int Factor, out IntPtr UnitSchemaArray, out int UnitCount);
        
        [DllImport("Winbio.dll")]
        public static extern int WinBioEnumEnrollments(IntPtr SessionHandle, uint UnitId, IntPtr Identity, out IntPtr SubFactorArray, out int SubFactorCount);

        [StructLayout(LayoutKind.Sequential)]
        public struct WINBIO_UNIT_SCHEMA {
            public uint UnitId;
            public Guid PoolType;
            public uint BiometricFactor;
            public uint SensorSubType;
            public uint Capabilities;
            public ushort ManufacturerName;
            public ushort ModelName;
            public ushort SerialNumber;
            public ushort FirmwareVersion;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct WINBIO_BIOMETRIC_SUBTYPE {
            public byte SubType;
        }
    }
"@

# Constants for the WinBio API
$WINBIO_TYPE_FACIAL_FEATURES = 8

# Check if facial recognition is enrolled
function Test-FacialRecognitionEnrollment {
    $unitSchemaArrayPtr = [IntPtr]::Zero
    $unitCount = 0
    $result = [WinBio]::WinBioEnumBiometricUnits($WINBIO_TYPE_FACIAL_FEATURES, [ref]$unitSchemaArrayPtr, [ref]$unitCount)
    
    if ($result -ne 0) {
        Write-Error "Failed to enumerate biometric units. Error code: $result"
        return $false
    }
    
    if ($unitCount -eq 0) {
        Write-Output "No facial recognition units found."
        return $false
    }

    $unitSchemaSize = [System.Runtime.InteropServices.Marshal]::SizeOf([WinBio+WINBIO_UNIT_SCHEMA])
    for ($i = 0; $i -lt $unitCount; $i++) {
        $unitSchema = [System.Runtime.InteropServices.Marshal]::PtrToStructure([IntPtr]::Add($unitSchemaArrayPtr, $i * $unitSchemaSize), [WinBio+WINBIO_UNIT_SCHEMA])
        $sessionHandle = [IntPtr]::Zero
        $identityPtr = [IntPtr]::Zero
        $subFactorArrayPtr = [IntPtr]::Zero
        $subFactorCount = 0

        $result = [WinBio]::WinBioEnumEnrollments($sessionHandle, $unitSchema.UnitId, $identityPtr, [ref]$subFactorArrayPtr, [ref]$subFactorCount)
        
        if ($result -eq 0 -and $subFactorCount -gt 0) {
            # Facial recognition is enrolled
            return $true
        }
    }

    return $false
}

if (Test-FacialRecognitionEnrollment) {
    Write-Output "Windows Hello for Business face login is set up."
} else {
    Write-Output "Windows Hello for Business face login is not set up."
}
