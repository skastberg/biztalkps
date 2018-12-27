# Export-LoginsAndJobs
Will export Logins and jobs used in a BizTalk Server installation.

Jobs will work when using default names for databases.
Logins will exclude local accounts.


| Parameter | Comment |
|-----------|---------|
| destinationFolder       |    Path to a folder where the exported files will be saved     |
|     mgmtServer      |     Name of the management server, defaults to *Localhost*    |
|    mgmtDatabase       |     Name of the BizTalk Management database, defaults to *BizTalkMgmtDb*     |

*Note*: Requires the SQL Server PowerShell Provider to be installed on the machine you run it.
