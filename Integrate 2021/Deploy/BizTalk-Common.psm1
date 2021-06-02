#
# The script is licensed "as-is." You bear the risk of using it. 
# The contributors give no express warranties, guarantees or conditions.
# Test it in safe environment and change it to fit your requirements.
#
Write-Host "BizTalk-Common.psm1 v2.0.0"

#get Variables
$global:btsGroupSettings = $null
$global:btsWmiNamespace = "root\MicrosoftBizTalkServer"
$global:btsOMCatalog = $null


function Get-ScriptDirectory
{
    $scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value
    return Split-Path $scriptInvocation.MyCommand.Path
}

$scriptDir = Get-ScriptDirectory


<#
.Synopsis
   Returns Wmi Object representing the groups settings
.DESCRIPTION
   Returns Wmi Object representing the groups settings.
   Read more on resulting object https://msdn.microsoft.com/en-us/library/aa578341.aspx
.EXAMPLE
   Get-BtsGroupSettings
#>
function Get-BtsGroupSettings ()
{
    if ($global:btsGroupSettings -eq $null)
    {
        $global:btsGroupSettings = Get-WmiObject -Class MSBTS_groupsetting -Namespace $global:btsWmiNamespace
    }
    return $global:btsGroupSettings
    
}


<#
.Synopsis
   Returns ExplorerOM Object representing the group
.DESCRIPTION
   Returns ExplorerOM Object representing the group, if already loaded returns a cached version run Refresh method to update it.
   Read more on resulting object https://msdn.microsoft.com/en-us/library/microsoft.biztalk.explorerom.btscatalogexplorer.aspx
.EXAMPLE
   Get-BtsOmCatalog
#>
function Get-BtsOmCatalog()
{
    if ($global:btsOMCatalog -eq $null)
    {
        $gSettings = Get-BtsGroupSettings 
        $as = [Reflection.Assembly]::LoadWithpartialName("Microsoft.BizTalk.ExplorerOM")
        $database = $gSettings.MgmtDbName 
        $server = $gSettings.MgmtDbServerName
        $global:btsOMCatalog = New-Object Microsoft.BizTalk.ExplorerOM.BtsCatalogExplorer
        $global:btsOMCatalog.ConnectionString = "Application Name=BizTalk-Common;Server=$server;Database=$database;Integrated Security=true;Connect Timeout=30"
    }
    return $global:btsOMCatalog
}

<#
.Synopsis
   Loads the BizTalk PowerShell provider ("BizTalkFactory.PowerShell.Extensions") 
.DESCRIPTION
   Loads the BizTalk PowerShell provider ("BizTalkFactory.PowerShell.Extensions") if not loaded. It also ensures that the BizTalk: drive is present.
.EXAMPLE
   Register-BtsSnapin
#>
function Register-BtsSnapin
{
    
    $psprovider = Get-PSProvider |Where-Object { $_.Name -eq "BizTalk" -and $_.PSSnapIn.Name -eq  "BizTalkFactory.PowerShell.Extensions"} 
    if($psprovider -eq $null)
    {
        try
         {
            $InitializeDefaultBTSDrive = $false
            $snapin = Add-PSSnapin -Name "BizTalkFactory.PowerShell.Extensions"
            $bd = Add-BizTalkDrive

         }
         catch [System.Exception]
         { 
            Write-Host $_
            Throw $_
         }
    }
    else
    {
        $bd = Add-BizTalkDrive
    }
}


<#
.Synopsis
   Ensures that the BizTalk: drive is present.
.DESCRIPTION
   Ensures that the BizTalk: drive is present.
.EXAMPLE
   Add-BizTalkDrive
#>
function Add-BizTalkDrive 
{
    $grpSettings = Get-BtsGroupSettings
    if(Test-Path -Path "BizTalk:\")
    {
        Remove-PSDrive -Name BizTalk   
    }
    New-PSDrive -Name BizTalk -PSProvider BizTalk -Root BizTalk:\ -Instance $grpSettings.MgmtDbServerName -Database $grpSettings.MgmtDbName -Scope global
    
}

<#
.Synopsis
   Installs BizTalkFactory.PowerShell.Extensions.dll so the provider can be loaded and used.
.DESCRIPTION
   Installs BizTalkFactory.PowerShell.Extensions.dll so the provider can be loaded and used.
.EXAMPLE
   Register-BtsPowershellExtensions
#>
function Register-BtsPowershellExtensions
{
    $btspath = $env:BTSINSTALLPATH
    $pspath = "$btspath\SDK\Utilities\PowerShell"
    if (Test-Path -Path $pspath) 
    {
        $instalUtil = $env:windir + "\Microsoft.NET\Framework\v4.0.30319\InstallUtil.exe"
        $extpath =  "$pspath\BizTalkFactory.PowerShell.Extensions.dll"
        . $instalUtil  $extpath 
        
    }
    else
    {
        throw "Failed loading PowerShell Extensions. SDK not found."
    }
    
}

###############
# Commandelet like Get functions
###############

<#
.Synopsis
   Returns BizTalk Server Applications.
.DESCRIPTION
   Returns BizTalk Server Applications by default all if the switch parameter -ExcludeSystem is included in call System applications are excluded.
.EXAMPLE
   Get-BizTalkApplications -ExcludeSystem
.EXAMPLE
   Get-BizTalkApplications -ExcludeSystem
#>
Function Get-BizTalkApplications
{
Param
([switch]$ExcludeSystem)
    if ($ExcludeSystem)
    {
        $res = Get-ChildItem -Path BizTalk:\Applications | Where-Object { $_.IsSystem -eq $false }
    }
    else
    {
        $res = Get-ChildItem -Path BizTalk:\Applications
    }
	return $res
}

<#
.Synopsis
   Returns BizTalk Server hosts.
.DESCRIPTION
   Returns BizTalk Server Hosts by default all, if the filter parameter -Filter is included in call only hosts which contains the text specified are returned.
.EXAMPLE
   Get-BizTalkHosts
.EXAMPLE
   Get-BizTalkHosts -Filter "Track" -FilterMode Contains
#>
Function Get-BizTalkHosts
{
param (
[Parameter(Mandatory=$false,Position=0,HelpMessage="Specify a filter to only include hosts containing the filter text.")]
    [string]$filter ="*",
    [Parameter(Mandatory=$false,Position=1,HelpMessage="Specify how filter parameter will be used. When specifying All it will be ignored")]
    [ValidateSet("All", "Equals", "Contains")]
    [string]$filterMode ="All" )

    switch ($filterMode)
    {
        'Equals' {Get-ChildItem -Path "BizTalk:\Platform Settings\Hosts" | Where-Object { $_.Name -eq $filter  }}
        'Contains' { Get-ChildItem -Path "BizTalk:\Platform Settings\Hosts" | Where-Object { $_.Name.Contains($filter)  } }
        Default { Get-ChildItem -Path "BizTalk:\Platform Settings\Hosts"  }
    }

}

<#
.Synopsis
   Returns BizTalk Server host instances.
.DESCRIPTION
   Returns BizTalk Server host instances by default all, if the filter parameter -Filter is included in call only hostsnames which contains the text specified are returned.
.EXAMPLE
   Get-BizTalkHostInstances
.EXAMPLE
   Get-BizTalkHostInstances -Filter "Track"
#>
Function Get-BizTalkHostInstances
{
param ([Parameter(Mandatory=$false,Position=0,HelpMessage="Specify a filter to only include hostnames containing the filter text.")]
    [string]$hostfilter ="*",
    [Parameter(Mandatory=$false,Position=1,HelpMessage="Specify how filter parameter will be used. When specifying All it will be ignored")]
    [ValidateSet("All", "Equals", "Contains")]
    [string]$filterMode ="All",
    [Parameter(Mandatory=$false,Position=2,HelpMessage="Specify a BizTalk Server name.")]
    [string]$btsserver =""
     
     )

        switch ($filterMode)
    {
        'Equals' {$instances = Get-ChildItem -Path "BizTalk:\Platform Settings\Host Instances" | Where-Object { $_.HostName -eq $hostfilter  }}
        'Contains' { $instances = Get-ChildItem -Path "BizTalk:\Platform Settings\Host Instances" | Where-Object { $_.HostName.Contains($filter)  } }
        Default { $instances = Get-ChildItem -Path "BizTalk:\Platform Settings\Host Instances"}
    }


    if ($instances -ne $null -and $btsserver -ne "")
    {
        $instances = $instances | Where-Object { $_.RunningServer -eq $btsserver }  
    }
    return $instances
}


<#
.Synopsis
   Returns BizTalk Server Adapter handler.
.DESCRIPTION
    Returns BizTalk Server Adapter handler.
.EXAMPLE
   BizTalkAdapterHandler
.EXAMPLE
   BizTalkAdapterHandler -Filter "ReceiveHost"
#>
Function Get-BizTalkAdapterHandler
{
param ([Parameter(Mandatory=$true,Position=0,HelpMessage="Specify an adapter to get handlers for.")]
    [string]$adapter,
    [Parameter(Mandatory=$false,Position=1,HelpMessage="Specify a direction.")]
    [ValidateSet("Send", "Receive")]
    [string]$direction
     
     )
	
    $adapterPath = "BizTalk:\Platform Settings\Adapters\$adapter"
    if ((Test-Path $adapterPath) -eq $false)
    {
        Write-Warning "Adapter $adapter not installed."
        return $null
    }

    $handlers = Get-AdapterHandlerSafe -adapterPath $adapterPath
    
    if ($direction)
    {
        $handlers = $handlers | Where-Object { $_.Direction -eq $direction }
    }
    return $handlers

}

function Get-AdapterHandlerSafe ($adapterPath)
{
    <#
    For some reason when fetching adapters fails with DTC error, a retry generally is enough. 
    #>
    $handlers = $null
    $retry = $true
    $counter = 1

    do
    {
        try
        {
            $handlers = Get-ChildItem -Path $adapterPath -ErrorAction SilentlyContinue
            $retry = $false
        }
        catch [System.Exception]
        {
            if($counter -eq 3)
            {
                Write-Host "Get-AdapterHandlerSafe Max retries reached for '$adapterPath'. $_" -ForegroundColor Cyan 
                $retry = $false
            }
        }    
        $counter++
    }
    until ($retry -eq $false)
    return $handlers
}


<#
.Synopsis
   Returns Receive Ports.
.DESCRIPTION
   Returns Receive Ports by default all, if the filter parameter -Filter is included in call only the ports which contains the text specified are returned.
.EXAMPLE
   Get-BizTalkReceivePorts
.EXAMPLE
   Get-BizTalkReceivePorts -filter "namepart"
#>
Function Get-BizTalkReceivePorts
{
param ([Parameter(Mandatory=$false,Position=0,HelpMessage="Specify a filter to only include ports containing the filter text.")]
    [string]$filter ="*" )
	if($filter -ne "*")
	{
        
		Get-WmiObject -Namespace $global:btsWmiNamespace -Class MSBTS_ReceivePort -Filter "Name LIKE '%$filter%'"
	}
	else
	{
		Get-WmiObject -Namespace $global:btsWmiNamespace -Class MSBTS_ReceivePort
	}
	
}


<#
.Synopsis
   Returns Receive Locations.
.DESCRIPTION
   Returns Receive Locations by default all, if the filter parameter -Filter is included in call only the Receive Locations which contains the text specified are returned.
.EXAMPLE
   Get-BizTalkReceiveLocations
.EXAMPLE
   Get-BizTalkReceiveLocations -filter "namepart"
#>
Function Get-BizTalkReceiveLocations
{
param ([Parameter(Mandatory=$false,Position=0,HelpMessage="Specify a filter to only include Locations containing the filter text.")]
    [string]$filter ="*" )
	if($filter -ne "*")
	{
        
		Get-WmiObject -Namespace $global:btsWmiNamespace -Class MSBTS_ReceiveLocation -Filter "Name LIKE '%$filter%'"
	}
	else
	{
		Get-WmiObject -Namespace $global:btsWmiNamespace -Class MSBTS_ReceiveLocation
	}
	
}


<#
.Synopsis
   Returns Send Ports.
.DESCRIPTION
   Returns Send Ports by default all, if the filter parameter -Filter is included in call only the ports which contains the text specified are returned.
.EXAMPLE
   Get-BizTalkSendPorts
.EXAMPLE
   Get-BizTalkSendPorts -filter "namepart"
#>
Function Get-BizTalkSendPorts
{
param ([Parameter(Mandatory=$false,Position=0,HelpMessage="Specify a filter to only include ports containing the filter text.")]
    [string]$filter ="*" )
	if($filter -ne "*")
	{
        
		Get-WmiObject -Namespace $global:btsWmiNamespace -Class MSBTS_SendPort -Filter "Name LIKE '%$filter%'"
	}
	else
	{
		Get-WmiObject -Namespace $global:btsWmiNamespace -Class MSBTS_SendPort
	}
	
}


<#
.Synopsis
   Returns a list of applications that are dependent on BizTalk.System application or specified application.
.DESCRIPTION
   Returns a list of applications that are dependent on BizTalk.System application or specified application in the app parameter.
.EXAMPLE
   Get-BizTalkDependentApplications
.EXAMPLE
   Get-BizTalkDependentApplications -app "searchRoot"
#>
function Get-BizTalkDependentApplications 
{
    param ([string]$app ="BizTalk.System" )

    $appList = New-Object System.Collections.ArrayList
    $currentApplication = Get-BizTalkApplications | Where-Object { $_.Name -eq "$app" } 
     if ($currentApplication -ne $null)
     {
        if ($currentApplication.BackReferences -ne $null)
        {
            foreach ($item in $currentApplication.BackReferences)
            {
                if ($appList.Contains($item.Name) -eq $false)
                {
                    $index = $appList.Add($item.Name)    
                }
                $itemChildren = Get-BizTalkDependentApplications  -app $item.Name
                foreach ($child in $itemChildren)
                {
                    if ($appList.Contains($child.ToString()) -eq $false)
                    {
                       $index = $appList.Add($child.ToString())    
                    }
                }
            }       
        }
     }
     return $appList

}




<#
.Synopsis
   This function will create a new BizTalk Host.
.DESCRIPTION
   This function will create a new BizTalk Host.
.PARAMETER hostName
Name of the host to create.
.PARAMETER hostType
In-process=1, Isolated=2
.PARAMETER ntGroupName
The Windows NT group name of the host.
.PARAMETER authTrusted 
Trusted setting of the host
.PARAMETER isTrackingHost 
Tells if the host should do tracking work
.PARAMETER is32BitOnly
Run 32 bit only
.EXAMPLE
   Create-BizTalkHost
#>
function Create-BizTalkHost(
    [string]$hostName, 
    [ValidateSet("InProcess", "Isolated")]
    [string]$hostType, 
    [string]$ntGroupName, 
    [bool]$authTrusted, 
    [bool]$isTrackingHost, 
    [bool]$is32BitOnly,
    [int]$MessagingMaxReceiveInterval = 500,
    [int]$XlangMaxReceiveInterval = 500    )
{
    try
    {
        
        $curhost = Get-BizTalkHosts -filter $hostName -filterMode Equals
        if ($curhost -eq $null)
        {

            Write-Host "Creating host $hostName" -ForegroundColor Green
            Push-Location "BizTalk:\Platform Settings\Hosts\"
            $curhost = New-Item  -Path "BizTalk:\Platform Settings\Hosts\$hostName" -HostType:$hostType -NtGroupName:$ntGroupName -AuthTrusted:$authTrusted   
            
        }
        else
        {
            if ($curhost.AuthTrusted -eq $authTrusted -and $curhost.HostType -eq $hostType -and $curhost.NtGroupName -eq $ntGroupName)
            {
                Write-Warning "Found host $hostName, updating." 
            }
            else
            {
                throw [System.ApplicationException] "Unable to update host $hostName, read only properties AuthTrusted, NtGroupName or Type different."
            }
        }
        $curhost.Is32BitOnly = $is32BitOnly
        $curhost.HostTracking = $isTrackingHost
        $curhost.MessagingMaxReceiveInterval = $MessagingMaxReceiveInterval
        $curhost.XlangMaxReceiveInterval = $XlangMaxReceiveInterval
        return $curhost
 
    }
    catch [System.Exception]
    {
        Write-Host $_.Exception.Message -BackgroundColor Red
    }
    finally
    {
        Pop-Location
    }
}



#############################################################
# This function will create a new BizTalk Host Instance
#############################################################
function Create-BizTalkHostInstance(
	[string]$hostName,
	[string]$serverName,
    $cred,
    [switch]$preventFromStarting
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
        Push-Location "BizTalk:\Platform Settings\Host Instances" 
        $curinstance = New-Item -Path:'HostInstance' -HostName:"$hostName" -RunningServer:"$serverName" -Credentials:$cred
        if ($preventFromStarting)
        {
            $curinstance.IsDisabled = $true
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
        Pop-Location
    }
}


#############################################################
# This function will create a new BizTalk Host Instance
#############################################################
function Create-BizTalkAdapterHandler(
	[string]$hostName,
	[string]$adapter,
    [bool]$isSend,
    [bool]$isDefault = $false
)
{
    if([System.String]::IsNullOrWhiteSpace($adapter))
    {
        Write-Warning "$handlerDirection adapter handler for adapter '$adapter' on $hostname not created, adapter empty."
        return $null
    } 
    $handlerDirection = "Receive"
    if ($isSend -eq $true)
    {
        $handlerDirection = "Send"    
    }

    $hand1 = Get-BizTalkAdapterHandler -adapter $adapter -direction $handlerDirection

    if($hand1 -eq $null)
    {
        return $null
    }
    $adapterPath = "BizTalk:\Platform Settings\Adapters\$adapter"
    Push-Location $adapterPath
    $adapterHandler = $hand1 | Where-Object { $_.HostName -eq "$hostName"}
    if ($adapterHandler -ne $null)
    {
        Write-Warning "$handlerDirection adapter handler for adapter '$adapter' on $hostname not created, already existed."
        return $adapterHandler
    }

    try
    {
        Write-Host "Creating $handlerDirection Adapter handler for $adapter $hostName" -ForegroundColor Green
         
        # Create handler
        if($isSend -eq $true)
        {
			# Create new send handler
            New-Item -path '.\Dummy' -hostname $hostname -direction $handlerDirection -Default:$isDefault
            Write-Host "$handlerDirection Adapter handler $adapter was successfully created for Host: $hostName" -Fore Green
        }
        else
        {   
			# Create new receive handler
            New-Item -path '.\Dummy' -hostname $hostname -direction $handlerDirection
            Write-Host "$handlerDirection Adapter handler $adapter was successfully created for Host: $hostName" -Fore Green
        }        
        
		
    }
    catch [System.Management.Automation.RuntimeException]
    {
		if ($_.Exception.Message.Contains("Another object with the same key properties already exists.") -eq $true)
        {
			Write-Host "$hostName host instance can't be created because another object with the same key properties already exists." -Fore Red
        }
		else{
        	write-Error "$hostName host instance on server $Server could not be created: $_.Exception.ToString()"
		}
    }
    finally
    {
        Pop-Location
    }
}


#######

Register-BtsSnapin

