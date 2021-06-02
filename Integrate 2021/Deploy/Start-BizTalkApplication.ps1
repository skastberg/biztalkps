#
# The script is licensed "as-is." You bear the risk of using it. 
# The contributors give no express warranties, guarantees or conditions.
# Test it in safe environment and change it to fit your requirements.
#
#Requires -RunAsAdministrator

param(
    [parameter(Mandatory = $true)][string]$ApplicationName
    )



function Log-ProcessStep ($message, [ValidateSet('Information','Warning','Error')]$level )
{
    $timestamp = [System.DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
    switch ($level)
    {
        'Warning' 
        {
            #Write-Host "$timestamp $message" -ForegroundColor DarkYellow
            Write-Host "##vso[task.logissue type=warning;]$message"
        }
        'Error' 
        {
            #Write-Host "$timestamp $message" -ForegroundColor Red
            Write-Host "##vso[task.logissue type=error;]$message"
            Exit 1
        }
        Default 
        {
            #Write-Host "$timestamp $message" -ForegroundColor Gray
            Write-Host "$message"

        }
    }

}

function Invoke-SelfIn32BitProcess ($scriptPath, $parameters)
{
    if ($env:Processor_Architecture -ne "x86")   
    { 
        &"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noninteractive -noprofile -file $scriptPath  @parameters
        exit
    }    
}



#######################################
# Main code
#######################################

Invoke-SelfIn32BitProcess -scriptPath $myinvocation.Mycommand.path -parameters $PSBoundParameters

Import-Module $PSScriptRoot\BizTalk-Common.psm1 -DisableNameChecking
Register-BtsSnapin 

if ($env:BTS_SRV_MODE.ToLower() -eq "primary") {
    Write-Host "Primary server sleeping 20 seconds"
    Start-Sleep -Seconds 20
    Write-Host "Primary server starting $ApplicationName"
    Start-Application -StartOption StartAll -Path "BizTalk:\Applications\$ApplicationName"    
}




