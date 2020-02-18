param(
	[parameter(Mandatory = $false)][string]$destinationFolder="",
	[parameter(Mandatory = $false)][string]$mgmtServer = "Localhost",
	[parameter(Mandatory = $false)][string]$mgmtDatabase="BizTalkMgmtDb"
)

#
# The script is licensed "as-is." You bear the risk of using it. 
# The contributors give no express warranties, guarantees or conditions.
# Test it in safe environment and change it to fit your requirements.
#



function Query-SQLServer($sqlText, $database = "master", $server = ".")
{
    $connection = new-object System.Data.SqlClient.SQLConnection("Data Source=$server;Integrated Security=SSPI;Initial Catalog=$database");
    $cmd = new-object System.Data.SqlClient.SqlCommand($sqlText, $connection);

    $connection.Open();
    $reader = $cmd.ExecuteReader()

    $results = @()
    while ($reader.Read())
    {
        $row = @{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++)
        {
            $row[$reader.GetName($i)] = $reader.GetValue($i)
        }
        $results += new-object psobject -property $row            
    }
    $connection.Close();

    $results
}

function Load-SQLProvider ()
{

    $sqlProvider = Get-PSProvider -PSProvider SqlServer -ErrorAction SilentlyContinue

    if ($sqlProvider -eq $null)
    {
        $sqlSnapin = Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
        if ($sqlSnapin -eq $null)
        {
        	Add-PSSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
        	$sqlSnapin = Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
          if ($sqlSnapin -eq $null)
          {    
                # SQL 2012
                Import-Module SqlPs -ErrorAction Stop
          }
	  else
          {
		    $assemblylist = 
		     "Microsoft.SqlServer.Management.Common",
		     "Microsoft.SqlServer.Smo",
		     "Microsoft.SqlServer.Dmf ",
		     "Microsoft.SqlServer.Instapi ",
		     "Microsoft.SqlServer.SqlWmiManagement ",
		     "Microsoft.SqlServer.ConnectionInfo ",
		     "Microsoft.SqlServer.SmoExtended ",
		     "Microsoft.SqlServer.SqlTDiagM ",
		     "Microsoft.SqlServer.SString ",
		     "Microsoft.SqlServer.Management.RegisteredServers ",
		     "Microsoft.SqlServer.Management.Sdk.Sfc ",
		     "Microsoft.SqlServer.SqlEnum ",
		     "Microsoft.SqlServer.RegSvrEnum ",
		     "Microsoft.SqlServer.WmiEnum ",
		     "Microsoft.SqlServer.ServiceBrokerEnum ",
		     "Microsoft.SqlServer.ConnectionInfoExtended ",
		     "Microsoft.SqlServer.Management.Collector ",
		     "Microsoft.SqlServer.Management.CollectorEnum",
		     "Microsoft.SqlServer.Management.Dac",
		     "Microsoft.SqlServer.Management.DacEnum",
		     "Microsoft.SqlServer.Management.Utility"

		     foreach ($asm in $assemblylist)
		     {
		         $asm = [Reflection.Assembly]::LoadWithPartialName($asm)
		     }
          }	
	}
    }
    
}


function Save-LoginScript ($ServerInstance, [Bool]$IncludeLocalUsers = $false)
{
    $NotAllowedLoginStrings = @("")
    if ($IncludeLocalUsers)
    {
        $NotAllowedLoginStrings = "##", "BUILTIN", "NT AUTHORITY", "NT SERVICE"
    }
    else
    {
        $NotAllowedLoginStrings = "##", "BUILTIN", "NT AUTHORITY", "NT SERVICE", $Env:COMPUTERNAME
    }
    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $ServerInstance
    $loginsSql = "--Logins for Server instance $ServerInstance " + [System.DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss") + "`r`n--`r`n-------------------"
    $instance = $ServerInstance.Replace("\", "_")

    $so = new-object microsoft.sqlserver.management.smo.scriptingoptions;
    $so.LoginSid = $true
    $so.AllowSystemObjects = $false
    foreach ($login in $server.Logins)
    {
        $generate = $true
        foreach ($item in $NotAllowedLoginStrings)
        {
            if ($login.Name.StartsWith($item, [System.StringComparison]::CurrentCultureIgnoreCase) -or $login.Name -eq "sa" )
            {
                $generate = $false
            }
        }
        if ($generate)
        {
            $loginsSql += "`r`n$($login.script( $so ))`r`nGO";    
        } 
    }
    $loginsSql | Out-File "$($instance)_logins_$($script:scriptTime).sql" -Encoding unicode

}

function Save-JobsScript ($ServerInstance)
{
    $AllowedJobs = "Backup BizTalk Server", 
                    "CleanupBTFExpiredEntriesJob_BizTalkMgmtDb", 
                    "DTA Purge and Archive", 
                    "MessageBox_DeadProcesses_Cleanup_BizTalkMsgBoxDb", 
                    "MessageBox_Message_Cleanup_BizTalkMsgBoxDb", 
                    "MessageBox_Message_ManageRefCountLog_BizTalkMsgBoxDb", 
                    "MessageBox_Parts_Cleanup_BizTalkMsgBoxDb", 
                    "MessageBox_UpdateStats_BizTalkMsgBoxDb", 
                    "Monitor BizTalk Server", 
                    "Operations_OperateOnInstances_OnMaster_BizTalkMsgBoxDb", 
                    "PurgeSubscriptionsJob_BizTalkMsgBoxDb", 
                    "Rules_Database_Cleanup_BizTalkRuleEngineDb", 
                    "TrackedMessages_Copy_BizTalkMsgBoxDb"

    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $ServerInstance
    $jobsSql = "--Jobs for Server instance $ServerInstance " + [System.DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss") + "`r`n--`r`n-------------------"
    $instance = $ServerInstance.Replace("\", "_")

    $so = new-object microsoft.sqlserver.management.smo.scriptingoptions;
    $so.AllowSystemObjects = $false
    
    foreach ($job in $server.JobServer.Jobs)
    {
        $generate = $false
        foreach ($item in $AllowedJobs)
        {
            if ($job.Name.Contains($item))
            {
                $generate = $true
            }
        }
        if ($generate)
        {
            $so.AgentJobId = $false
        
            $jobsSql +=  "`r`n-- $($job.Name)`r`n$($job.script( $so ))`r`nGO`r`n--------------------------------------------------------------------------------------";
        }
    
    }

    $jobsSql | Out-File "$($instance)_Jobs_$($script:scriptTime).sql" -Encoding unicode
    
}


Load-SQLProvider 
Set-Location c:
###################################
# Handle parameters

# Get the folder of this script
$scriptPath =  Split-Path -parent $MyInvocation.MyCommand.Definition
if ([System.String]::IsNullOrWhiteSpace( $destinationFolder))
{
    $destinationFolder = $scriptPath
}

###################################
Set-Location $destinationFolder
$script:scriptTime = [System.DateTime]::Now.ToString("yyyy-MM-dd HHmmss")

if ($host.Name -eq "Windows PowerShell ISE Host" -or $host.Name -eq "ConsoleHost" )
{
    Clear-Host
    Write-Host "Export-LoginsAndJobs.ps1 v1.0.1 - Timestamp $($script:scriptTime)"
}



$servers = Query-SQLServer -database $mgmtDatabase -server $mgmtServer -sqlText "SELECT DISTINCT [ServerName]  FROM [dbo].[admv_BackupDatabases]" 


foreach ($s in $servers)
{
    Save-LoginScript -ServerInstance $s.ServerName -IncludeLocalUsers $false
    Save-JobsScript  -ServerInstance $s.ServerName
}



