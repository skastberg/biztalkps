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
    # FailOnApplicationPresent
    [Parameter(Mandatory=$false, Position=3)][switch]$FailOnApplicationPresent,
    # FailOnApplicationBackreference
    [Parameter(Mandatory=$false, Position=4)][switch]$FailOnApplicationBackreference
)

function Test-BizTalkApplicationHasActiveInstances
{
    [OutputType([boolean])]
    Param
    (
        # BaseUrl to the BizTalk management REST API 
        [Parameter(Mandatory=$true,
                   Position=0)]
        [string] $BaseUrl,

        # ApplicationName, name of the application to retrieve
        [Parameter(Mandatory=$true,
                   Position=1)]
        [string]$ApplicationName
    )

    $result = Invoke-BizTalkServices -Url "$BaseUrl/Instances?`$filter=Properties/Application eq '$ApplicationName'&`$top=1"
    if ($null -eq $result)
    {
        Write-Host "##vso[task.logissue type=error;]Test-BizTalkApplicationHasActiveInstances failed request."
        return $true
    }
    return $result.value.Count -gt 0
}


#############################################

Import-Module -Name $PSScriptRoot\BtsUtils.psm1 -DisableNameChecking
Set-AcceptAllCerts

$fail = $false

$Application = Get-BizTalkApplication -BaseUrl $BaseUrlMgmt -ApplicationName $ApplicationName
if ( $FailOnApplicationPresent -and $null -ne $Application)
{
    $fail = $true
    Write-Host "##vso[task.logissue type=error;]$ApplicationName exist."
}

if ($null -ne $Application) 
{
    $HasInstances = Test-BizTalkApplicationHasActiveInstances -BaseUrl $BaseUrlOds  -ApplicationName $ApplicationName
    if ($HasInstances)
    {
        $fail = $true
        Write-Host "##vso[task.logissue type=error;]$ApplicationName has instances."
    }
}

if ( $FailOnApplicationBackreference -and $null -ne $Application)
{
    if ( 0 -lt $Application.ApplicationBackReferences.Count) {
        $fail = $true
        Write-Host "##vso[task.logissue type=error;]$ApplicationName has back references."
    }
}


if ($fail) {
    exit 1
}