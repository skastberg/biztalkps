function Invoke-BizTalkServices
{
    Param
    (
        [Parameter(Mandatory=$true,
                   Position=0)]
        [string] $Url,
        # Ignore404
        [Parameter(Mandatory=$false, Position=1)][switch]$Ignore404
    )

    try
    {
        $Response = Invoke-RestMethod -Uri "$Url" -Method Get -UseDefaultCredentials -UseBasicParsing 
        return $Response
    }
    catch [System.Net.WebException]
    {
        $t =$_ 
        if ($t.Exception.Response.StatusCode -eq "NotFound" -and $Ignore404)
        {
            return $null
        }
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
    return $null
}

function Exit-ScriptIfNotPrimary()
{
    $nodeText = "Target '$($env:COMPUTERNAME)' is configured as '$($env:BTS_SRV_MODE)' node"
    if ( 'primary' -eq $env:BTS_SRV_MODE.ToLower()) {
        Write-Host "$nodeText continue."
    }
    else {
        Write-Host "$nodeText exit with success."
        Exit 0
    }
}

function Set-AcceptAllCerts {
    # Added to accept https with self signed certs. Not intended for production. --------
    # ----------------------------------------------------------------------------------------
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    # ----------------------------------------------------------------------------------------
    
}



function Get-BizTalkApplication
{
    Param
    (
        # BaseUrl to the BizTalk management REST API 
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string] $BaseUrl,

        # ApplicationName, name of the application to retrieve
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]$ApplicationName
    )
    
    $result = Invoke-BizTalkServices -Url "$BaseUrl/Applications/$ApplicationName" -Ignore404
    if ($null -eq $result)
    {
        Write-Host "$ApplicationName not found"
        #    Write-Host "##vso[task.logissue type=error;]Get-BizTalkApplication failed request."
    }
    else {
        Write-Host "$ApplicationName found"
    }
    return $result
}
