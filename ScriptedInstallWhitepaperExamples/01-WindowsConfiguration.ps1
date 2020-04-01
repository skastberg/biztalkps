#
# This is as sample script to enable Windows features and other configurations.
# 
#Requires -RunAsAdministrator


function Enable-Feature ( 
    [Parameter(Mandatory=$false,Position=0)][string]$featureName, 
    [Parameter(Mandatory=$false,Position=1)][string]$source = $null )
{
    $feature = Get-WindowsOptionalFeature -FeatureName $featureName -Online 

    if ($feature -eq $null)
    {
        Log-SetupStep -message "Feature: $featureName not found." -Level Error 
        return
    }
    if ($feature.State -ne "Enabled")
    {
        
        if ( [string]::IsNullOrWhiteSpace( $source))
        {
            Log-SetupStep -message "Enabling Feature: $featureName"
            $res = Enable-WindowsOptionalFeature -FeatureName $featureName -Online 
        }
        else
        {
            if (Test-Path -Path $source)
            {
                Log-SetupStep -message "Enabling Feature: $featureName with source '$source'"
                $res = Enable-WindowsOptionalFeature -FeatureName $featureName -Online -Source $source
            }
            else
            {
                Log-SetupStep -message "Not Enabling Feature: $featureName with source '$source'. Source not found" -level Warning
            }
        }
    }
    else
	{
        Log-SetupStep -message "Feature: $featureName already enabled."
    }
}


Function Enable-IISFeatures ()
{
Enable-Feature -featureName IIS-WebServerRole              
Enable-Feature -featureName IIS-WebServer                  
Enable-Feature -featureName IIS-CommonHttpFeatures         
Enable-Feature -featureName IIS-Security                   
Enable-Feature -featureName IIS-RequestFiltering           
Enable-Feature -featureName IIS-StaticContent              
Enable-Feature -featureName IIS-DefaultDocument            
Enable-Feature -featureName IIS-DirectoryBrowsing          
Enable-Feature -featureName IIS-HttpErrors                 
Enable-Feature -featureName IIS-HttpRedirect               
Enable-Feature -featureName IIS-ApplicationDevelopment     
Enable-Feature -featureName IIS-WebSockets                 
Enable-Feature -featureName IIS-ApplicationInit            
Enable-Feature -featureName IIS-NetFxExtensibility45       
Enable-Feature -featureName IIS-ISAPIExtensions            
Enable-Feature -featureName IIS-ISAPIFilter                
Enable-Feature -featureName IIS-ASPNET45                   
Enable-Feature -featureName IIS-HealthAndDiagnostics       
Enable-Feature -featureName IIS-HttpLogging                
Enable-Feature -featureName IIS-LoggingLibraries           
Enable-Feature -featureName IIS-RequestMonitor             
Enable-Feature -featureName IIS-HttpTracing                
Enable-Feature -featureName IIS-BasicAuthentication        
Enable-Feature -featureName IIS-WindowsAuthentication      
Enable-Feature -featureName IIS-Performance                
Enable-Feature -featureName IIS-HttpCompressionStatic      
Enable-Feature -featureName IIS-WebServerManagementTools   
Enable-Feature -featureName IIS-ManagementConsole          
Enable-Feature -featureName IIS-LegacySnapIn               
Enable-Feature -featureName IIS-IIS6ManagementCompatibility
Enable-Feature -featureName IIS-Metabase                   
Enable-Feature -featureName IIS-WMICompatibility           
Enable-Feature -featureName IIS-LegacyScripts    

}


function Configure-MSDTC ()
{
    Log-SetupStep -message "Entering Configure-MSDTC" -level Information
    # Ensure DTC is correctly installed. e.g. the machine was cloned
    $dtc = Get-Dtc
    if ($dtc -ne $null)
    {
        Log-SetupStep -message "Uninstalling DTC"
        Uninstall-Dtc -Confirm:$false    
    }
    Log-SetupStep -message "Installing DTC"
    Install-Dtc 

    Set-DtcNetworkSetting -DtcName "Local" -AuthenticationLevel "NoAuth" -InboundTransactionsEnabled $True -OutboundTransactionsEnabled $True -RemoteClientAccessEnabled $True -RemoteAdministrationAccessEnabled $False -XATransactionsEnabled $False -LUTransactionsEnabled $False -Confirm:$False;
   
    Log-SetupStep -message "Done Configure-MSDTC" -level Information
}

function Set-COM3NetworkAccess ()
{
    # Enable COM+ Network access 
    # https://social.technet.microsoft.com/Forums/en-US/cf49e572-f3a6-404f-84bd-0eff86ca89ae/com-network-access
    Log-SetupStep -message "Starting Set-COM3NetworkAccess" -level Information
    $registryPath = "HKLM:\SOFTWARE\Microsoft\COM3"
    $Name = "RemoteAccessEnabled"
    $value = "1"

    if(!(Test-Path $registryPath))
    {
        New-Item -Path $registryPath -Force | Out-Null
        New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
    }
    else
    {
        New-ItemProperty -Path $registryPath -Name $name -Value $value  -PropertyType DWORD -Force | Out-Null
    }
    Log-SetupStep -message "Done Set-COM3NetworkAccess" -level Information
}


function Set-TLSSettings ()
{
    Log-SetupStep -message "Set-TLSSettings - Start" -level Information
    <#
        https://support.microsoft.com/en-us/help/245030/how-to-restrict-the-use-of-certain-cryptographic-algorithms-and-protoc
        Make sure following registry settings are set to enable TLS 1.2
    #>
    if((Test-Path -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client") -ne $true) {  New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" -force -ea SilentlyContinue | OUT-NULL };
    if((Test-Path -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server") -ne $true) {  New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" -force -ea SilentlyContinue | OUT-NULL };
    if((Test-Path -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client") -ne $true) {  New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" -force -ea SilentlyContinue | OUT-NULL };
    if((Test-Path -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server") -ne $true) {  New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" -force -ea SilentlyContinue | OUT-NULL };
    if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319") -ne $true) {  New-Item "HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" -force -ea SilentlyContinue | OUT-NULL };
    if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319") -ne $true) {  New-Item "HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" -force -ea SilentlyContinue | OUT-NULL };
    if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp") -ne $true) {  New-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" -force -ea SilentlyContinue | OUT-NULL };
    if((Test-Path -LiteralPath "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp") -ne $true) {  New-Item "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" -force -ea SilentlyContinue | OUT-NULL };
    New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client' -Name 'DisabledByDefault' -Value 0x00000000  -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;
    New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client' -Name 'Enabled' -Value 0x00000001  -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;
    New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -Name 'DisabledByDefault' -Value 0x00000000  -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;
    New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' -Name 'Enabled' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;
    New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Name 'DisabledByDefault' -Value 0x00000000  -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;
    New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Name 'Enabled' -Value 0x00000001  -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;
    New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Name 'DisabledByDefault' -Value 0x00000000  -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;
    New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Name 'Enabled' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' -Name 'DefaultSecureProtocols' -Value 2688 -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;
    New-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp' -Name 'DefaultSecureProtocols' -Value 2688 -PropertyType DWord -Force -ea SilentlyContinue | OUT-NULL ;

    Log-SetupStep -message "Set-TLSSettings - Done" -level Information
    
}


function Set-FwRule()
{   Log-SetupStep -message "Set-FwRule - Start" 

    $ruleName = "My Custom Rule"
    $rule  = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($rule -eq $null)
    {
        $newRule = New-NetFirewallRule -DisplayName $ruleName -Group "BizTalk" -Direction Inbound -LocalPort 1434 -Protocol UDP  -Action Allow -Profile Domain 
        
        Log-SetupStep -message  "Adding '$ruleName'" -level Information
    }
    else
    {
        Log-SetupStep -message  "Firewall rule '$ruleName' existed, not changed" -level Warning
    }


    Enable-NetFirewallRule -DisplayName "COM+ Network Access (DCOM-In)"
    Enable-NetFirewallRule -DisplayName "COM+ Remote Administration (DCOM-In)"
    Enable-NetFirewallRule -DisplayName "Distributed Transaction Coordinator (RPC)"
    Enable-NetFirewallRule -DisplayName "Distributed Transaction Coordinator (RPC-EPMAP)"
    Enable-NetFirewallRule -DisplayName "Distributed Transaction Coordinator (TCP-In)"
    Enable-NetFirewallRule -DisplayName "Distributed Transaction Coordinator (TCP-Out)"


    Log-SetupStep -message  "Set-FwRule - Done"

   }


   function Enable-II32BitAppOnWin64 ([string]$appPool)
   {
    Log-SetupStep -message "Enable-II32BitAppOnWin64 $appPool - Start" 
    $pool = Get-IISAppPool -Name $appPool -ErrorAction SilentlyContinue
    if ($pool -ne $null)
    {
        $srvMgr = Get-IISServerManager
        $pool.Enable32BitAppOnWin64 = $true
        #Commit the local changes to server store.
        $srvMgr.CommitChanges()
        $pool.Recycle()
    }
    else
    {
         Log-SetupStep -message  "$appPool - not found!" -level Warning
    }

    Log-SetupStep -message  "Enable-II32BitAppOnWin64 $appPool - Done"
   }

################################################################
# Maincode
################################################################ 

$scriptfolder = [System.IO.Path]::GetDirectoryName( $MyInvocation.InvocationName)

Set-Location $scriptfolder
Import-Module "$scriptfolder\BtsSetupHelper.psm1" -Global -DisableNameChecking
Check-64Bit
Get-ScriptDirectory
$timestamp = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")


Enable-Feature -featureName MSMQ
Enable-IISFeatures
# Optional - required for the Sharepoint Adapter
Enable-Feature -featureName Windows-Identity-Foundation

# .NET 3.5 is Not necessary for BizTalk 2020
#Enable-Feature -featureName NetFX3 -source D:\sources\sxs # This row expects the source to be present in the specified path 

# Enable Network DTC Access
Configure-MSDTC

Set-COM3NetworkAccess
Set-TLSSettings
Set-FwRule

Enable-II32BitAppOnWin64 -appPool DefaultAppPool
