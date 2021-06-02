# Integrate 2021 - Utils

Example PowerShell scripts related to BizTalk Server used for my presentation Integrate 2021.

- **Export-BindingsWithParameters** 
  - Takes a bindings file and exports parameterized version and a csv file with tokens and replaced values.

- **Add-BizTalkApplicationProject.ps1**
  - Adds to a BizTalk solution a BizTalk Application Project updating references etc. You need to update the default naming conventions to match you project.
  - **Usage:** *\Add-BizTalkProject.ps1 -SolutionPath C:\yourpath\yoursolution.sln -ApplicationName "Bts.CarSample"*

- **Update-AssemblyInfoVersionFiles.ps1**
  - Sets the Assembly FileVersion during a build.