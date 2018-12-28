# UpdateJobSteps 1.0.3
Will add a control on T-SQL job steps to ensure the steps only run on a primary replica. This is needed when configuring a BizTalk environment with Availability groups.

Will work when using default names for databases. When using several BizTalk Server instances you will need to run the script once for each instance with jobs.

/* Will only run when primary */ <br/>
IF (sys.fn_hadr_is_primary_replica('master') = 1)<br/>
BEGIN

**-- Original Code**

END

| Parameter | Comment |
|-----------|---------|
| sqlServerName | Name to the SQL Server instance to update  |

*Note*: Requires the SQL Server PowerShell Provider to be installed on the machine you run it.
