# Function to set BIOS setting and write registry key
Function Set_BIOS_Setting {
    param (
        [string]$SettingName,
        [string]$SettingValue,
        [string]$BIOS_PWD
    )
    
    try {
        # Get the WMI Class
        $BIOSSettings = Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class HP_BIOSSettingInterface
        
        # Set the BIOS setting
        $ChangeBIOS_State = $BIOSSettings.SetBIOSSetting($SettingName, $SettingValue, "<utf-16/>" + "$BIOS_PWD")
        
        #Check Return Code is 0
        $ChangeBIOS_State_Code = $ChangeBIOS_State.return
        If(($ChangeBIOS_State_Code) -eq 0)
        {
            #Write Log
            Write_Log -Message_Type "SUCCESS" -Message "$SettingName set to $SettingValue"
            Write-Output "$SettingName set to $SettingValue SUCCESS"

            #Create Registry Key Path if it doesn't exist
            if (!(Test-Path $RegistryPath)) {
                New-Item -Path $RegistryPath -Force | Out-Null
            }

            #Write to registry
            Set-ItemProperty -Path $RegistryPath -Name $SettingName -Value $SettingValue -force
            Write_Log -Message_Type "SUCCESS" -Message "Registry Key for $SettingName set to $SettingValue"

        }
        Else
        {
            Write_Log -Message_Type "ERROR" -Message "Failed to set $SettingName to $SettingValue"
            Write-Output "Failed to set $SettingName to $SettingValue Failed"
        }
    }
}
