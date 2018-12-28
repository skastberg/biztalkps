# RestoreScriptForBizTalkJob
Generates a SQL Server restore script for each SQL Server instance in a BizTalk Server Group each time you take a backup.
Full usage is described in this [Post](https://skastberg.wordpress.com/2017/06/24/generating-restore-scripts-for-biztalk-server-version-4/) 

| Parameter| Default value | Comment |
|---------|----------|---------|
| ServerName | | Name of the SQL Server including instance containing BizTalk Management database i.e “Server01\myinstance”. <br/>**Note**: If you use the listener name in an AG you will need to add the instance name. **Mandatory**
| MgmtDb | BizTalkMgmtDb | Name of BizTalk Management database. not mandatory |
|SqlScriptDestination | NULL | By default, the script stores the scripts in the full backup folder, use this parameter to redirect to another folder. Not mandatory|


