Param
(
    # BaseUrl to the BizTalk management REST API 
    [Parameter(Mandatory=$true,
                Position=0)]
    [string] $BaseUrlMgmt,
        # BaseUrl to the BizTalk OperationalDataService oData endpoint 
        [Parameter(Mandatory=$true,
        Position=1 )]
        [string] $BaseUrlOds,

    # ApplicationName, name of the application to retrieve
    [Parameter(Mandatory=$true,
                Position=2)]
    [string]$ApplicationName,
    # DeleteAppIfExists
    [Parameter(Mandatory=$false, Position=3)][switch]$DeleteAppIfExists,

    # ApplicationReferences, a string array with the applications the new application should reference
    [Parameter(Mandatory=$false, Position=4)]
 [string[]]$ApplicationReferences = @("BizTalk.System")
)


<#
.Synopsis
   Creates a new BizTalk Application
.DESCRIPTION
   Calls the BaseUrl to create a new BizTalk Application. If the call fails $null is returned if successful the new application is returned
.EXAMPLE
   Add-BizTalkApplication -BaseUrl $url -ApplicationName Test -Description "My test application" 
.PARAMETER BaseUrl
BaseUrl to the BizTalk management REST API 
.PARAMETER ApplicationName
Name of the application to create
.PARAMETER Description
A description for the application
.PARAMETER IsDefaultApplication
A boolean telling if the new application is intended to be the default application in the group. Default value is $false
.PARAMETER ApplicationReferences 
A string array with the applications the new application should reference
#>
function Add-BizTalkApplication
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # BaseUrl to the BizTalk management REST API 
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string] $BaseUrl,

        # ApplicationName Name of the new application
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$ApplicationName
        ,

        # Description, a description for the application
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [string]$Description
        ,

        # IsDefaultApplication, a boolean telling if the new application is intended to be the default application in the group. Default value is $false
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=3)]
        [string]$IsDefaultApplication = $false
        ,

        # ApplicationReferences, a string array with the applications the new application should reference
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=4)]
        [string[]]$ApplicationReferences = @("BizTalk.System")
    )

    Process
    {
        $app = $null

        try
        {
            # Create a custom object with the application properties
            $object = [pscustomobject]@{
                Name = $ApplicationName
                Description = $Description
                IsDefaultApplication = $IsDefaultApplication
                ApplicationReferences = $ApplicationReferences
            }
            $appBody = $object | ConvertTo-Json
            
            $app = Invoke-RestMethod -Uri "$BaseUrl/Applications" -Method Post -Body $appBody -UseDefaultCredentials -ContentType "application/json"

            # Get the create application
            $app = Get-BizTalkApplication -BaseUrl $BaseUrl -ApplicationName $ApplicationName
        }
        catch [System.Net.WebException],[System.Exception]
        {
            Write-Warning $_
        }
        return $app
    }
}

<#
.Synopsis
   Deletes a BizTalk Application
.DESCRIPTION
   Calls the BaseUrl to Delete a specific BizTalk Application. 
.EXAMPLE
   Remove-BizTalkApplication -BaseUrl $url -ApplicationName "BizTalk Application 1"
.PARAMETER BaseUrl
BaseUrl to the BizTalk management REST API 
.PARAMETER ApplicationName
Name of the application to delete
#>
function Remove-BizTalkApplication
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # BaseUrl to the BizTalk management REST API 
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string] $BaseUrl,

        # ApplicationName, name of the application to delete
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$ApplicationName
    )

    Process
    {
       
        try
        {
            $result = Invoke-RestMethod -Uri "$BaseUrl/Applications/$ApplicationName" -Method Delete -UseDefaultCredentials
        }
        catch [System.Net.WebException]
        {
            $raisedException = $_
            $errorMessage = "$($raisedException.Exception.Message) `r`nResponseUri: '$($raisedException.Exception.Response.ResponseUri)'.`r`n$($raisedException.ScriptStackTrace)"
            Write-Error ($errorMessage)
            Write-Host "##vso[task.logissue type=error;]$errorMessage"
            Exit 1
        }
        catch [System.Exception]
        {
            Write-Error ($Error[0])
            Write-Host "##vso[task.logissue type=error;]$Error[0]"
            Exit 1
        }      
        finally
        {
            
        }
    }
}


#############################################

Import-Module -Name $PSScriptRoot\BtsUtils.psm1 -DisableNameChecking
Set-AcceptAllCerts
Exit-ScriptIfNotPrimary
$fail = $false

$Application = Get-BizTalkApplication -BaseUrl $BaseUrlMgmt -ApplicationName $ApplicationName 
if ( $DeleteAppIfExists -and $null -ne $Application)
{
    Write-Host "$ApplicationName exist will be deleted."
    Remove-BizTalkApplication -BaseUrl $BaseUrlMgmt -ApplicationName $ApplicationName 
    Write-Host "$ApplicationName existed, now deleted."
}

Write-Host "Creating $ApplicationName"

$desc = "DeployServer: $($env:COMPUTERNAME)`r`nRelease: $($env:BUILD_BUILDNUMBER)`r`nReleaseTime: $([System.DateTime]::Now.ToString("yyyy-MM-dd HH:mm"))"

$app = Add-BizTalkApplication -BaseUrl $BaseUrlMgmt -ApplicationName $ApplicationName -Description $desc -ApplicationReferences $ApplicationReferences
if ($null -eq $app ) {
    $fail = $true
    Write-Host "##vso[task.logissue type=error;]Failed creating $ApplicationName."
}

if ($fail) {
    exit 1
}