#Requires -RunAsAdministrator
################################################################




function Extract-FilesFromZip {
    param ( [string]$zipArchive,
    [string]$destinationRootFolder,
    [string[]]$filesToExtract,
    [string]$backupFoldername 
    )

    Log-SetupStep -message  "Extract-FilesFromZip - Start" -level Information
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead("$zipArchive")
    
    If(!(test-path $destinationRootFolder -PathType Container))
    {
        New-Item -ItemType Directory -Force -Path $destinationRootFolder | Out-Null
    }
    $filesInArchive = $archive.Entries | Where-Object { ($_.Name -in $filesToExtract) -and $_.FullName.Contains('/') -eq $false  }
    foreach ($item in $filesInArchive)
    {
        $destination = "$destinationRootFolder\$($item.Name)"
        $backupDestination = "$destinationRootFolder\$backupFoldername"
        If(!(test-path $backupDestination -PathType Container))
        {
            New-Item -ItemType Directory -Force -Path $backupDestination | Out-Null
        }
        Log-SetupStep -message  "Extract-FilesFromZip - Backup to $backupDestination." -level Information
        if (Test-Path -Path $destination)
        {
            Move-Item -Path $destination -Destination "$backupDestination\$($item.Name)" -Force # -ErrorAction SilentlyContinue
        }
        
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($item,$destination)
    }
    $archive.Close
    Log-SetupStep -message  "Extract-FilesFromZip - Done" -level Information
}

<#
# Download the automation version of WinSCP
# https://winscp.net/download/WinSCP-5.15.3-Automation.zip or later
#>
function Install-WinSCP {
    param ([string]$mediaLib, [string]$installPath
    )
    
    Log-SetupStep -message  "Install-WinSCP - Start" -level Information

    $timestampString = [System.DateTime]::Now.ToString("yyyyMMddHHmmss")
    $automationArchive = Get-ChildItem -Path "$mediaLib\WinSCP" | Sort-Object -Property Name -Descending | Select-Object -First 1 -ErrorAction SilentlyContinue

    if ($automationArchive -eq $null)
    {
        Log-SetupStep -message  "Install-WinSCP - Failed,  no media found in '$mediaLib\WinSCP'" -level error
        return
    }

    Extract-FilesFromZip $automationArchive.FullName -destinationRootFolder $installPath -filesToExtract "WinSCP.exe","WinSCPNet.dll" -backupFoldername $timestampString
    $dll = "$installPath\WinSCPNet.dll"
    $fv = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($dll).FileVersion

    $configFiles = Get-ChildItem -Path $installPath -Filter "BTSNTSvc*.exe.config"
    foreach ($item in $configFiles) {
        
        Log-SetupStep -message  "Install-WinSCP - Backing up to $($item.PSParentpath)\$timestampString\$($item.Name)" -level Information
        Copy-Item -Path $item.FullName -Destination "$($item.PSParentpath)\$timestampString\$($item.Name)" -Force
        $doc = [XML]"<root/>"
        $doc.Load($item.FullName)
        if ($doc.DocumentElement.Name -eq 'configuration' -and $null -ne $doc.configuration.runtime.assemblyBinding )
        {
            Log-SetupStep -message  "Install-WinSCP - Updating Assemblybinding in '$($item.Fullname)'" -level Information
            $assemblyBinding = $doc.configuration.runtime.assemblyBinding
            $dependentAssemblies = @($assemblyBinding.dependentAssembly)
            $winscpRedirectFound = $false
            foreach ($element in $dependentAssemblies) {
                if ($element.assemblyIdentity.name -eq "WinSCPnet") {
                    $element.bindingRedirect.oldVersion = "0.0.0.0-$fv"
                    $element.bindingRedirect.newVersion = "$fv"
                    $winscpRedirectFound = $true
                }
            }
            if($winscpRedirectFound -eq $false){
                $da =  "<dependentAssembly><assemblyIdentity name=`"WinSCPnet`" publicKeyToken=`"2271ec4a3c56d0bf`" culture=`"neutral`" /><bindingRedirect oldVersion=`"0.0.0.0-$fv`" newVersion=`"$fv`" /></dependentAssembly>"
                $doc.configuration.runtime.assemblyBinding.InnerXml += $da
            }
            $doc.Save($item.FullName)

        }

    }
    Log-SetupStep -message  "Install-WinSCP - Done" -level Information
}

################################################################
# Maincode
################################################################

$scriptfolder = [System.IO.Path]::GetDirectoryName( $MyInvocation.InvocationName)
if ($scriptfolder -eq ".")
{
    $currLocation = Get-Location 
    $scriptfolder = $currLocation.Path
}
else
{
    Set-Location $scriptfolder
}

Import-Module "$scriptfolder\BtsSetupHelper.psm1" -Global -DisableNameChecking



Install-WinSCP -mediaLib "E:\Media" -installPath "$($env:BTSINSTALLPATH)"

