- **BtsSetupHelper.psm1** contains functions to be used from many scripts.
- **Install-BizTalk.ps1** is a sample installation script.
- **Config\Features.xml** is a sample file with features section.
- **Configure-BizTalkServer.ps1** is a sample configuration script

**Sample Templates** 

Folder with sample documents to configure an environment
- **Sample Templates\BTS2016VM.csv** File with token values that will be used at configuration time.
- **Sample Templates\BTS2016VM.kbdx** KeePass file I used for a lab installation. Password: **Nice@Password!**
- **Sample Templates\Create-Group-BTS2016VM.xml** Configuration file with tokens I used for a Lab installation.

**ConfigureHosts**

Folder with files to export and import hosts, instances and handlers for a BizTalk Server group.
- **BizTalk-Common.psm1** Module used from the other scripts, contains some handy functions.
- **Configure-Hosts.ps1** Script to configure hosts, instances and handlers. 
- **Export-BizTalkHostsRemote.ps1** Exports hosts, instances and handlers for a BizTalk Server environment.
- **ExportedHosts-Sample.csv** Sample output from Export-BizTalkHostsRemote.ps1, edit and use to configure an environment.
