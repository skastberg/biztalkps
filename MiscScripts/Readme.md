# Sample scripts 
A collection of scripts related to BizTalk Server

**Extract-WinSCP.ps1** extracts WinSCP from an automation package zip file and updates BizTalk configuration files to use the new version. Note that if you have done a normal install of WinSCP it will add files to GAC, then this is not the solution for you.

**Install-WinSCP.ps1** Downloads the latest stable WinSCP version from [**Nuget**](https://www.nuget.org/packages/WinSCP/), extracts WinSCP and updates BizTalk configuration files to use the new version. Note that if you have done a normal install of WinSCP it will add files to GAC, then this is not the solution for you. 

**Note:**
*Requires an Internet connection from the server.*
*This script expects [**Nuget.exe**](https://www.nuget.org/downloads) in the same folder.* 