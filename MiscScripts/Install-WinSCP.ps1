#
# The script is licensed "as-is." You bear the risk of using it. 
# The contributors give no express warranties, guarantees or conditions.
# Test it in safe environment and change it to fit your requirements.
#
#Requires -RunAsAdministrator

<#
    The script will 
        Download the latest WinSCP package from Nuget.
        Take a backup of the current WinSCP and config files in the BizTalk install directory 
        Update the WinSCP files in the BizTalk install folder
        Update the configuration files to match the file version of the new package

#>

function Backup-PreviousWinSCP ($installPath = $env:BTSINSTALLPATH)
{
    
    $timestampString = [System.DateTime]::Now.ToString("yyyyMMddHHmmss")
    $destinationRootFolder = "$installPath\$timestampString"
    Write-Host "Backup-PreviousWinSCP to '$destinationRootFolder'"

    $configFiles = Get-ChildItem -Path $installPath -Filter "BTSNTSvc*.exe.config"
    If(!(test-path $destinationRootFolder -PathType Container))
    {
        New-Item -ItemType Directory -Force -Path $destinationRootFolder | Out-Null
    }
    if (Test-Path -Path $destinationRootFolder)
    {
        $files = Get-ChildItem -Path $installPath\* -Include "WinSCP.exe","WinSCPNet.dll","BTSNTSvc.exe.config","BTSNTSvc64.exe.config"  -File 
        $files | Copy-Item -Destination "$destinationRootFolder" -Force # -ErrorAction SilentlyContinue
    }
}


function Download-WinSCPPackage ($packegesFolder)
{
    $nugetexe = "$PSScriptRoot\nuget.exe"   
    $arguments =  "install WinSCP -OutputDirectory $packagesFolder"    
    if ($false -eq (Test-Path -Path $nugetexe))
    {
        Write-Host "'$nugetexe' not found, download it from https://www.nuget.org/downloads" -ForegroundColor Red
        ##Exit
        Quit
    }

    Write-Host "Downloading latest WinSCP version from Nuget 'https://www.nuget.org/packages/WinSCP/'"   
    $output = &"$nugetexe" install WinSCP -OutputDirectory "$packagesFolder"

    if ($output[($output.Count -1)].EndsWith("is already installed.") )
    {
        Write-Host "$($output[($output.Count -1)]) found in '$packagesFolder'" -ForegroundColor DarkYellow
    }
    else
    {
        Write-Host $output[($output.Count -2)] -ForegroundColor Green
    }

}

function Validate-WinSCPPackage ($packegeFolder)
{
    Write-Host "Validate-WinSCPPackage"
    $isValid = $true    
    $exe =  "$packegeFolder\tools\WinSCP.exe"
    $dll = "$packegeFolder\lib\net40\WinSCPNet.dll"

    if (!(Test-Path $exe))
    {
        $isValid = $false
        Write-Host "Did not find '$exe'" -ForegroundColor Red
    }
    if (!(Test-Path $dll))
    {
        $isValid = $false
        Write-Host "Did not find '$dll'" -ForegroundColor Red
    }
    else
    {
        $fv = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($dll).FileVersion
        Write-Host "Found WinSCPNet.dll version '$fv'" 
    }

    if (! $isValid)
    {
        Write-Host "Validation failed ending without updating!" -ForegroundColor Red
        Exit
    }
}


function Install-WinSCPPackage ($packegeFolder)
{
    Write-Host "Install-WinSCPPackage"
    Validate-WinSCPPackage -packegeFolder $packegeFolder

    $exe =  "$packegeFolder\tools\WinSCP.exe"
    $dll = "$packegeFolder\lib\net40\WinSCPNet.dll"
    $fv = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($dll).FileVersion

    Write-Host "Install-WinSCPPackage, Copy $exe to $($env:BTSINSTALLPATH)"
    Copy-Item -Path $exe -Destination $env:BTSINSTALLPATH -Force
    
    Write-Host "Install-WinSCPPackage, Copy $dll to $($env:BTSINSTALLPATH)"
    Copy-Item -Path $dll -Destination $env:BTSINSTALLPATH -Force

    $configFiles = Get-ChildItem -Path $env:BTSINSTALLPATH -Filter "BTSNTSvc*.exe.config"
    foreach ($item in $configFiles) {
        
        $doc = [XML]"<root/>"
        $doc.Load($item.FullName)
        if ($doc.DocumentElement.Name -eq 'configuration' -and $null -ne $doc.configuration.runtime.assemblyBinding )
        {
            Write-Host "Install-WinSCPPackage, Updating Assemblybinding in '$($item.Fullname)'"
            
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

################################################################
# Maincode
################################################################

$packagesFolder = "$PSScriptRoot\Packages"

Download-WinSCPPackage -packegesFolder $packagesFolder
$latestPackageFolder = (Get-ChildItem -Path $packagesFolder -Directory | Sort-Object -Property Name -Descending | Select-Object -First 1 -ErrorAction SilentlyContinue).FullName

Backup-PreviousWinSCP
Install-WinSCPPackage -packegeFolder $latestPackageFolder





