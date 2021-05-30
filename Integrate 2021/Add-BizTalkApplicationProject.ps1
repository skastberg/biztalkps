param(
    [parameter(Mandatory = $true)][string]$SolutionPath,
    [parameter(Mandatory = $true)][string]$ApplicationName,
    [parameter(Mandatory = $false)][string[]]$SchemaTokens = @(".Schema"),
    [parameter(Mandatory = $false)][string[]]$OrchestrationTokens = @(".Orchestration"),
    [parameter(Mandatory = $false)][string[]]$TransformTokens = @(".Transform", ".Maps"),
    [parameter(Mandatory = $false)][string[]]$PipelineTokens = @(".Pipeline")
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


function Get-Inventory([string]$packageFolder, [string]$application)
{
    Report-Progress -stepText "Retrieve Inventory"
    $inventoryFile = $packageFolder | Join-Path -ChildPath 'BizTalkServerInventory.json'

	if (-not (Test-Path -Path $inventoryFile -PathType 'Leaf'))
	{
		return $null
	}

	$inventory = Get-Content -Path $inventoryFile | ConvertFrom-Json 
    #|Add-Member -NotePropertyName 'packageFolder' -NotePropertyValue $packageFolder -PassThru | Add-Member -NotePropertyName 'Application' -NotePropertyValue $application -PassThru
    return $inventory
}


function Add-ProjectToSolution
{
param(
    [parameter(Mandatory = $true)][string]$SolutionPath,
    [parameter(Mandatory = $true)][string]$appProjectPath,
    [parameter(Mandatory = $true)][string]$appName
)

    Report-Progress -stepText "Adding BizTalk Application Project ($appName) to solution $SolutionPath"
    # This path can differ from machine to machine so we lookup BizTalkServerApplication.vstemplate and replace with your path.
    #"C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\Common7\IDE\Extensions\21mc0q5m.djw\ProjectTemplates\Alm\BizTalkServerApplication.vstemplate"

    $projectTemplate = (Get-ChildItem -Path ${env:ProgramFiles(x86)} -Recurse -Filter "BizTalkServerApplication.vstemplate" | Select-Object  -First 1).FullName
    
    #Visual Studio solution handling
    $dte = New-Object -ComObject VisualStudio.DTE
    $dte.ExecuteCommand("File.OpenProject",$SolutionPath)
    
    $project = $dte.Solution.AddFromTemplate("$projectTemplate","$appProjectPath", $appName,$false)
    return $dte
}

function Set-NetFramework ($propGroupNodes, $namespace, $xdoc)
{
    Report-Progress -stepText "Updating Target .NET Framework"
    $configs = $xdoc.DocumentElement.PropertyGroup | Where-Object { $_.Label -eq "Configuration" }

    foreach ($item in $configs)
    {
        $moniker = $xdoc.CreateElement("TargetFrameworkMoniker", $namespace )
        $moniker.InnerText = ".NETFramework,Version=v4.8" # ".NETFramework,Version=v4.7.2" if using 4.7.2
        $item.AppendChild($moniker) | Out-Null
    }
}


function Add-TokenToDeploymentSequence
{
param(
    [parameter(Mandatory = $true)][string[]]$Tokens,
    [parameter(Mandatory = $true)]$inventory
    )
    foreach ($token in $Tokens)
    {
        $list = $inventory.BizTalkAssemblies | Where-Object { $_.Name.ToLower().Contains($token.ToLower()) }    
        foreach ($item in $list)
        {    
            $inventory.DeploymentSequence.Add($item.Name) | Out-Null
        }
    }
}


function Update-ProjectFiles
{
param(
    [parameter(Mandatory = $true)][string]$appProjectPath,
    [parameter(Mandatory = $true)][string]$appName,
    [parameter(Mandatory = $true)]$vsdte,
    [parameter(Mandatory = $true)][string[]]$SchemaTokens,
    [parameter(Mandatory = $true)][string[]]$OrchestrationTokens,
    [parameter(Mandatory = $true)][string[]]$TransformTokens,
    [parameter(Mandatory = $true)][string[]]$PipelineTokens
)

    Report-Progress -stepText "Updating Project files" 
    $appProjectFile = "$appProjectPath\$appName.btaproj"
    $appInventoryFile = "$appProjectPath\BizTalkServerInventory.json"

    # Project file
    $xdoc = [XML]"<dummy/>"
    $xdoc.Load($appProjectFile)
    $ns = $xdoc.DocumentElement.NamespaceURI
    Set-NetFramework -propGroupNodes $xdoc.DocumentElement.PropertyGroup -namespace $ns -xdoc $xdoc
    
    
    $element = $xdoc.CreateElement("ItemGroup", $ns )
    $xdoc.DocumentElement.InsertAfter($element, $xdoc.DocumentElement.ItemGroup) | Out-Null

    # Inventory file
    $inventory = Get-Inventory -packageFolder $appProjectPath -application $appName
    # Convert arrays to ArrayList to be able to add items
    $inventory.BizTalkAssemblies =[System.Collections.ArrayList]$inventory.BizTalkAssemblies
    $inventory.Assemblies =[System.Collections.ArrayList]$inventory.Assemblies
    $inventory.DeploymentSequence =[System.Collections.ArrayList]$inventory.DeploymentSequence

    # Get the projects except the new one and folders.
    $projects = $vsdte.Solution.Projects | Where-Object { [string]::IsNullOrWhiteSpace($_.FullName) -eq $false -and $_.Name -ne $appName }

    # Changing location to ensure we get the relative path
    Push-Location $appProjectPath
    foreach ($p in $projects)
    {
        Report-Progress -stepText "Adding $($p.Name) reference and package json."
        # Add Reference
        $relPath = Resolve-Path -Path $p.FullName -Relative 
        $pr = $xdoc.CreateElement("ProjectReference", $ns )
        $pr.SetAttribute("Include",$relPath) | Out-Null
        $element.AppendChild($pr) | Out-Null

        # Add to Json file
        if ([System.IO.Path]::GetExtension($p.FileName) -eq ".btproj")
        {
            $o = [PSCustomObject]@{ Name=$p.Name
                                Path="bin\$($p.Properties["AssemblyName"].Value).dll" }   
            $inventory.BizTalkAssemblies.Add($o)  | Out-Null
        }
        elseif([System.IO.Path]::GetExtension($p.FileName) -eq ".csproj" -or [System.IO.Path]::GetExtension($p.FileName) -eq ".vbproj")
        {
            $o = [PSCustomObject]@{ Name=$p.Name
                                Path="assemblies\$($projects[0].Properties["AssemblyName"].Value).dll" }
            $inventory.Assemblies.Add($o) | Out-Null
                                
        }
    }
    Pop-Location


    # DeploymentSequence

    # Add Assemblies
    Report-Progress -stepText "Adding Assemblies to DeploymentSequence."
    foreach ($item in $inventory.Assemblies)
    {
        $inventory.DeploymentSequence.Add($item.Name) | Out-Null
    }

    # Add BizTalk Assemblies in the right order, Schemas, Transforms, Pipelines and Orchestrations
    Report-Progress -stepText "Adding schemas to DeploymentSequence."   
    Add-TokenToDeploymentSequence -Tokens $SchemaTokens -inventory $inventory 

    Report-Progress -stepText "Adding transforms to DeploymentSequence."
    Add-TokenToDeploymentSequence -Tokens $TransformTokens -inventory $inventory 

    Report-Progress -stepText "Adding pipelines to DeploymentSequence."
    Add-TokenToDeploymentSequence -Tokens $PipelineTokens -inventory $inventory 
    
    Report-Progress -stepText "Adding orchestrations to DeploymentSequence."
    Add-TokenToDeploymentSequence -Tokens $OrchestrationTokens -inventory $inventory 

    Report-Progress -stepText "Saving Project files"
    # Save the files
    $xdoc.Save($appProjectFile)
    $inventory | ConvertTo-Json -Depth 5 | Set-Content -Path $appInventoryFile -Encoding UTF8

}



################################################################
# Maincode
################################################################

Set-Location $PSScriptRoot

$appProjectPath = "$([System.IO.Path]::GetDirectoryName($SolutionPath))\$ApplicationName"



$dte = Add-ProjectToSolution -SolutionPath $SolutionPath -appProjectPath $appProjectPath -appName $ApplicationName
Update-ProjectFiles  -appProjectPath $appProjectPath -appName $ApplicationName -vsdte $dte -SchemaTokens $SchemaTokens -OrchestrationTokens $OrchestrationTokens -TransformTokens $TransformTokens -PipelineTokens $PipelineTokens

$dte.Quit()

Report-Progress -stepText "Done" -completed