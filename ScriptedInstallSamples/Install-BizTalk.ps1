#Requires -RunAsAdministrator


################################################################


function Install-BizTalk ($mediaLib, $logFullname)
{
    $fullPathToBTS = "$mediaLib\BizTalk Server\setup.exe" 
    $fullPathToConfig = "$mediaLib\Config\Features.xml"
    $FullPathToCab = "$mediaLib\Prereq\BtsRedistW2K12R2EN64.CAB"
    

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
    if ((Test-Path -Path $FullPathToCab) -eq $false ) 
    {
        Log-SetupStep -message "Did not find $FullPathToCab. Exit!"  -level Error
        Exit
    }

    Log-SetupStep -message "Installing BizTalk '$fullPathToBTS'"
    Start-Process -FilePath $fullPathToBTS -ArgumentList "/S $fullPathToConfig /CABPATH `"$FullPathToCab`" /norestart /l $logFullname /companyname CONTOSO /username CONTOSO" -Wait
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


function Install-AdapterPack ( [string]$mediaLib, [switch]$Install32Bit,[switch]$Install64Bit,[switch]$UseProductionSettings)
{
    # $installationroot should be the folder where the server media is located i.e. X:\BizTalk Server
    $installationRoot = "$mediaLib\BizTalk Server"
    
    if ($Install64Bit)
    {
        Log-SetupStep -message "Installing Adapter framework SDK 64"
        $sdk64 = "$installationRoot\ASDK_x64"
        $cmd = "$sdk64\AdapterFramework64.msi"

        if (-not (Test-Path -Path $cmd))
        {
            Log-SetupStep -message "Did not install Adapter framework SDK 64, Did not find $cmd"  -level Error
        }
        else
        {
            # MUOPTIN=”No” = don't check for updates
            if ($UseProductionSettings)
            {
                Start-Process -FilePath "$cmd" -ArgumentList "/quiet MUOPTIN=`”No`”" -Wait  
            }
            else
            {
                # Will add tools and samples
                Start-Process -FilePath "$cmd" -ArgumentList "/quiet addlocal=all MUOPTIN=`”No`”" -Wait 
            }
             

        }

    
        Log-SetupStep -message "Installing Adapter pack 64"
        $apack64 = "$installationRoot\AdapterPack_x64"
        $cmd = "$apack64\AdaptersSetup64.msi"
        # Install only WCF-SQL, https://docs.microsoft.com/en-us/biztalk/adapters-and-accelerators/install-biztalk-adapter-pack-2013-r2-and-2013#installing-the-biztalk-adapter-pack-in-silent-mode 
        if (-not (Test-Path -Path $cmd))
        {
            Log-SetupStep -message "Did not install Adapter pack 64, Did not find $cmd"  -level Error
        }
        else
        {
            Start-Process -FilePath "$cmd" -ArgumentList "/qn ADDLOCAL=SqlFeature CEIP_OPTIN=false" -Wait 
        }
        Log-SetupStep -message "Adapter pack 64 bit Done" -level Information
    }
    
    if ($Install32Bit)
    {
        Log-SetupStep -message "Installing Adapter framework SDK 32"
        $sdk32 = "$installationRoot\ASDK_x86"
        $cmd = "$sdk32\AdapterFramework.msi"
        if (-not (Test-Path -Path $cmd))
        {
            Log-SetupStep -message "Did not install Adapter framework SDK 32, Did not find $cmd"  -level Error
        }
        else
        {
            # MUOPTIN=”No” = don't check for updates
            if ($UseProductionSettings)
            {
                Start-Process -FilePath "$cmd" -ArgumentList "/quiet MUOPTIN=`”No`”" -Wait  
            }
            else
            {
                # Will add tools and samples
                Start-Process -FilePath "$cmd" -ArgumentList "/quiet addlocal=all MUOPTIN=`”No`”" -Wait 
            }      
        }
        Log-SetupStep -message "Installing Adapter pack 32" -level Information
        $apack32 = "$installationRoot\AdapterPack_x86"
        $cmd = "$apack32\AdaptersSetup.msi"
        if (-not (Test-Path -Path $cmd))
        {
            Log-SetupStep -message "Did not install Adapter pack 32, Did not find $cmd"  -level Error
        }
        else
        {
            # Install only WCF-SQL, https://docs.microsoft.com/en-us/biztalk/adapters-and-accelerators/install-biztalk-adapter-pack-2013-r2-and-2013#installing-the-biztalk-adapter-pack-in-silent-mode 
            Start-Process -FilePath "$cmd" -ArgumentList "/qn ADDLOCAL=SqlFeature CEIP_OPTIN=false" -Wait 
        }
        Log-SetupStep -message "Adapter pack 32 Done" -level Information
    }
}


function Install-CU ($mediaLib,$logFullname)
{
    $cuLib = "$mediaLib\FeaturePack"
    $fullPathToCu = $null
    if (-not (Test-Path -Path $cuLib))
    {
            Log-SetupStep -message "Did not install any CU, Did not find $cuLib"  -level Error
            return
    }
    else
    {
        # Get the latest CU
        $fullPathToCu = Get-ChildItem "$cuLib\*.exe" | Sort-Object -Property Name -Descending | Select-Object -first 1
    }
    if ($fullPathToCu -ne $null)
    {
        Log-SetupStep -message "Installing CU '$fullPathToCu'" -level Information
        Start-Process -FilePath $fullPathToCu -ArgumentList "/quiet /s /w /norestart /log $logFullname" -Wait
        Log-SetupStep -message "Installed CU '$fullPathToCu'"  -level Information      
    }
    else
    {
        Log-SetupStep -message "Did not find any CU to install."  -level Error
        
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



Install-BizTalk -mediaLib $btsMedia   -logFullname "$scriptfolder\Install-BizTalk_$timestamp.log"
Install-AdapterPack -mediaLib $btsMedia -Install32Bit -Install64Bit
Install-CU -mediaLib $btsMedia -logFullname  "$scriptfolder\Install-CU_$timestamp.log"

