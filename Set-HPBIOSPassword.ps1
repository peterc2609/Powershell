#********************************************************************************************
# Part to fill
#
# Azure application info (for getting secret from Key Vault)
$TenantID = "d3a2d0d3-7cc8-4f52-bbf9-85bd43d94279"
$App_ID = "3e139008-3233-43a5-add5-92949164eb0b"
$ThumbPrint = "EE87950229E3ABE244B9635BD3B26CD310E30251"

# Mode to install Az modules, 
$Az_Module_Install_Mode = "Install" # Install or Download (We don't use Download)

# Set Key Vault Details
$vaultName = "kv-falcon-lenovo-bios-01"
$Secret_Name_New_PWD = "HPBiosPassword"
#********************************************************************************************

Function Install_Az_Module {
    param (
        [bool]$Is_Nuget_Installed
    )
    
    if ($Is_Nuget_Installed) {
        $Modules = @("Az.Accounts", "Az.KeyVault")
        foreach ($Module_Name in $Modules) {
            if (!(Get-InstalledModule -Name $Module_Name -ErrorAction SilentlyContinue)) {
                Write_Log -Message_Type "INFO" -Message "The module $Module_Name has not been found"
                try {
                    Write_Log -Message_Type "INFO" -Message "The module $Module_Name is being installed"
                    Install-Module -Name $Module_Name -Force -Confirm:$False -AllowClobber -ErrorAction Stop
                    Write_Log -Message_Type "SUCCESS" -Message "The module $Module_Name has been installed"
                } catch {
                    Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been installed"
                    Write-Output "The module $Module_Name has not been installed"
                    Exit 1
                }
            } else {
                try {
                    Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been found"
                    Import-Module -Name $Module_Name -Force -ErrorAction Stop
                    Write_Log -Message_Type "INFO" -Message "The module $Module_Name has been imported"
                } catch {
                    Write_Log -Message_Type "ERROR" -Message "The module $Module_Name has not been imported"
                    Write-Output "The module $Module_Name has not been imported"
                    Exit 1
                }
            }
        }

        if ((Get-Module -Name "Az.Accounts" -ListAvailable) -and (Get-Module -Name "Az.KeyVault" -ListAvailable)) {
            Write_Log -Message_Type "INFO" -Message "Both modules are available"
        }
    }
}

$Log_File = "$env:SystemDrive\ProgramData\Microsoft\IntuneApps\OspreyBIOSPassword\Set_BIOS_password.log"
if (!(Test-Path $Log_File)) {
    New-Item -Path $Log_File -ItemType File -Force | Out-Null
}

Function Write_Log {
    param (
        [string]$Message_Type,
        [string]$Message
    )

    $MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
    $LogEntry = "$MyDate - $Message_Type : $Message"
    Add-Content -Path $Log_File -Value $LogEntry
    Write-Output $LogEntry
}

# Install NuGet package provider if not already installed
$Is_Nuget_Installed = $False
if (!(Get-PackageProvider -Name NuGet -ListAvailable)) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
        Write_Log -Message_Type "SUCCESS" -Message "The NuGet package provider has been successfully installed"
        $Is_Nuget_Installed = $True
    } catch {
        Write_Log -Message_Type "ERROR" -Message "An issue occurred while installing the NuGet package provider"
        Exit 1
    }
} else {
    $Is_Nuget_Installed = $True
}

if ($Is_Nuget_Installed -eq $True) {
    if ($Az_Module_Install_Mode -eq "Install") {
        Install_Az_Module -Is_Nuget_Installed $Is_Nuget_Installed
    }
}

if (($TenantID -eq "") -or ($App_ID -eq "") -or ($ThumbPrint -eq "")) {
    Write_Log -Message_Type "ERROR" -Message "Info is missing, please fill: TenantID, App_ID, and Thumbprint"
    Write-Output "Info is missing, please fill: TenantID, App_ID, and Thumbprint"
    Exit 1
} else {
    $Appli_Infos_Filled = $True
}

if ($Appli_Infos_Filled -eq $True) {
    try {
        Write_Log -Message_Type "INFO" -Message "Connecting to your Azure application"
        Connect-AzAccount -TenantId $TenantID -ApplicationId $App_ID -CertificateThumbprint $ThumbPrint | Out-Null
        Write_Log -Message_Type "SUCCESS" -Message "Connection successful to your Azure application"
        $Azure_App_Connected = $True
    } catch {
        Write_Log -Message_Type "ERROR" -Message "Connection failed to your Azure application"
        Write-Output "Connection failed to your Azure application"
        Exit 1
    }

    if ($Azure_App_Connected -eq $True) {
        # Getting the HP BIOS password
        try {
            $Secret_New_PWD = Get-AzKeyVaultSecret -VaultName $vaultName -Name $Secret_Name_New_PWD
            $Get_New_PWD = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret_New_PWD.SecretValue)
            $New_PWD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($Get_New_PWD)
            $Getting_KeyVault_PWD = $True
        } catch {
            Write_Log -Message_Type "ERROR" -Message "Failed to retrieve the BIOS password from Key Vault"
            Write-Output "Failed to retrieve the BIOS password from Key Vault"
            Exit 1
        }

        if ($Getting_KeyVault_PWD -eq $True) {
            Write_Log -Message_Type "INFO" -Message "Setting BIOS password for HP"
            try {
                $bios = Get-WmiObject -Namespace root/hp/instrumentedBIOS -Class HP_BIOSSettingInterface
                $bios.SetBIOSSetting("Setup Password", "<utf-16/>" + "$New_PWD", "<utf-16/>")
                Write_Log -Message_Type "SUCCESS" -Message "BIOS password has been changed"
                Write-Output "Change password: Success"
                Exit 0
            } catch {
                Write_Log -Message_Type "ERROR" -Message "BIOS password has not been changed"
                Write-Output "Change password: Failed"
                Exit 1
            }
        }
    }
}