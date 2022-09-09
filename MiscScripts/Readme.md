# Sample scripts 
A collection of scripts related to BizTalk Server

- **Extract-WinSCP.ps1** extracts WinSCP from an automation package zip file and updates BizTalk configuration files to use the new version. Note that if you have done a normal install of WinSCP it will add files to GAC, then this is not the solution for you.
- **Install-WinSCP.ps1** Downloads the latest stable WinSCP version from [**Nuget**](https://www.nuget.org/packages/WinSCP/), extracts WinSCP and updates BizTalk configuration files to use the new version. Note that if you have done a normal install of WinSCP it will add files to GAC, then this is not the solution for you. 
>**Note:**
*Requires an Internet connection from the server.*
*This script expects [**Nuget.exe**](https://www.nuget.org/downloads) in the same folder.* 

- **Migrate-BizTalk2016To2020.ps1** Updates one or more BizTalk 2016 solutions to BizTalk 2020. Creates a copy of the solutions, changes .NET Framework to 4.8 let you rename files and does a replace in files. Finally it builds the projects and shows issues.

- **Add-BTSApplicationProject.ps1** Adds a BizTalk application project to your solution and creates a **BizTalkServerInventory.json** file with the projects in the solution. 
  > **Note** will need some tweaking to your needs.
