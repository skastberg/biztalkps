#
# The script is licensed "as-is." You bear the risk of using it. 
# The contributors give no express warranties, guarantees or conditions.
# Test it in safe environment and change it to fit your requirements.
#
#Requires -RunAsAdministrator

param(
    [parameter(Mandatory = $true)][string]$ApplicationName,
    [parameter(Mandatory = $true)][string]$ContentFolder
    )


Write-Host "Install-BizTalkZipPackage.ps1 v1.0.0"


function Log-ProcessStep ($message, [ValidateSet('Information','Warning','Error')]$level )
{
    $timestamp = [System.DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
    switch ($level)
    {
        'Warning' 
        {
            #Write-Host "$timestamp $message" -ForegroundColor DarkYellow
            Write-Host "##vso[task.logissue type=warning;]$message"
        }
        'Error' 
        {
            #Write-Host "$timestamp $message" -ForegroundColor Red
            Write-Host "##vso[task.logissue type=error;]$message"
            Exit 1
        }
        Default 
        {
            #Write-Host "$timestamp $message" -ForegroundColor Gray
            Write-Host "$message"

        }
    }

}


function Extract-FilesFromZip {
    param ( [string]$zipArchive,
    [string]$destinationRootFolder
    )

    Log-ProcessStep -message  "Extract-FilesFromZip - Start" -level Information
    If((test-path $destinationRootFolder -PathType Container))
    {
        
        Log-ProcessStep -message " renaming '$destinationRootFolder' to '$destinationRootFolder-$timestampString'" -level Warning    
        Rename-Item -Path "$destinationRootFolder" -NewName "$destinationRootFolder-$timestampString"
    }
 
     Log-ProcessStep -message "Extracting to '$destinationRootFolder'" -level Information
     Expand-Archive -Path $zipArchive -DestinationPath $destinationRootFolder
     Log-ProcessStep -message  "Extract-FilesFromZip - Done" -level Information
}



function Remove-BizTalkApplication ([string]$application)
{
    $cat = Get-BtsOmCatalog
    $cat.Refresh()
    if ($cat.Applications[$application] -ne $null)
    {
        Log-ProcessStep -message "Stopping and removing Application '$application'" -level Information
        $cat.Applications[$application].Stop([Microsoft.BizTalk.ExplorerOM.ApplicationStopOption]::StopAll)
        Remove-Item -Path "BizTalk:\Applications\$application" -Recurse
        $cat.Refresh()
    }
    else
    {
        Log-ProcessStep -message "Application '$application' not found" -level Information
    }
}


function New-BizTalkApplication  ([string]$application, [string] $description)
{
    Log-ProcessStep -message  "New-BizTalkApplication $application" -level Information

    Push-Location "BizTalk:\Applications"

    New-Item -Path $application -Description $description -Force | Out-Null

    Pop-Location
    Log-ProcessStep -message  "New-BizTalkApplication $application done" -level Information

}


function Get-Inventory([string]$packageFolder, [string]$application)
{
    $inventoryFile = $packageFolder | Join-Path -ChildPath 'BizTalkServerInventory.json'

	if (-not (Test-Path -Path $inventoryFile -PathType 'Leaf'))
	{
		return $null
	}

	$inventory = Get-Content -Path $inventoryFile |
			ConvertFrom-Json |Add-Member -NotePropertyName 'packageFolder' -NotePropertyValue $packageFolder -PassThru | Add-Member -NotePropertyName 'Application' -NotePropertyValue $application -PassThru
    return $inventory
}


Function Process-Inventory($inventory)
{
    $path = "BizTalk:\Applications\$($inventory.Application)\Resources"
    Push-Location $path
    if ('primary' -eq $env:BTS_SRV_MODE.ToLower())
    {
        $btAssembly = $null
        $assembly = $null
        foreach ($item in $inventory.DeploymentSequence)
        {
          $btAssembly = $inventory.BizTalkAssemblies | Where-Object { $_.Name -eq $item }
          $assembly = $inventory.Assemblies | Where-Object { $_.Name -eq $item }
          $binding = $inventory.BindingsFiles | Where-Object { $_.Name -eq $item }
          $rpath = ""
          if ($null -ne $btAssembly)
          {
             $rpath = "$($inventory.packageFolder)\$($btassembly.Path)"
             Log-ProcessStep -message  "Adding Resource $rpath" -level Information
             New-Item -Path .\NameIgnored -SourceLocation "$rpath" -ItemType System.BizTalk:BizTalkAssembly -GacOnAdd -Overwrite | Out-Null
          }
          if ($null -ne $assembly)
          {

             $rpath = "$($inventory.packageFolder)\$($assembly.Path)"
             Log-ProcessStep -message  "Adding Resource $rpath" -level Information
             New-Item -Path .\NameIgnored -SourceLocation "$rpath" -ItemType System.BizTalk:Assembly -GacOnAdd -Overwrite  | Out-Null

          }
          if ($null -ne $binding)
          {
            $rpath = "$($inventory.packageFolder)\$($binding.Path)"
            Log-ProcessStep -message  "Applying binding Resource $rpath" -level Information
            Import-Bindings -Source $rpath -Path "BizTalk:\Applications\$($inventory.Application)"
          }
          $btAssembly = $null
          $assembly = $null
          $binding = $null
        }
    }
    else
    {
        foreach ($item in $inventory.DeploymentSequence)
        {
          $btAssembly = $inventory.BizTalkAssemblies | Where-Object { $_.Name -eq $item }
          $assembly = $inventory.Assemblies | Where-Object { $_.Name -eq $item }
          $rpath = ""
          if ($null -ne $btAssembly)
          {
             $rpath = "$($inventory.packageFolder)\$($btassembly.Path)"
             Log-ProcessStep -message  "Adding Resource $rpath" -level Information
             #New-Item -Path .\NameIgnored -SourceLocation "$rpath" -ItemType System.BizTalk:BizTalkAssembly -GacOnAdd -Overwrite | Out-Null
             Add-GacAssembly -Path $rpath -Force
          }
          if ($null -ne $assembly)
          {

             $rpath = "$($inventory.packageFolder)\$($assembly.Path)"
             Log-ProcessStep -message  "GAC Assembly $rpath" -level Information
             #New-Item -Path .\NameIgnored -SourceLocation "$rpath" -ItemType System.BizTalk:Assembly -GacOnAdd -Overwrite  | Out-Null
             Add-GacAssembly -Path $rpath -Force
          }
          
          $btAssembly = $null
          $assembly = $null
        }
    }
    Pop-Location
}

function Invoke-SelfIn32BitProcess ($scriptPath, $parameters)
{
    if ($env:Processor_Architecture -ne "x86")   
    { 
        &"$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" -noninteractive -noprofile -file $scriptPath  @parameters
        exit
    }    
}



#######################################
# Main code
#######################################

Invoke-SelfIn32BitProcess -scriptPath $myinvocation.Mycommand.path -parameters $PSBoundParameters

$timestampString = [System.DateTime]::Now.ToString("yyyyMMddHHmmss")

Import-Module GAC 
Import-Module $PSScriptRoot\BizTalk-Common.psm1 -DisableNameChecking
Register-BtsSnapin 

#Extract-FilesFromZip -zipArchive $pathToZipFile -destinationRootFolder $ContentFolder
if ('primary' -eq $env:BTS_SRV_MODE.ToLower())
{
    Write-Host "Primary server removing and creating application $ApplicationName"
    Remove-BizTalkApplication -application $ApplicationName
    $desc = "Deploy Server: $($env:COMPUTERNAME)`r`nRelease: $($env:BUILD_BUILDNUMBER)`r`nRelease Time: $([System.DateTime]::Now.ToString("yyyy-MM-dd HH:mm"))"
    New-BizTalkApplication -application $ApplicationName -description $desc
}
else {
    Write-Host "Secondary server working on application $ApplicationName"
}

$inventory = Get-Inventory -packageFolder $ContentFolder -application $ApplicationName
Process-Inventory -inventory $inventory 


