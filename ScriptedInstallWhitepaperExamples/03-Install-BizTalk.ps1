#Requires -RunAsAdministrator


################################################################


function Install-BizTalk ($mediaLib, $fullPathToConfig, $logFullname)
{
    $fullPathToBTS = "$mediaLib\BizTalk Server\setup.exe" 
   

    if ((Test-Path -Path $fullPathToBTS) -eq $false ) 
    {
        Log-SetupStep -message "Did not find $fullPathToBTS. Exit!" -level Error
        Exit
    }
    if ((Test-Path -Path $fullPathToConfig) -eq $false ) 
    {
        Log-SetupStep -message "Did not find $fullPathToConfig. Exit!"  -level Error
        Exit
    }


    Log-SetupStep -message "Installing BizTalk '$fullPathToBTS'"
    Start-Process -FilePath $fullPathToBTS -ArgumentList "/S $fullPathToConfig /norestart /l $logFullname /companyname CONTOSO /username CONTOSO" -Wait
    # Get the updated Env variables to check that setup did not rollback
    $updatedEnv = [Environment]::GetEnvironmentVariables("Machine") 
    
    if ($updatedEnv.ContainsKey("BTSINSTALLPATH"))
    {
        Log-SetupStep -message "Installation av BizTalk Binaries Done" -level Information   
    }
    else
    {
        Log-SetupStep -message "Installation av BizTalk Binaries Failed, review '$logFullname' for details." -level Error
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
$btsMedia = "D:\"



Install-BizTalk -mediaLib $btsMedia -fullPathToConfig "$scriptfolder\Config\Features.xml"  -logFullname "$scriptfolder\Install-BizTalk_$timestamp.log"



