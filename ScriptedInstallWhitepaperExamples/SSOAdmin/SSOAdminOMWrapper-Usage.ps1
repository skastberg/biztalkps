
#Requires -RunAsAdministrator
################################################################







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

Import-Module "$scriptfolder\SSOAdminOMWrapper.psm1" -Global -DisableNameChecking
###############

$tempfile = "$([System.IO.Path]::GetTempPath())$([System.IO.Path]::GetRandomFileName()).bak"
$pass = "MyPassword123"
$reminder = "MyReminder123"

# Backup the secret
Write-Host "Backing up Secret" -ForegroundColor Green
Invoke-SSOBackupSecret -backupFile $tempfile -filePassword $pass -filePasswordReminder $reminder
Write-Host "Saved $tempfile"

## Restore a backup of the Secret
Write-Host "Restore Secret $tempfile" -ForegroundColor Green
Invoke-SSORestoreSecret -restoreFile $tempfile -filePassword $pass

<#
## Generate a new Secret
Write-Host "Regenerating Secret" -ForegroundColor Yellow
$tempfile = "$([System.IO.Path]::GetTempPath())$([System.IO.Path]::GetRandomFileName()).bak"
Invoke-SSOGenerateSecret -backupFile $tempfile -filePassword $pass -filePasswordReminder $reminder
Write-Host "Saved $tempfile"


#>