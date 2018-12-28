param(
	[parameter(Mandatory = $true)][string]$ServerName,
    [parameter(Mandatory = $false)][string]$MgmtDb = "BizTalkMgmtDb",
    [parameter(Mandatory = $false)][string]$SqlScriptDestination = $null 

)

#Version: 4.1.0
#
# The script is licensed "as-is." You bear the risk of using it. 
# The contributors give no express warranties, guarantees or conditions.
# Test it in safe environment and change it to fit your requirements.
# 
$ScriptVersion = "4.1.0"


Function Get-BackupFiles
{
param ([string]$sqlServerName, [string]$MgmtDb)
   
     
    
    $query ="
    	DECLARE @FullBackupSetId int 
	    DECLARE @FullMark nvarchar(120)
	    DECLARE @LastBackupSetId int 
	    DECLARE @LastMark nvarchar(120)

	    SELECT TOP 1 @FullBackupSetId = [BackupSetId],  @FullMark = REPLACE(SUBSTRING([BackupFileName],(PATINDEX ( '%_full_%' ,[BackupFileName]  )+6),200),'.bak','')
	    FROM [dbo].[adm_BackupHistory]
	    WHERE  BackupType = 'db' AND SetComplete = 1
	    Order by [BackupSetId] DESC

	    SELECT TOP 1 @LastMark = [MarkName], @LastBackupSetId = BackupSetId 
	    FROM [dbo].[adm_BackupHistory]
	    WHERE  BackupType = 'lg' AND SetComplete = 1
	    Order by [BackupSetId] DESC

	    SELECT BH.[BackupFileLocation] + '\' +BH.[BackupFileName] AS BackupFile
		    , BH.[DatabaseName]
		    ,BH.[BackupFileLocation]
		    , REPLACE(DB.[ServerName], '\','_') + '_' + @FullMark + '_to_' + @LastMark AS ScriptName
		    , BH.[ServerName]
		    , BH.[BackupSetId] AS [BackupSetId]
		    ,BH.[MarkName] AS LogMark
		    , @LastBackupSetId AS LastBackupSetId 
		    , @LastMark AS LastMark
		    , @FullBackupSetId AS FullBackupSetId
		    , @FullMark AS FullMark
		    , BH.BackupType
		FROM [dbo].[adm_BackupHistory] BH
		INNER JOIN [dbo].admv_BackupDatabases DB ON (BH.DatabaseName = DB.DatabaseName)
	    WHERE [BackupSetId] >= @FullBackupSetId AND [BackupSetId] <= @LastBackupSetId AND SetComplete = 1
	    ORDER BY [DatabaseName], [BackupSetId]" 
    $BuppSet = Invoke-Sqlcmd -Server $ServerName -Database $MgmtDb -Query $query 
    $BuppFiles = $BuppSet | 
    Select-Object -Property @{Name="BackupFileName"; Expression = {$_[0]}},
                            @{Name="DatabaseName"; Expression = {$_[1]}} ,
                            @{Name="BackupFileLocation"; Expression = {$_[2]}} ,
                            @{Name="ScriptName"; Expression = {$_[3]}} ,
                            @{Name="ServerName"; Expression = {$_[4]}},
                            @{Name="BackupSetId"; Expression = {$_[5]}},
                            @{Name="LogMark"; Expression = {$_[6]}},
                            @{Name="LastBackupSetId"; Expression = {$_[7]}},
                            @{Name="LastMark"; Expression = {$_[8]}},
                            @{Name="FullBackupSetId"; Expression = {$_[9]}},
                            @{Name="FullMark"; Expression = {$_[10]}},
                            @{Name="BackupType"; Expression = {$_[11]}}
                               
    return $BuppFiles
}

Function Check-IsPrimary
{
param ([string]$sqlServerName, [string]$Db)
   
    $s1 = $sqlServerName.Split("\")
    $ServerName = $s1[0].Replace($s1[0], $env:COMPUTERNAME) + "\" + $s1[1]
    $query ="SELECT ISNULL (sys.fn_hadr_is_primary_replica('$Db'),1) AS IsPrimary" 
    $IsPrimaryResult = Invoke-Sqlcmd -Server $ServerName -Database "Master" -Query $query 
        
    return ($IsPrimaryResult.IsPrimary -eq 1)
}


Function Get-FullRestoreScript
{
param ([string]$sqlServerName, [string]$DatabaseName, [string]$fullBackupDevice)

    if ($DatabaseName -eq $MgmtDb)
    {
        $sqlServerName = $ServerName
    }
	$srv = new-object Microsoft.SqlServer.Management.Smo.Server($sqlServerName)
	$res = new-object Microsoft.SqlServer.Management.Smo.Restore


	$res.Devices.AddDevice($fullBackupDevice, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
	
	$sql = "SELECT [name] as LogicalName,[physical_name] as PhysicalName FROM [sys].[database_files] ORDER By file_id"
    $fl = Invoke-Sqlcmd -Server $sqlServerName -Database $DatabaseName -Query $sql

	foreach ($f in $fl )
	{
		$rl = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($f.LogicalName,$f.PhysicalName)
		$dummy = $res.RelocateFiles.Add($rl)
	}
	
	$res.Database = $DatabaseName
	$res.ReplaceDatabase = $true
    $res.Action = [Microsoft.SqlServer.Management.Smo.RestoreActionType]::Database
	$res.NoRecovery = $true
	return $res.Script($srv)[0]
}

Function Get-LogRestoreScript
{

param ([string]$sqlServerName, [string]$DatabaseName,[string]$BackupFile , [string]$LastMark,[string]$CurrentMark )
	$srv = new-object Microsoft.SqlServer.Management.Smo.Server($sqlServerName)
	$res = new-object Microsoft.SqlServer.Management.Smo.Restore
	$res.Database = $DatabaseName
    $res.Devices.AddDevice($BackupFile, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
    $res.Action = [Microsoft.SqlServer.Management.Smo.RestoreActionType]::Log

    if($LastMark -eq $CurrentMark)
	{
		$res.NoRecovery = $false
		$res.StopAtMarkName = $LastMark;
	}
	else
	{
		$res.NoRecovery = $true
	}

    return $res.Script($srv)
}



function Load-SQLProvider ()
{

    $sqlProvider = Get-PSProvider -PSProvider SqlServer -ErrorAction SilentlyContinue

    if ($sqlProvider -eq $null)
    {
        $sqlSnapin = Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
        $sqlModule = Get-Module -Name Sqlps  -ErrorAction SilentlyContinue
        if ($sqlSnapin -eq $null -and $sqlModule -eq $null)
        {
        	Add-PSSnapin SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
        	$sqlSnapin = Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue
          if ($sqlSnapin -eq $null)
          {    
                # SQL 2012
                Import-Module SqlPs -ErrorAction Stop
          }
	    }
    }
    
}


##############################
# Main code
##############################

#Load-SQLProvider

# Exit if this is a secondary replica
$IsPrimaryReplica = Check-IsPrimary -sqlServerName $ServerName -Db $MgmtDb
if ($IsPrimaryReplica -eq $false)
{
    Exit 0
}

$backups = Get-BackupFiles -sqlServerName $ServerName -MgmtDb $MgmtDb
$scriptPath = $backups[0].BackupFileLocation
if ([System.String]::IsNullOrWhiteSpace( $SqlScriptDestination )-eq $false)
{
    $scriptPath = $SqlScriptDestination
}

foreach ($backup in $backups)
{
    $db = $backup.DatabaseName
    $backupservername = $backup.ServerName
    $lastmark = $backup.LastMark 
    $scriptfilename = $backup.ScriptName
    $scriptfullpath = "FileSystem::$scriptPath\$scriptfilename.sql"   


    if ((Test-Path $scriptfullpath) -eq $false )
    {
        "/**************** Restore To Mark: $lastmark  ****************/"| Out-File -Append -FilePath $ScriptFullPath    
        "/**************** Script Version: $ScriptVersion  ****************/"| Out-File -Append -FilePath $ScriptFullPath    
        "USE Master`r`nGO"| Out-File -Append -FilePath $ScriptFullPath
    }

    if($backup.BackupType -eq 'db')
    {
    
        "`r`n/**************** Restore Database $db From Server: $backupservername ****************/"| Out-File -Append -FilePath $ScriptFullPath 
        
        # Generate code to close all other connections
        # This will enable you to restore without deleting DBs or manually disconnecting users
        "IF (EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE [name] = '$db' ))`r`nBEGIN"| Out-File -Append -FilePath $ScriptFullPath
        "/**************** Set Database $db to Single user ****************/"| Out-File -Append -FilePath $ScriptFullPath
        "    ALTER DATABASE $db SET SINGLE_USER WITH ROLLBACK IMMEDIATE`r`nEND"| Out-File -Append -FilePath $ScriptFullPath        


        $script = "/**************** Restore Database " + $backup.DatabaseName + " ****************/`r`n"
	    $script += Get-FullRestoreScript -sqlServerName $backup.ServerName  -DatabaseName $backup.DatabaseName -fullBackupDevice $backup.BackupFileName
	    $script | Out-File -Append -FilePath $scriptfullpath
    }
    else
    {
        $script = Get-LogRestoreScript -sqlServerName  $backup.ServerName  -DatabaseName $backup.DatabaseName -BackupFile $backup.BackupFileName -LastMark $backup.LastMark -CurrentMark $backup.LogMark
        $script | Out-File -Append -FilePath $scriptfullpath
    }

    if ($backup.Logmark -eq $backup.Lastmark)
    {
        # If it is the management database ensure next backup is full.
        if ($MgmtDb -eq $backup.DatabaseName)
        {
            "GO`r`nEXECUTE [$MgmtDb].[dbo].sp_ForceFullBackup" | Out-File -Append -FilePath $scriptfullpath      
        }
        else
        {
            "GO`r`n" | Out-File -Append -FilePath $scriptfullpath
        }
    }

}
