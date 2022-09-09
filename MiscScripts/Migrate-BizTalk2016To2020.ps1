param(
    [parameter(Mandatory = $true)][string]$SourceFolder,
    [parameter(Mandatory = $true)][string]$TempFolder,
    [parameter(Mandatory = $true)][string]$DestinationFolder  
)



function Report-Progress ($stepText, [switch]$completed , [switch]$reportError)
{
    $timestampText = "$([System.DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss"))`t$stepText"
    if ($completed)
    {
        Write-Progress -Activity "Upgrading projects" -CurrentOperation $stepText -Completed
        if ($reportError)
        {
            Write-Host $stepText -ForegroundColor White -BackgroundColor Red
        }
        else
        {
            Write-Host $timestampText -ForegroundColor Gray
        }

    }
    else
    {
       Write-Progress -Activity "Upgrading projects" -CurrentOperation $stepText  
       if ($reportError)
       {
            Write-Host $timestampText -ForegroundColor Yellow
       }
       else
       {
            Write-Host $timestampText -ForegroundColor Gray
       }
    }   
}



function Create-TempProjects(
    [parameter(Mandatory = $true)][string]$SourceFolder,
    [parameter(Mandatory = $true)][string]$TempFolder)
{
    Report-Progress -stepText "CopyTo-TempFolder $SourceFolder to $TempFolder, excluding Source control files"
    Copy-Item -Path $SourceFolder -Destination $TempFolder -Recurse -Exclude "*.*scc" 
    $slnFiles = Get-ChildItem -Path $TempFolder -Filter *.sln -Recurse


    foreach ($solution in $slnFiles)
    {
        
        $sln = $solution.FullName
        Report-Progress -stepText "CopyTo-TempFolder removing Source control section from $sln"
        $origSln = "$($solution.Fullname).origSln"
        Rename-Item -Path $sln -NewName $origSln
        $slnContent = Get-Content -Path $origSln -Encoding UTF8
        $inSourceControlSection = $false
        foreach ($line in $slnContent)
        {
            if ( $line.Contains("GlobalSection(TeamFoundationVersionControl)") -eq $true -or $inSourceControlSection -eq $true)
            {
                $inSourceControlSection = $true
                if ($line.Contains("EndGlobalSection"))
                {
                    $inSourceControlSection = $false    
                }
            }
            else
            {
                Add-Content -Value $line -Path $sln -Encoding UTF8 
            }
        }

        Upgrade-Solution -solutionFile $sln


    }
}


function CopyTo-Destination(
    [parameter(Mandatory = $true)][string]$TempFolder,
    [parameter(Mandatory = $true)][string]$DestinationFolder
)
{
    Report-Progress -stepText "CopyTo-Destination $TempFolder to $DestinationFolder"
    Copy-Item -Path "$TempFolder\*" -Destination $DestinationFolder -Recurse -Exclude "*.origSln","t.log"
 
}

function Clean-Temp([parameter(Mandatory = $true)][string]$TempFolder)
{
    Report-Progress -stepText "Clean-Temp $TempFolder"
    Get-ChildItem -Path $TempFolder | Remove-Item -Confirm:$false -Recurse -Force 
    
}

function Upgrade-Solution ($solutionFile)
{
    Report-Progress -stepText  "Upgrade starting: $solutionFile" 
    $program = Get-ChildItem -Path ${env:ProgramFiles(x86)}  -Include  "devenv.exe" -Recurse | Select-Object -First 1
    $arguments = "`"$solutionFile`" /UPGRADE"
    $p = Start-Process -FilePath "$($program.FullName)" -ArgumentList "$arguments" -PassThru -Verb runAs 

    Report-Progress -stepText  "Waiting for upgrade: $solutionFile"
    Wait-Process -Id $p.Id -Timeout 2000
 
    if ($p.ExitCode -ne 0)
    {
        Report-Progress -stepText  "Uppgrade failed: $solutionFile" -reportError  
        #Exit
    }
    else
    {
        Report-Progress -stepText  "Upgrade done: $solutionFile" 
        Write-Host "Upgrade done: $solutionFile" -ForegroundColor White
    }
}

function Build-Solution ($solutionFile)
{
    Report-Progress -stepText  "Build starting: $solutionFile" 
    $program = Get-ChildItem -Path ${env:ProgramFiles(x86)}  -Include  "devenv.exe" -Recurse | Select-Object -First 1
    $arguments = "`"$solutionFile`" /Rebuild Debug /out E:\2016-2020Migration\Temp\t.log"
    $p = Start-Process -FilePath "$($program.FullName)" -ArgumentList "$arguments" -PassThru -Verb runAs 

    Report-Progress -stepText  "Waiting for Build: $solutionFile"
    Wait-Process -Id $p.Id -Timeout 2000
 
    if ($p.ExitCode -ne 0)
    {
        Report-Progress -stepText  "Build failed: $solutionFile" -reportError  
        #Exit
    }
    else
    {
        Report-Progress -stepText  "Build done: $solutionFile" 
        Write-Host "Build done: $solutionFile" -ForegroundColor Green
    }
}



function Build-Solutions(
    [parameter(Mandatory = $true)][string]$TempFolder)
{
    Report-Progress -stepText "Build-Solutions $TempFolder"
    
    $slnFiles = Get-ChildItem -Path $TempFolder -Filter *.sln -Recurse


    foreach ($solution in $slnFiles)
    {
        Build-Solution -solutionFile $solution.FullName    
    }
}


function Update-TargetFramework([parameter(Mandatory = $true)][string]$TempFolder, [parameter(Mandatory = $true)][ValidateSet("v4.6", "v4.7.2", "v4.8")][string]$TargetFramework)
{
    Report-Progress -stepText "Update-ProjectFramework $TempFolder, $TargetFramework"
    $projectFiles = Get-ChildItem -Path $TempFolder -Filter *.*proj -Recurse

    foreach ($proj in $projectFiles)
    {
        $pfile = [XML]"<root />"
        Report-Progress -stepText "Update-ProjectFramework $($proj.FullName), $TargetFramework"
        $pfile.Load($proj.FullName)
       

        foreach ($element in $pfile.Project.PropertyGroup)
        {
            if ($element.TargetFrameworkVersion -ne $null)
            {
                $element.TargetFrameworkVersion = $TargetFramework
            }    
        }
        $pfile.Save($proj.FullName)     
    }

    
}


function Rename-SolutionFiles ($renFrom, $renTo, $lookIn)
{
    Get-ChildItem -Path $lookIn -Include "*$renFrom*" -Exclude "*.dll" -File -Recurse | Rename-Item -NewName { $_.Name -replace "$renFrom","$renTo" }  
    Get-ChildItem -Path $lookIn -Include "*$renFrom*" -Directory -Recurse | Rename-Item -NewName { $_.Name -replace "$renFrom","$renTo" }    
    $dte = New-Object -ComObject VisualStudio.DTE.16.0 
    $dte.MainWindow.Visible = $true
    $cmdParams = "Edit.ReplaceinFiles $renFrom $renTo /lookin:""$lookIn"" /sub /all /ext:""!*\bin\*;!*\obj\*;!*\.*"""
    $dte.DTE.ExecuteCommand($cmdParams)

    $dte.Quit()
}



###########################################


Clear-Host

$projectRootName = [System.IO.Path]::GetFileName($SourceFolder)

Create-TempProjects -SourceFolder $SourceFolder -TempFolder $TempFolder
Update-TargetFramework -TempFolder $TempFolder -TargetFramework v4.8

Build-Solutions -TempFolder $TempFolder

CopyTo-Destination -TempFolder $TempFolder -DestinationFolder $DestinationFolder
Rename-SolutionFiles -renFrom "LtB." -renTo "RB." -lookIn $DestinationFolder

Clean-Temp -TempFolder $TempFolder


