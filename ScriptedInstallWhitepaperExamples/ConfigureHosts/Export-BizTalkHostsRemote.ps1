#
# The script is licensed "as-is." You bear the risk of using it. 
# The contributors give no express warranties, guarantees or conditions.
# Test it in safe environment and change it to fit your requirements.
#


function Get-ScriptDirectory
{
    $scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value
    return Split-Path $scriptInvocation.MyCommand.Path
}


function Get-SendAdaptersForHost ($HostName)
{
    $query = "SELECT AdapterName, IsDefault FROM MSBTS_SendHandler2 Where  (( HostName = '$HostName' ))"
    $alist = Get-WmiObject -ComputerName $remoteServer -Namespace $global:btsWmiNamespace -Query $query
    $sendAdapters = ""
    foreach ($item in $alist)
    {
        if ($item.IsDefault)
        {
            $sendAdapters = "*$($item.AdapterName)|$sendAdapters"
        }
        else
        {
            $sendAdapters = "$($item.AdapterName)|$sendAdapters"
        }    
    }
    if ($sendAdapters.Length -lt 2)
    {
        return ""
    }
    return $sendAdapters.Substring(0,$sendAdapters.Length -1)
}

function Get-ReceiveAdaptersForHost ($HostName)
{
    $query = "SELECT AdapterName FROM MSBTS_ReceiveHandler Where  (( HostName = '$HostName' ))"
    $alist = Get-WmiObject -ComputerName $remoteServer -Namespace $global:btsWmiNamespace -Query $query 
    $ReceiveAdapters = ""    
    foreach ($item in $alist)
    {
        $ReceiveAdapters = "$($item.AdapterName)|$ReceiveAdapters"
    }
    if ($ReceiveAdapters.Length -lt 2)
    {
        return ""
    }
    return $ReceiveAdapters.Substring(0,$ReceiveAdapters.Length -1)
}

function Get-InstancesForHost ($HostName)
{
    $query = "SELECT HostName, RunningServer FROM MSBTS_HostInstance Where  (( HostName = '$HostName' ))"
    $alist = Get-WmiObject -ComputerName $remoteServer -Namespace $global:btsWmiNamespace -Query $query
    $Instances =  ""    
    foreach ($item in $alist)
    {
        $Instances = "$($item.RunningServer)|$Instances"
    }
    if ($Instances.Length -lt 2)
    {
        return ""
    }
    return $Instances.Substring(0,$Instances.Length -1)
}

function Get-InstanceUser ($HostName)
{
    $query = "SELECT HostName, RunningServer,Logon FROM MSBTS_HostInstance Where  (( HostName = '$HostName' ))"
    $alist = @(Get-WmiObject -ComputerName $remoteServer -Namespace $global:btsWmiNamespace -Query $query)

    if ($alist.Count -eq 0 )
    {
        return ""
    }
    return $alist[0].Logon
}

#######################################
# Main code
#######################################

$scriptTime = [System.DateTime]::Now.ToString("yyyy-MM-dd HHmmss")


$remoteServer = $env:COMPUTERNAME

Get-ScriptDirectory | Set-Location
Import-Module .\BizTalk-Common.psm1 -DisableNameChecking

$filename =".\$scriptTime.csv"
$myHosts = Get-BizTalkHosts
foreach ($h in $myHosts)
{
 
    $instanceUser = Get-InstanceUser -HostName $h.Name
    $inst =  Get-InstancesForHost -HostName $h.Name
    $sendhandlers = Get-SendAdaptersForHost -HostName $h.Name
    $receivehandlers = Get-ReceiveAdaptersForHost -HostName $h.Name


    $ho = [pscustomobject]@{ 'HostName' = $h.Name 
             'HostType' = $h.HostType 
             'GroupName' = $h.NtGroupName
             'AuthTrusted' = $h.AuthTrusted 
             'IsTrackingHost' = $h.HostTracking
             'Is32BitOnly' = $h.Is32BitOnly
             'MessagingMaxReceiveInterval' = $h.MessagingMaxReceiveInterval
             'XlangMaxReceiveInterval'= $h.XlangMaxReceiveInterval
             'InstanceServer' = "$inst"
             'InstanceUser'	= "$instanceUser"
             'InstanceUserPwd'	= "$instanceUser"
             'ReceiveHandler' = $receivehandlers	
             'SendHandler' = $sendhandlers 
            }
    Export-Csv -InputObject $ho -Path $filename -Append -Delimiter "`t" -Encoding Unicode -NoTypeInformation  

}
