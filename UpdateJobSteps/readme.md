# UpdateJobSteps 1.0.3
Will add a control on T-SQL job steps to ensure the steps only run on a primary replica.

Will work when using default names for databases. When using several BizTalk Server instances you will need to run the script once for each instance with jobs.


| Parameter | Comment |
|-----------|---------|
| sqlServerName | Name to the SQL Server instance to update  |

*Note*: Requires the SQL Server PowerShell Provider to be installed on the machine you run it.
