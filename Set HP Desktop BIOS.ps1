#********************************************************************************************
# Part to fill
#
# Azure application info (for getting secret from Key Vault)
$TenantID = "d3a2d0d3-7cc8-4f52-bbf9-85bd43d94279"
$App_ID = "3e139008-3233-43a5-add5-92949164eb0b"
$ThumbPrint = "EE87950229E3ABE244B9635BD3B26CD310E30251"
#
# Mode to install Az modules, 
# Choose Install if you want to install directly modules from PSGallery
# Choose Download if you want to download modules a blob storage and import them
$Az_Module_Install_Mode = "Install" # Install or Download
# Modules path on the web, like blob storage
$Az_Accounts_URL = ""
$Az_KeyVault_URL = ""
#
$vaultName = "kv-falcon-lenovo-bios-01"
$LENOVO_BIOS_PWD = "BiosPassword"
$DELL_BIOS_PWD = "DellBiosPassword"
$HP_BIOS_PWD = "HPBiosPassword"
#********************************************************************************************
Function Create_Registry_Content {
    $BIOS_Settings_Registry_Path = "HKLM:\SOFTWARE\BIOS_Management"
    If (!(test-path $BIOS_Settings_Registry_Path)) {
        New-Item $BIOS_Settings_Registry_Path -Force
    }

    New-ItemProperty -Path $BIOS_Settings_Registry_Path -Name "BIOS_Desktop_Settings_Updated" -Value "1" -Force | out-null
    New-ItemProperty -Path $BIOS_Settings_Registry_Path -Name "BIOS_Desktop_Settings_Version" -Value "1.0" -Force | out-null			
}
Function Install_Az_Module { 	
    If ($Is_Nuget_Installed -eq $True) {
        $Modules = @("Az.accounts", "Az.KeyVault")
        ForEach ($Module_Name in $Modules) {
            If (!(Get-InstalledModule $Module_Name)) { 
                Write_Log -Message_Type "INFO" -Message "The module $Module_Name has not been found"	
                Try {
                    Write_Log -Message_Type "INFO" -Message "The module $Module_Name is being installed"								
                    Install-Module $Module_Name -Force -Confirm:$False -AllowClobber -ErrorAction SilentlyContinue | out-null	
                    Write_Log -Message_Type "SUCCESS" -Message "The module $Module_Name has been installed"	
                    Write_Log -Message_Type "INFO" -Message "AZ.Accounts version $Module_Version"	
                }
                Catch {
                    Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been installed"			
                    write-output "The module $Module_Name has not been installed"			
                    EXIT 1							
                }															
            } 
            Else {
                Try {
                    Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been found"												
                    Import-Module $Module_Name -Force -ErrorAction SilentlyContinue 
                    Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been imported"	
                }
                Catch {
                    Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been imported"	
                    write-output "The module $Module_Name has not been imported"	
                    EXIT 1							
                }				
            } 				
        }
					
        If ((Get-Module "Az.accounts" -listavailable) -and (Get-Module "Az.KeyVault" -listavailable)) {
            Write_Log -Message_Type "INFO" -Message "Both modules are there"																			
        }
    }
}


$Old_Log_File = "$env:SystemDrive\ProgramData\Microsoft\IntuneApps\OspreyBIOSSettings\Set_BIOS_Settings.log"
$Log_File = "$env:SystemDrive\ProgramData\Microsoft\IntuneApps\OspreyBIOSSettings\Set_Osprey_BIOS_Settings.log"
#Remove Old Log File
If (test-path $Old_Log_File) {Remove-Item $Old_Log_File -force}

#Create New Log File
If (!(test-path $Log_File)) { new-item $Log_File -type file -force }
Function Write_Log {
    param(
        $Message_Type,	
        $Message
    )
		
    $MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)		
    Add-Content $Log_File  "$MyDate - $Message_Type : $Message"		
    write-host  "$MyDate - $Message_Type : $Message"		
}	

# We will install the Az.accounts module
$Is_Nuget_Installed = $False	
If (!(Get-PackageProvider NuGet -listavailable)) {
    Try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-PackageProvider -Name Nuget -MinimumVersion 2.8.5.201 -Force | out-null							
        Write_Log -Message_Type "SUCCESS" -Message "The package $Module_Name has been successfully installed"	
        $Is_Nuget_Installed = $True						
    }
    Catch {
        Write_Log -Message_Type "ERROR" -Message "An issue occured while installing package $Module_Name"	
        Break
    }
}
Else {
    $Is_Nuget_Installed = $True	
}
	
If ($Is_Nuget_Installed -eq $True) {
    If ($Az_Module_Install_Mode -eq "Install") {
        Install_Az_Module
    }
    Else {
        Import_from_Blob
    }	
}


If (($TenantID -eq "") -and ($App_ID -eq "") -and ($ThumbPrint -eq "")) {
    Write_Log -Message_Type "ERROR" -Message "Info is missing, please fill: TenantID, appid and thumbprint"		
    write-output "Info is missing, please fill: TenantID, appid and thumbprint"
    EXIT 1					
}
Else {
    $Appli_Infos_Filled = $True
}
	
If ($Appli_Infos_Filled -eq $True) {			
    Try {
        Write_Log -Message_Type "INFO" -Message "Connecting to your Azure application"														
        Connect-AzAccount -tenantid $TenantID -ApplicationId $App_ID -CertificateThumbprint $ThumbPrint | Out-null
        Write_Log -Message_Type "SUCCESS" -Message "Connection OK to your Azure application"			
        $Azure_App_Connnected = $True
    }
    Catch {
        Write_Log -Message_Type "ERROR" -Message "Connection OK to your Azure application"	
        write-output "Connection OK to your Azure application"	
        EXIT 1							
    }

    If ($Azure_App_Connnected -eq $True) {
        $Get_Manufacturer_Info = (gwmi win32_computersystem).Manufacturer
        Write_Log -Message_Type "INFO" -Message "Manufacturer is: $Get_Manufacturer_Info"			
        
        # Getting the BIOS password for Lenovo
        If ($Get_Manufacturer_Info -like "*Lenovo*") {
            Write_Log -Message_Type "INFO" -Message "Getting Lenovo BIOS Password"
            $Secret_BIOS_PWD = (Get-AzKeyVaultSecret -vaultName $vaultName -name $LENOVO_BIOS_PWD) | select *
            $Get_BIOS_PWD = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret_BIOS_PWD.SecretValue) 
            $BIOS_PWD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Get_BIOS_PWD) 			
            #Write_Log -Message_Type "INFO" -Message "BIOS password is: $BIOS_PWD"
            $Getting_KeyVault_PWD = $True 
        }

        # Getting the BIOS password for HP
        ElseIf ($Get_Manufacturer_Info -like "*HP*") {
            Write_Log -Message_Type "INFO" -Message "Getting HP BIOS Password"
            $Secret_BIOS_PWD = (Get-AzKeyVaultSecret -vaultName $vaultName -name $HP_BIOS_PWD) | select *
            $Get_BIOS_PWD = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret_BIOS_PWD.SecretValue) 
            $BIOS_PWD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Get_BIOS_PWD) 			
            #Write_Log -Message_Type "INFO" -Message "BIOS password is: $BIOS_PWD"    
            $Getting_KeyVault_PWD = $True 
        }

        # Getting the BIOS password for Dell
        If ($Get_Manufacturer_Info -like "*Dell*") {
            Write_Log -Message_Type "INFO" -Message "Getting Dell BIOS Password"            
            $Secret_BIOS_PWD = (Get-AzKeyVaultSecret -vaultName $vaultName -name $DELL_BIOS_PWD) | select *
            $Get_BIOS_PWD = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret_BIOS_PWD.SecretValue) 
            $BIOS_PWD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Get_BIOS_PWD) 			
            #Write_Log -Message_Type "INFO" -Message "BIOS password is: $BIOS_PWD"    
            $Getting_KeyVault_PWD = $True 
        }
    }

    If ($Getting_KeyVault_PWD -eq $True) {
        $Get_Manufacturer_Info = (gwmi win32_computersystem).Manufacturer
        Write_Log -Message_Type "INFO" -Message "Manufacturer is: $Get_Manufacturer_Info"											

        If (($Get_Manufacturer_Info -notlike "*HP*") -and ($Get_Manufacturer_Info -notlike "*Lenovo*") -and ($Get_Manufacturer_Info -notlike "*Dell*")) {
            Write_Log -Message_Type "ERROR" -Message "Device manufacturer not supported"											
            Break
            write-output "Device manufacturer not supported"		
            EXIT 1									
        }

        If ($Get_Manufacturer_Info -like "*Lenovo*") {
            $IsPasswordSet = (gwmi -Class Lenovo_BiosPasswordSettings -Namespace root\wmi).PasswordState
        }
        ElseIf ($Get_Manufacturer_Info -like "*HP*") {
            $IsPasswordSet = (Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class HP_BIOSSetting | Where-Object Name -eq "Setup password").IsSet							
        } 
        ElseIf ($Get_Manufacturer_Info -like "*Dell*") {
            $module_name = "DellBIOSProvider"
            If (Get-InstalledModule -Name DellBIOSProvider) { import-module DellBIOSProvider -Force } 
            Else { Install-Module -Name DellBIOSProvider -Force }	
            $IsPasswordSet = (Get-Item -Path DellSmbios:\Security\IsAdminPasswordSet).currentvalue 	
        } 

        If (($IsPasswordSet -eq 1) -or ($IsPasswordSet -eq "true") -or ($IsPasswordSet -eq 2)) {
            $Is_BIOS_Password_Protected = $True	
            Write_Log -Message_Type "INFO" -Message "There is a current BIOS password"																				
        }
        Else {
            $Is_BIOS_Password_Protected = $False
            Write_Log -Message_Type "INFO" -Message "There is no current BIOS password"													
        }

        If ($Is_BIOS_Password_Protected -eq $True) {
            If ($Get_Manufacturer_Info -like "*HP*") {
                Write_Log -Message_Type "INFO" -Message "Setting Desktop BIOS Settings for HP"											
                	Try
                	{
                		#Get WMI Class
                        $BIOSSettings = Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class HP_BIOSSettingInterface

                        #Set NumLock on at boot
                		$BIOSSettings.SetBIOSSetting("NumLock on at boot","Enable","<utf-16/>" + "$BIOS_PWD")				
                		Write_Log -Message_Type "SUCCESS" -Message "NumLock on at boot has been set to Enable"	
                		write-output "Change NumLock on at boot: Success"

                        #Disable Microphone
                        $BIOSSettings.SetBIOSSetting("Microphone","Disable","<utf-16/>" + "$BIOS_PWD")				
                		Write_Log -Message_Type "SUCCESS" -Message "Microphone set to Disable"	
                		write-output "Disable Microphone: Success" 

                        #Disable CD-ROM Boot
                        $BIOSSettings.SetBIOSSetting("CD-ROM Boot","Disable","<utf-16/>" + "$BIOS_PWD")				
                		Write_Log -Message_Type "SUCCESS" -Message "CD-ROM Boot set to Disable"	
                		write-output "Disable CD-ROM Boot: Success"   

                        #Disable USB Storage Boot
                        $BIOSSettings.SetBIOSSetting("USB Storage Boot","Disable","<utf-16/>" + "$BIOS_PWD")				
                		Write_Log -Message_Type "SUCCESS" -Message "USB Storage Boot set to Disable"	
                		write-output "Disable USB Storage Boot: Success"   

                        #Disable Network (PXE) Boot
                        $BIOSSettings.SetBIOSSetting("Network (PXE) Boot","Disable","<utf-16/>" + "$BIOS_PWD")				
                		Write_Log -Message_Type "SUCCESS" -Message "Network (PXE) Boot set to Disable"	
                		write-output "Disable Network (PXE) Boot: Success"   

                        #Write Registry Key
                		Create_Registry_Content
                		
                		EXIT 0
                	}
                	Catch
                	{
                		Write_Log -Message_Type "ERROR" -Message "BIOS Settings have not been changed"	
                		write-output "Change Settings: Failed"		
                		EXIT 1	
                	}		
            } 
            ElseIf ($Get_Manufacturer_Info -like "*Lenovo*") {
                Write_Log -Message_Type "INFO" -Message "Setting BIOS for Lenovo"											
                Try {
                
                    EXIT 0					
                }
                Catch {
                    Write_Log -Message_Type "ERROR" -Message "BIOS Settings have not been changed"		
                    write-output "BIOS Settings: Failed"			
                    EXIT 1						
                }						
            } 
            #NEED TO UPDATE FOR DELL
            ElseIf ($Get_Manufacturer_Info -like "*Dell*") {
                Write_Log -Message_Type "INFO" -Message "Changing BIOS for Dell"	
                #$New_PWD_Length = $New_PWD.Length
                #If(($New_PWD_Length -lt 4) -or ($New_PWD_Length -gt 32))
                #	{
                #		Write_Log -Message_Type "ERROR" -Message "New password length is not correct"	
                #		Write_Log -Message_Type "ERROR" -Message "Password must contain minimum 4, and maximum 32 characters"			
                #		Write_Log -Message_Type "INFO" -Message "Password length: $New_PWD_Length"												
                #		write-output "Password must contain minimum 4, and maximum 32 characters"	
                #		#Remove_Current_script
                #		EXIT 1												
                #	}
                #Else
                #	{
                #		Write_Log -Message_Type "INFO" -Message "Password length: $New_PWD_Length"																							
                #		Try
                #			{
                #				Set-Item -Path DellSmbios:\Security\AdminPassword $New_PWD -Password $Old_PWD -ErrorAction stop											
                #				Write_Log -Message_Type "SUCCESS" -Message "BIOS password has been changed"			
                #				write-output "Change password: Success"		
                #				Create_Registry_Content -KeyVault_New_PWD_Date $Get_New_PWD_Date -KeyVault_New_PWD_Version $Get_New_PWD_Version -Key_Vault_Old_PWD_Date $Get_New_PWD_Date -Key_Vault_Old_PWD_Version $Get_New_PWD_Version
                #				# Remove_Current_script
                #				EXIT 0					
                #			}
                #			Catch
                #			{
                #				$Exception_Error = $error[0]
                #				Write_Log -Message_Type "ERROR" -Message "BIOS password has not been changed"
                #				Write_Log -Message_Type "ERROR" -Message "Error: $Exception_Error"																										
                #				write-output "Change password: Failed"				
                #				# Remove_Current_script
                #				Check_Old_Password_version -Key_Vault_Old_PWD_Date $Get_Old_PWD_Date -Key_Vault_Old_PWD_Version	$Get_Old_PWD_Version									
                #				EXIT 1					
                #	    	}											
                #   }			
            } 
        }																		
        Else {
            If ($Get_Manufacturer_Info -like "*HP*") {
                Write_Log -Message_Type "INFO" -Message "Changing BIOS Settings for HP - No Password Set"
                Try
                	{
                		#Get WMI Class
                        $BIOSSettings = Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class HP_BIOSSettingInterface

                        #Set NumLock on at boot
                		$BIOSSettings.SetBIOSSetting("NumLock on at boot","Enable")				
                		Write_Log -Message_Type "SUCCESS" -Message "NumLock on at boot has been set to Enable"	
                		write-output "Change NumLock on at boot: Success"

                        #Disable Microphone
                        $BIOSSettings.SetBIOSSetting("Microphone","Disable")				
                		Write_Log -Message_Type "SUCCESS" -Message "Microphone set to Disable"	
                		write-output "Disable Microphone: Success" 

                        #Disable CD-ROM Boot
                        $BIOSSettings.SetBIOSSetting("CD-ROM Boot","Disable")				
                		Write_Log -Message_Type "SUCCESS" -Message "CD-ROM Boot set to Disable"	
                		write-output "Disable CD-ROM Boot: Success"   

                        #Disable Microphone
                        $BIOSSettings.SetBIOSSetting("USB Storage Boot","Disable")				
                		Write_Log -Message_Type "SUCCESS" -Message "USB Storage Boot set to Disable"	
                		write-output "Disable USB Storage Boot: Success"   

                        #Disable Microphone
                        $BIOSSettings.SetBIOSSetting("Network (PXE) Boot","Disable")				
                		Write_Log -Message_Type "SUCCESS" -Message "Network (PXE) Boot set to Disable"	
                		write-output "Disable Network (PXE) Boot: Success"  

                        #Write Registry Key
                		Create_Registry_Content
                		
                		EXIT 0
                	}
                	Catch
                	{
                		Write_Log -Message_Type "ERROR" -Message "BIOS Settings have not been changed"	
                		write-output "Change Settings: Failed"		
                		EXIT 1	
                	}													
            } 
            ElseIf ($Get_Manufacturer_Info -like "*Lenovo*") {
                Write_Log -Message_Type "INFO" -Message "Changing BIOS Settings for Lenovo - No Password Set"
                #try {
                 #   $BIOSSettings = Get-WmiObject -Namespace root\wmi -Class Lenovo_SetBiosSetting
                  #  $BIOSSettings.SetBiosSetting("BottomCoverTamperDetected,Enable") | out-null	                                    
                   # $SaveLenovoBIOS = (gwmi -class Lenovo_SaveBiosSettings -namespace root\wmi)
                    #$SaveLenovoBIOS.SaveBiosSettings()
            
                    #Write_Log -Message_Type "SUCCESS" -Message "BIOS Settings have been changed"	
                    #write-output "BIOS Settings: Success"
                    #Create_Registry_Content
                                    
                    #EXIT 0                                    
                #}
                #catch {
                    #Write_Log -Message_Type "ERROR" -Message "BIOS Settings have not been changed"														
                    #write-output "Change BIOS Settings: Failed"	
                    #EXIT 1
                #}

            } 
            ElseIf ($Get_Manufacturer_Info -like "*Dell*") {				
                Write_Log -Message_Type "INFO" -Message "NOT SET UP YET - Changing BIOS Settings for Dell - No Password Set"											
                #Try
                #{
                #	Set-Item -Path DellSmbios:\Security\AdminPassword "$AdminPwd"
                #	Write_Log -Message_Type "SUCCESS" -Message "BIOS password has been changed"		
                #	write-output "Change password: Success"			
                #	Create_Registry_Content -KeyVault_New_PWD_Date $Get_New_PWD_Date -KeyVault_New_PWD_Version $Get_New_PWD_Version -Key_Vault_Old_PWD_Date $Get_New_PWD_Date -Key_Vault_Old_PWD_Version $Get_New_PWD_Version
                #	#Remove_Current_script
                #	EXIT 0											
                #}
                #Catch
                #{
                #	Write_Log -Message_Type "ERROR" -Message "BIOS password has not been changed"														
                #	write-output "Change password: Failed"				
                #	#Remove_Current_script
                #	EXIT 1					
            }					
							
        } 
    }
}					