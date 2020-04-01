#
# The script is licensed "as-is." You bear the risk of using it. 
# The contributors give no express warranties, guarantees or conditions.
# Test it in safe environment and change it to fit your requirements.
#
#  Version 2.0
#Requires -RunAsAdministrator

param([Parameter(Mandatory=$true,Position=0)]
     $ConfigurationFile,[Parameter(Mandatory=$true,Position=1)]
     $KeepassFile   )

function Get-ScriptDirectory
{
    $scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value
    return Split-Path $scriptInvocation.MyCommand.Path
}


function Get-HostCredential ($kpDatabasePath, $kpPass, $userName, $entryPath)
{
    $MyCredential = $null
    $secret = Resolve-Secret -kpDatabasePath $kpDatabasePath -kpPass $kpPass -entryPath  $entryPath
    if ($secret)
    {
        $MyCredential=New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, $secret
    }
    else
    {
        $prompt = "Enter credentials for $userName"
        $MyCredential = Get-Credential -UserName $userName -Message $prompt 
    }
    
    return $MyCredential    
}


function Resolve-Secret ($kpDatabasePath, $kpPass, $entryPath)
{

    Import-Module PoShKeePass

    if ($kpPass -eq $null)
    {
        $kpPass = Read-Host -Prompt "MasterKey for '$pathToDatabase'" -AsSecureString
    }
    
    $kpconfig = Get-KeePassDatabaseConfiguration -DatabaseProfileName MasterKeyDB  
    if ($kpconfig.DatabasePath -ne $kpDatabasePath)
    {
        # Removes the configuration from the xml configuration file just in case
        Remove-KeePassDatabaseConfiguration -DatabaseProfileName 'MasterKeyDB' -Confirm:$false
    }

    if ($kpconfig -eq $null)
    {
        $kpconfig = New-KeePassDatabaseConfiguration -DatabaseProfileName 'MasterKeyDB' -DatabasePath $kpDatabasePath -UseMasterKey 
    }
    $key = [System.IO.Path]::GetFileName($entryPath)    
    $group =  [System.IO.Path]::GetDirectoryName($entryPath).Replace('\', '/')

    $ent = Get-KeePassEntry -Title $key -KeePassEntryGroupPath $group -MasterKey $kpPass -DatabaseProfileName MasterKeyDB 
    return $ent.Password

}




function Require-32Bit
{
    if ($env:PROCESSOR_ARCHITECTURE -ne "x86")
    {
        $scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value
        
        $errorText = "The script $($scriptInvocation.MyCommand) must run in a 32 bit PowerShell Host. Found architecture $env:PROCESSOR_ARCHITECTURE"
        Write-Error $errorText
        Exit
    }
    
}


#######################################
# Main code
#######################################

# BizTalk provider works only on 32bit
Require-32Bit

$scriptTime = [System.DateTime]::Now.ToString("yyyy-MM-dd HHmmss")
$kpPass = Read-Host -Prompt "Keepass Database password" -AsSecureString
$curLocation = Get-Location

Get-ScriptDirectory | Set-Location
Import-Module .\BizTalk-Common.psm1 -DisableNameChecking


$BizTalkHosts = Import-Csv -Path $ConfigurationFile -Delimiter "`t" -Encoding Unicode

$cred = $null

foreach ($BizTalkHost in $BizTalkHosts)
{
    # Create the host
    $newHost = Create-BizTalkHost -hostName $BizTalkHost.HostName `
     -hostType $BizTalkHost.HostType `
     -ntGroupName $BizTalkHost.GroupName `
     -authTrusted ([System.Convert]::ToBoolean( $BizTalkHost.AuthTrusted)) `
     -isTrackingHost ([System.Convert]::ToBoolean($BizTalkHost.IsTrackingHost)) `
     -is32BitOnly ([System.Convert]::ToBoolean( $BizTalkHost.Is32BitOnly)) `
     -MessagingMaxReceiveInterval ([System.Convert]::ToInt32($BizTalkHost.MessagingMaxReceiveInterval)) `
     -XlangMaxReceiveInterval ([System.Convert]::ToInt32($BizTalkHost.XlangMaxReceiveInterval))
     if ($newHost -ne $null)
     {
        # Split Instance servers and create instaces
        $Servers = @($BizTalkHost.InstanceServer.Split('|'))

        foreach ($srv in $Servers)
        {
            $preventFromStarting = $false
            try
            {
                if ($srv.Contains("*"))
                {
                    $srv = $srv.Replace("*","")
                    $preventFromStarting = $true
                }
                if ($cred -eq $null -or $BizTalkHost.InstanceUser -ne $cred.Username)
                {     
                    $cred =  Get-HostCredential -kpDatabasePath $KeepassFile -kpPass $kpPass -userName $BizTalkHost.InstanceUser -entryPath $BizTalkHost.InstanceUserPwd
                }
                if ($preventFromStarting)
                {
                    $hi = Create-BizTalkHostInstance -hostName $BizTalkHost.HostName `
                    -serverName $srv `
                    -cred $cred -PreventFromStarting
                }
                else
                {
                    $hi = Create-BizTalkHostInstance -hostName $BizTalkHost.HostName `
                    -serverName $srv `
                    -cred $cred
                }
                
            }
            catch [System.Exception]
            {
                Write-Host "Failed: $_" -ForegroundColor Red
                exit 
            }
            finally 
            {
                if ($cred -eq $null)
                { 
                    Write-Host "Failed creating credential exit." -ForegroundColor Red
                    Set-Location $curLocation
                    exit 
                    
                }
            }


        }

        $rhandler = @($BizTalkHost.ReceiveHandler.Split('|'))
        $shandler = @($BizTalkHost.SendHandler.Split('|'))

        foreach ($rad in $rhandler)
        {
            if( -not [System.String]::IsNullOrWhiteSpace($rad))
            {  
                $h = Create-BizTalkAdapterHandler -hostName $BizTalkHost.HostName -adapter $rad -isSend $false
            }
        }
        foreach ($sad in $shandler)
        {
            if( -not [System.String]::IsNullOrWhiteSpace($sad))
            {  
                $def = $sad.StartsWith("*")
                $sad = $sad.Replace("*","")
                $h = Create-BizTalkAdapterHandler -hostName $BizTalkHost.HostName -adapter $sad -isSend $true -isDefault $def
            }
        }

     }

}

Set-Location $curLocation