#Requires -RunAsAdministrator


################################################################


function Install-WinFeature ([string]$featureName )
{
    $feature = Get-WindowsFeature -Name $featureName

    try
    {
        if ($feature.Installed -eq $false)
        {
            Log-SetupStep -message "Installing $featureName" -level Information
            $featureResult = Install-WindowsFeature -Name $feature -IncludeManagementTools 
            # ToDo handle failure
            Log-SetupStep -message "Installed $featureName" -level Information
        }
        else
        {
            Log-SetupStep -message "$featureName already installed" -level Information
        }
    }    
    catch [System.Exception]
    {
         Log-SetupStep -message "Failed Installing $featureName" -level Warning
    }

}

function Install-Basic ()
{
    <#
        Possible features with Install-WindowsFeature

    #>
    
    Log-SetupStep -message "Starting MSMQ Install" -level Information
    Install-WinFeature -featureName ""

    Log-SetupStep -message "Done MSMQ Install" -level Information
}

function Install-IIS ()
{
    <#
        Possible features with Install-WindowsFeature
        Get-WindowsFeature -Name Web-*
    #>
    
    Log-SetupStep -message "Starting IIS Install" -level Information
    Install-WinFeature -featureName "Web-WebServer"
    Install-WinFeature -featureName "Web-Default-Doc"
    Install-WinFeature -featureName "Web-Dir-Browsing"
    Install-WinFeature -featureName "Web-Http-Errors"
    Install-WinFeature -featureName "Web-Static-Content"
    Install-WinFeature -featureName "Web-Http-Logging"
    Install-WinFeature -featureName "Web-Stat-Compression"
    Install-WinFeature -featureName "Web-Filtering"
    Install-WinFeature -featureName "Web-Basic-Auth"
    Install-WinFeature -featureName "Web-Windows-Auth"
    Install-WinFeature -featureName "Web-Asp-Net45"
    Install-WinFeature -featureName "Web-ISAPI-Ext"
    Install-WinFeature -featureName "Web-ISAPI-Filter"
    Install-WinFeature -featureName "Web-Mgmt-Console"
    Install-WinFeature -featureName "Web-Mgmt-Compat"
    Install-WinFeature -featureName "Web-Scripting-Tools"
    Install-WinFeature -featureName "Web-Mgmt-Service"

    Log-SetupStep -message "Done IIS Install" -level Information
}

function Install-MSMQ ()
{
    <#
        Possible features with Install-WindowsFeature
        MSMQ 
        MSMQ-DCOM 
        MSMQ-Directory 
        MSMQ-HTTP-Support 
        MSMQ-Multicasting 
        MSMQ-Routing 
        MSMQ-Server 
        MSMQ-Services 
        MSMQ-Triggers 
    #>
    
    Log-SetupStep -message "Starting MSMQ Install" -level Information
    Install-WinFeature -featureName "MSMQ"

    Log-SetupStep -message "Done MSMQ Install" -level Information
}


function Set-MSDTCSettings ()
{
    Log-SetupStep -message "Starting Set-MSDTCSettings" -level Information
    Set-DtcNetworkSetting -DtcName "Local" -AuthenticationLevel "NoAuth" -InboundTransactionsEnabled $True -OutboundTransactionsEnabled $True -RemoteClientAccessEnabled $True -RemoteAdministrationAccessEnabled $False -XATransactionsEnabled $False -LUTransactionsEnabled $False -Confirm:$False
    Log-SetupStep -message "Done Set-MSDTCSettings" -level Information
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
    Log-SetupStep -message "Starting Set-TLSSettings" -level Information
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

    Log-SetupStep -message "Done Set-TLSSettings" -level Information
    
}


function Install-SQLClient ($mediaLib,$logFullname)
{
    <#
    # SQL Client 11 needed for full TLS 1.2 support
    # https://support.microsoft.com/en-us/help/4091110/support-for-tls-1-2-protocol-in-biztalk-server
    # https://www.microsoft.com/en-us/download/details.aspx?id=50402&751be11f-ede8-5a0c-058c-2ee190a24fa6=True
    #>
    $fullPathToSQLClient = "$mediaLib\SQLClient\sqlncli.msi"
    if (Test-Path -Path $fullPathToSQLClient)
    {
        Log-SetupStep -message "Installing SQLClient '$fullPathToSQLClient'" -level Information
        Start-Process -FilePath $fullPathToSQLClient -ArgumentList "/quiet /passive /norestart /log $logFullname" -Wait
        Log-SetupStep -message "Installed SQLClient '$fullPathToSQLClient'"  -level Information      
    }
    else
    {
        Log-SetupStep -message "Did not find any SQLClient to install. Expected '$fullPathToSQLClient'"  -level Error
    }

}


################################################################
# Maincode
################################################################ 

$scriptfolder = [System.IO.Path]::GetDirectoryName( $MyInvocation.InvocationName)

Set-Location $scriptfolder
Import-Module "$scriptfolder\BtsSetupHelper.psm1" -Global -DisableNameChecking
Check-64Bit

$timestamp = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
$btsMedia = "C:\BizTalkMedia"

Install-MSMQ
Install-IIS
Set-MSDTCSettings
Set-COM3NetworkAccess
Set-TLSSettings
Install-SQLClient -mediaLib $btsMedia -logFullname  "$scriptfolder\Install-SQLClient_$timestamp.log"
