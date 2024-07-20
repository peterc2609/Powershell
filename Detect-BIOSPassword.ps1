#This script will determine if  BIOS Password is set on a HP device.

#Log File Creation
$Log_File = "$env:SystemDrive\ProgramData\Microsoft\IntuneApps\OspreyBIOSPassword\Check_BIOS_password.log"
If(!(test-path $Log_File)){new-item $Log_File -type file -force}
Function Write_Log
	{
		param(
		$Message_Type,	
		$Message
		)
		
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"		
		write-host  "$MyDate - $Message_Type : $Message"		
	}	

#Check if BIOS Password is set
$Get_Manufacturer_Info = (gwmi win32_computersystem).Manufacturer

If($Get_Manufacturer_Info -like "*HP*")
{
    Write_Log -Message_Type "INFO" -Message "Manufacturer: HP"
    $IsPasswordSet = (Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class HP_BIOSSetting | Where-Object Name -eq "Setup password").IsSet
}
Else
{
    Write_Log -Message_Type "ERROR" -Message "This manufacturer is not supported"
    Write-output "This manufacturer is not supported"
    Exit 1
}

If(($IsPasswordSet -eq 1) -or ($IsPasswordSet -eq "true") -or ($IsPasswordSet -eq $true) -or ($IsPasswordSet -eq 2))
	{
		Write_Log -Message_Type "INFO" -Message "Your BIOS is password protected"	
	}
Else
	{
		Write_Log -Message_Type "ERROR" -Message "Your BIOS is not password protected"			
		Write-output "Your BIOS is not password protected"			
		Exit 1
	}