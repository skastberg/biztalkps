param(
	[parameter(Mandatory = $true)][string]$pathToTokensFile,
    [parameter(Mandatory = $false)][string]$pathToKeepassFile,
    [parameter(Mandatory = $false)][string]$pathToConfigFile
    )
#Requires -RunAsAdministrator


################################################################



<#
.Synopsis
   Installs BizTalkFactory.PowerShell.Extensions.dll so the provider can be loaded and used.
.DESCRIPTION
   Installs BizTalkFactory.PowerShell.Extensions.dll so the provider can be loaded and used.
.EXAMPLE
   Register-BtsPowershellExtensions
#>
function Register-BtsPowershellExtensions
{
    $btspath = $env:BTSINSTALLPATH
    $pspath = "$btspath\SDK\Utilities\PowerShell"
    Log-SetupStep -message  "Starting Register-BtsPowershellExtensions" -level Information
    if (Test-Path -Path $pspath) 
    {
        
        $instalUtil = $env:windir + "\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe"
        $extpath =  "`"$pspath\BizTalkFactory.PowerShell.Extensions.dll`""
        . $instalUtil  $extpath 
        
    }
    else
    {
        Log-SetupStep -message  "Did not find PowerShell Extensions at '$pspath'." -level Error
    }
    Log-SetupStep -message  "Ending Register-BtsPowershellExtensions" -level Information
}

function Resolve-Secrets ($configurations, $pathToDatabase)
{
    Log-SetupStep -message  "Starting Resolve-Secrets '$pathToDatabase'" -level Information
    Import-Module PoShKeePass
    $mkey = Read-Host -Prompt "MasterKey for '$pathToDatabase'" -AsSecureString


    $kpconfig = Get-KeePassDatabaseConfiguration -DatabaseProfileName MasterKeyDB  
    if ($kpconfig.DatabasePath -ne $pathToDatabase)
    {
        # Removes the configuration from the xml configuration file just in case
        Remove-KeePassDatabaseConfiguration -DatabaseProfileName 'MasterKeyDB' -Confirm:$false
    }

    if ($kpconfig -eq $null)
    {
        $kpconfig = New-KeePassDatabaseConfiguration -DatabaseProfileName 'MasterKeyDB' -DatabasePath $pathToDatabase -UseMasterKey 
    }
    foreach ($item in $configurations)
    {
        if ($item.Value.StartsWith('$$'))
        {
            
            $key = [System.IO.Path]::GetFileName($item.Value)    
            $group =  [System.IO.Path]::GetDirectoryName($item.Value).Replace('$$','').Replace('\', '/')

            $ent = Get-KeePassEntry -Title $key -KeePassEntryGroupPath $group -MasterKey $mkey -DatabaseProfileName MasterKeyDB 
            $SecurePassword = $ent.Password
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
            $item.Value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        }
    }

    Log-SetupStep -message  "Ending Resolve-Secrets" -level Information
}

function Replace-Tokens($configurations,[string]$contents,[string]$timestamp, $pathToDatabase)
{
    Log-SetupStep -message  "Starting Replace-Tokens" -level Information
    foreach ($item in $configurations)
    {
        $contents = $contents.Replace("%%$($item.Token)%%", $item.Value).Replace('@TimeStamp@',$timestamp)
    }
    return $contents
    Log-SetupStep -message  "Ending Replace-Tokens" -level Information

}


function Create-ConfigurationFile($configurations, [string]$pathToKeepassFile, [string]$pathToConfigFile, [string]$tempConfigFile, [string]$timestamp)
{
    Log-SetupStep -message  "Starting Create-ConfigurationFiles" -level Information
    Resolve-Secrets -configurations $configs -pathToDatabase $pathToKeepassFile

    $configContent = Get-Content -Path $pathToConfigFile -Encoding UTF8
    $cfg = Replace-Tokens -configurations $configs -contents $configContent -timestamp $timestamp
    $cfg | Set-Content -Path $tempConfigFile -Encoding UTF8
    Log-SetupStep -message  "Ending Create-ConfigurationFiles" -level Information

}

function Update-Environment {
# Credits Joey
# https://stackoverflow.com/questions/14381650/how-to-update-windows-powershell-session-environment-variables-from-registry
# Adapted to skip PROCESSOR_ARCHITECTURE that was changed.
    $locations = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
                 'HKCU:\Environment'

    $locations | ForEach-Object {
        $k = Get-Item $_
        $k.GetValueNames() | ForEach-Object {
            $name  = $_
            $value = $k.GetValue($_)

            if ($userLocation -and $name -ieq 'PATH') {
                $Env:Path += ";$value"
            } else {
                if ($name -ne "PROCESSOR_ARCHITECTURE")
                {
                    Set-Item -Path Env:${name} -Value $value
                }                
            }
        }

        $userLocation = $true
    }
}

function Configure-BizTalk ($destinationConfig,$installLog )
{
    Log-SetupStep -message  "Starting Configure-BizTalk" -level Information
    $program = "$env:BTSINSTALLPATH\Configuration.exe"

    $arguments = "/S `"$destinationConfig`" /L `"$installLog`""
    $p = Start-Process -FilePath "$program" -ArgumentList "$arguments" -Wait -PassThru -Verb runAs
    if ($p.ExitCode -ne 0)
    {
        Log-SetupStep -message  "Failed Configure-BizTalk" -level Error
        return $false
    }
    Log-SetupStep -message  "Ending Configure-BizTalk" -level Information
    return $true
}







function Set-DTAPurge ($configurations)
{

    Push-Location; Import-Module SQLPs -DisableNameChecking; Pop-Location;
    $DtaServer = $configurations | Where-Object { $_.Token -eq  "BizTalkDTADb-Server" } | Select-Object -First 1
    $DtaDb = $configurations | Where-Object { $_.Token -eq  "BizTalkDTADb-Database" } | Select-Object -First 1
    $SQLServer = $DtaServer.Value
    $DTADatabaseName = $DtaDb.Value
    if ($SQLServer.Contains("\") -eq $false)
    {
        $SQLServer = "$SQLServer\DEFAULT"    
    }    
    $SQLProviderLocation = "SQLSERVER:\SQL\${SQLServer}\JobServer\Jobs"

    # Get all of the job steps and hold the output in the $JobSteps object

    $JobSteps = Get-ChildItem -Path $SQLProviderLocation | ForEach-Object {$_.enumjobstepsbyid()} | Where-Object { ($_.SubSystem -eq "TransactSql") -and ($_.Parent.Name -eq "DTA Purge and Archive ($DTADatabaseName)") }

    foreach ($Step in $JobSteps) {
        # Refresh to ensure the latest code is in the command
        $Step.Refresh()
        $Step.Command = "DECLARE @RC int`r`nDECLARE @nHours tinyint = 0`r`nDECLARE @nDays tinyint = 5`r`nDECLARE @nHardDays tinyint = 15`r`nDECLARE @dtLastBackup datetime = GETDATE()`r`nDECLARE @fHardDeleteRunningInstances int = 1`r`n`r`nEXECUTE @RC = [dbo].[dtasp_PurgeTrackingDatabase] `r`n   @nHours`r`n  ,@nDays`r`n  ,@nHardDays`r`n  ,@dtLastBackup`r`n  ,@fHardDeleteRunningInstances"
        $Step.Parent.IsEnabled = $true
        $Step.Alter()
        $Step.Parent.Alter()
 
    }
}

function Set-BackupFolder ($configurations)
{

    Push-Location; Import-Module SQLPs -DisableNameChecking; Pop-Location;
    $MgmtServer = $configurations | Where-Object { $_.Token -eq  "BizTalkMgmtDb-Server" } | Select-Object -First 1
    $MgmtDb = $configurations | Where-Object { $_.Token -eq  "BizTalkMgmtDb-Database" } | Select-Object -First 1
    $BackupFolder = $configurations | Where-Object { $_.Token -eq  "BACKUP_FOLDER" } | Select-Object -First 1
    $SQLServer = $MgmtServer.Value
    $BackupFolderName = $BackupFolder.Value
    $MgmtDbName = $MgmtDb.Value

    if ($SQLServer.Contains("\") -eq $false)
    {
        $SQLServer = "$SQLServer\DEFAULT"    
    }    
    $SQLProviderLocation = "SQLSERVER:\SQL\${SQLServer}\JobServer\Jobs"

    # Get all of the job steps and hold the output in the $JobSteps object

    $JobSteps = Get-ChildItem -Path $SQLProviderLocation | ForEach-Object {$_.enumjobstepsbyid()} | Where-Object { ($_.SubSystem -eq "TransactSql") -and ($_.Parent.Name -eq "Backup BizTalk Server ($MgmtDbName)") }

    foreach ($Step in $JobSteps) {
        # Refresh to ensure the latest code is in the command
        $Step.Refresh()
        $Step.Command = $Step.Command.Replace("'<destination path>'", "'$BackupFolderName'")
        $Step.Parent.IsEnabled = $true
        $Step.Alter()
        $Step.Parent.Alter()
 
    }
}






################################################################
# Maincode
################################################################ 

$scriptfolder = [System.IO.Path]::GetDirectoryName( $MyInvocation.InvocationName)
if ($scriptfolder -eq ".")
{
    $currLocation = Get-Location 
    $scriptfolder = $currLocation.Path
}
else
{
    Set-Location $scriptfolder
}

Import-Module "$scriptfolder\BtsSetupHelper.psm1" -Global -DisableNameChecking
Check-32Bit

Update-Environment
Register-BtsPowershellExtensions 

$timestamp = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
$tempConfigFile = "$scriptfolder\$timestamp-config.xml"
$logFile = "$scriptfolder\$timestamp-config.log"



$configs = Load-ConfigFile -fullPathToFile $pathToTokensFile -exitOnError
Create-ConfigurationFile -configurations $configs -pathToKeepassFile $pathToKeepassFile -pathToConfigFile $pathToConfigFile -tempConfigFile $tempConfigFile -timestamp $timestamp

#$result = Configure-BizTalk -destinationConfig $tempConfigFile -installLog $logFile 

Log-SetupStep -message "Note that '$tempConfigFile' contains passwords!" -level Warning
if (Prompt-YesNo -title "Delete Config file?" -message "Do you want to delete '$tempConfigFile'?" -yesText "Yes" -noText "no")
{
    Log-SetupStep -message "Deleting '$tempConfigFile'" -level Information
    Remove-Item -Path $tempConfigFile
    Log-SetupStep -message "Removed '$tempConfigFile'" -level Information
}

Set-DTAPurge -configurations $configs
Set-BackupFolder -configurations $configs


