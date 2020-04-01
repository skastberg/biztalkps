#############################################################
# This function will create a new BizTalk Host Instance
#############################################################
function Create-BizTalkHostInstance(
	[string]$hostName,
	[string]$serverName,
    $cred,
    [switch]$preventFromStarting,
    [switch]$isGmsaAccount
)
{
    $instance = Get-BizTalkHostInstances -hostfilter $hostName -btsserver $serverName -filterMode Equals
    if ($instance -ne $null)
    {
        Write-Warning "$hostName host instance on server $Server could not be created: Existing"
        return $instance
    }
    try
    {
        Write-Host "Creating host instances for $hostName" -ForegroundColor Green

        $hostinstanceName = "Microsoft BizTalk Server $hostName $serverName"
        $hostobject = ([WMICLASS]"root\MicrosoftBizTalkServer:MSBTS_ServerHost").CreateInstance()
        $hostobject.ServerName = $serverName
        $hostobject.HostName = $hostName
        $hostobject.Map()
        $instance = ([WMICLASS]"root\MicrosoftBizTalkServer:MSBTS_HostInstance").CreateInstance()
        $instance.Name = $hostinstanceName
        if ($preventFromStarting)
        {
            $instance.IsDisabled = $true
        }
        if ($isGmsaAccount)
        {
            $instance.Install( $cred.UserName , $null, $preventFromStarting, $true) 
        }
        else
        {
            $pass 
            $instance.Install( $cred.UserName , $cred.GetNetworkCredential().password, $preventFromStarting, $false) 
        }
        
		Write-Host "HostInstance $hostName was mapped and installed successfully. Mapping created between Host: $hostName and Server: $serverName);" -Fore Green
    }
    catch [System.Management.Automation.RuntimeException]
    {
		if ($_.Exception.Message.Contains("Another object with the same key properties already exists.") -eq $true)
        {
			Write-Host "Create-BizTalkHostInstance: $hostName host instance can't be created because another object with the same key properties already exists." -ForegroundColor Red 
        }
		else{
        	write-Host "Create-BizTalkHostInstance: $hostName host instance on server $Server could not be created: $_.Exception.Message" -ForegroundColor Red
		}
    }
    finally
    {
        
    }
}





Create-BizTalkHostInstance -hostName "Testing" -serverName sk2020dev -cred $cred -preventFromStarting 