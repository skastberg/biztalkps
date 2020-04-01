
# Load types
$pathToInteropDll = "$($env:CommonProgramW6432)\Enterprise Single Sign-On\Microsoft.EnterpriseSingleSignOn.Interop.dll"
$t = Add-Type -Path $pathToInteropDll



<#
.Synopsis
   The Invoke-SSOBackupSecret function backs up the secret server.
.DESCRIPTION
   The BackupSecret function backs up the secret server.
.EXAMPLE
   Invoke-SSOBackupSecret -backupFile $tempfile -filePassword $pass -filePasswordReminder $reminder

#>
function Invoke-SSOBackupSecret
{
    Param
    (
        # String containing the path and name of the secret server backup file.
        [Parameter(Mandatory=$true,
                   Position=0)]
        [string]$backupFile,

        # String containing the backup file password.
        [Parameter(Mandatory=$true,
                   Position=1)]
        [string]$filePassword,
        # String containing the secret server file password reminder.
        [Parameter(Mandatory=$true,
                   Position=2)]
        [string]$filePasswordReminder
    )
    $ssoInt = New-Object -TypeName "Microsoft.EnterpriseSingleSignOn.Interop.SSOConfigOM" 
    $flags = [System.Reflection.BindingFlags]::InvokeMethod + [System.Reflection.BindingFlags]::Instance 
    [Microsoft.EnterpriseSingleSignOn.Interop.ISSOConfigSS].InvokeMember("BackupSecret",$flags, $null,$ssoInt,($backupFile,$filePassword,$filePasswordReminder))
    

}




<#
.Synopsis
   The Invoke-SSOGenerateSecret method generates the secret for the secret server.
.DESCRIPTION
   The Invoke-SSOGenerateSecret method generates the secret for the secret server.
.EXAMPLE
   Example of how to use this cmdlet

#>
function Invoke-SSOGenerateSecret
{
    Param
    (
        # String containing the path and name of the secret server backup file.
        [Parameter(Mandatory=$true,
                   Position=0)]
        [string]$backupFile,

        # String containing the backup file password.
        [Parameter(Mandatory=$true,
                   Position=1)]
        [string]$filePassword,
        # String containing the secret server file password reminder.
        [Parameter(Mandatory=$true,
                   Position=2)]
        [string]$filePasswordReminder
    )

    $ssoInt = New-Object -TypeName "Microsoft.EnterpriseSingleSignOn.Interop.SSOConfigOM" 
    $flags = [System.Reflection.BindingFlags]::InvokeMethod + [System.Reflection.BindingFlags]::Instance
    [Microsoft.EnterpriseSingleSignOn.Interop.ISSOConfigSS].InvokeMember("GenerateSecret",$flags, $null,$ssoInt,($backupFile,$filePassword,$filePasswordReminder))
   
}



<#
.Synopsis
   The Get-SSOFilePasswordReminder method gets the password reminder from the backup file.
.DESCRIPTION
   The Get-SSOFilePasswordReminder method gets the password reminder from the backup file.
.EXAMPLE
   Example of how to use this cmdlet

#>
function Get-SSOFilePasswordReminder
{
    Param
    (
        # The file from which the reminder is to be retrieved.
        [Parameter(Mandatory=$true,
                   Position=0)]
        [string]$restoreFile
    )

    Write-Host "Get-SSOFilePasswordReminder - not implemented yet!" -ForegroundColor Red

    return
    $ssoInt = New-Object -TypeName "Microsoft.EnterpriseSingleSignOn.Interop.SSOConfigOM" 
    $filePasswordReminder=""
    $flags = [System.Reflection.BindingFlags]::InvokeMethod 
    $s = [Microsoft.EnterpriseSingleSignOn.Interop.ISSOConfigSS].InvokeMember("GetFilePasswordReminder",$flags, $null,$ssoInt,($restoreFile,([ref]$filePasswordReminder)))
   
    
    return $filePasswordReminder
}


<#
.Synopsis
   The Invoke-SSORestoreSecret method restores master secrets from the password protected backup file.
.DESCRIPTION
   The Invoke-SSORestoreSecret method restores master secrets from the password protected backup file.
.EXAMPLE
   Example of how to use this cmdlet

#>
function Invoke-SSORestoreSecret
{
    Param
    (
        # The file from which the reminder is to be retrieved.
        [Parameter(Mandatory=$true,
                   Position=0)]
        [string]$restoreFile,
         # The password used to protect the restore file.
        [Parameter(Mandatory=$true,
                   Position=1)]
        [string]$filePassword
    )

    $ssoInt = New-Object -TypeName "Microsoft.EnterpriseSingleSignOn.Interop.SSOConfigOM" 
    $flags = [System.Reflection.BindingFlags]::InvokeMethod + [System.Reflection.BindingFlags]::Instance
    [Microsoft.EnterpriseSingleSignOn.Interop.ISSOConfigSS].InvokeMember("RestoreSecret",$flags, $null,$ssoInt,($restoreFile,$filePassword))
   

}

