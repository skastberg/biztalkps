

function Extract-FilesFromZip {
    param ( [string]$zipArchive,
    [string]$destinationRootFolder,
    [string[]]$filesToExtract,
    [string]$backupFoldername 
    )
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
        Move-Item -Path $destination -Destination "$backupDestination\$($item.Name)" -Force # -ErrorAction SilentlyContinue
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($item,$destination)
    }
    $archive.Close
}

<#
# Download the automation version of WinSCP
# https://winscp.net/download/WinSCP-5.15.3-Automation.zip 
#>
function Install-WinSCP {
    param ([string]$mediaLib, [string]$installPath
    )
    
    $timestampString = [System.DateTime]::Now.ToString("yyyyMMddHHmmss")
    $automationArchive = Get-ChildItem -Path "$mediaLib\WinSCP" | Sort-Object -Property Name -Descending | Select-Object -First 1

    Extract-FilesFromZip $automationArchive.FullName -destinationRootFolder $installPath -filesToExtract "WinSCP.exe","WinSCPNet.dll" -backupFoldername $timestampString
    $dll = "$installPath\WinSCPNet.dll"
    $fv = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($dll).FileVersion

    $configFiles = Get-ChildItem -Path $installPath -Filter "BTSNTSvc*.exe.config"
    foreach ($item in $configFiles) {
        Copy-Item -Path $item.FullName -Destination "$($item.PSParentpath)\$timestampString\$($item.Name)" -Force
        $doc = [XML]"<root/>"
        $doc.Load($item.FullName)
        if ($doc.DocumentElement.Name -eq 'configuration' -and $null -ne $doc.configuration.runtime.assemblyBinding )
        {
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
                if ($doc.configuration.runtime.assemblyBinding -is [Array])
                {
                    $doc.configuration.runtime.assemblyBinding[0].InnerXml += $da
                }
                else
                {
                    $doc.configuration.runtime.assemblyBinding.InnerXml += $da
                }
                
            }
            $doc.Save($item.FullName)

        }

    }

}

Install-WinSCP -mediaLib "D:\Media" -installPath "$($env:BTSINSTALLPATH)"

