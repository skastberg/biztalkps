param(
	[parameter(Mandatory = $true)][string]$sqlServerName
)
#Version: 1.0.3


Push-Location; Import-Module SQLPs -DisableNameChecking; Pop-Location;




function Set-HADrPrimaryOnly ($SQLServer)
{
    if ($SQLServer.Contains("\") -eq $false)
    {
        $SQLServer = "$SQLServer\DEFAULT"    
    }    
    $SQLProviderLocation = "SQLSERVER:\SQL\${SQLServer}\JobServer\Jobs"

    # Get all of the job steps and hold the output in the $JobSteps object

    $JobSteps = Get-ChildItem -Path $SQLProviderLocation | ForEach-Object {$_.enumjobstepsbyid()} | Where-Object { ($_.SubSystem -eq "TransactSql") -and ($_.Parent.Name -in "Backup BizTalk Server (BizTalkMgmtDb)", 
                        "CleanupBTFExpiredEntriesJob_BizTalkMgmtDb", 
                        "DTA Purge and Archive (BizTalkDTADb)", 
                        "MessageBox_DeadProcesses_Cleanup_BizTalkMsgBoxDb", 
                        "MessageBox_Message_Cleanup_BizTalkMsgBoxDb", 
                        "MessageBox_Message_ManageRefCountLog_BizTalkMsgBoxDb", 
                        "MessageBox_Parts_Cleanup_BizTalkMsgBoxDb", 
                        "MessageBox_UpdateStats_BizTalkMsgBoxDb", 
                        "Monitor BizTalk Server (BizTalkMgmtDb)", 
                        "Operations_OperateOnInstances_OnMaster_BizTalkMsgBoxDb", 
                        "PurgeSubscriptionsJob_BizTalkMsgBoxDb", 
                        "Rules_Database_Cleanup_BizTalkRuleEngineDb", 
                        "TrackedMessages_Copy_BizTalkMsgBoxDb") }



    # Go through each job step and change the OutputFileName to the new location, and also set it to Append Output
    foreach ($Step in $JobSteps) {
        # Refresh to ensure the latest code is in the command
        $Step.Refresh()
        if ($Step.Command.Contains('sys.fn_hadr_is_primary_replica'))
        {
            Write-Host "sys.fn_hadr_is_primary_replica found in $($Step.Parent) $($Step.Name)" $Step.Parent 
        }
        else
        {
            Write-Host "Updating $($Step.Parent) $($Step.Name)"
            $Step.Command = [System.String]::Format("/* Will only run when primary */`r`n IF (sys.fn_hadr_is_primary_replica('{0}') = 1)`r`nBEGIN`r`n   {1}`r`nEND",$Step.DatabaseName, $Step.Command)
            # The Alter() call actually modifies the value
            $Step.Alter()

        }
   
    }
}


Set-HADrPrimaryOnly -SQLServer $sqlServerName

  

