
#
# This is as sample script to install prerequisites.
# 
#Requires -RunAsAdministrator


function Install-VCRedist ($mediaLib,$logFullname)
{
    <#
    # Download and install the Visual C++ 2015-2019 redistributable package - x86 and Visual C++ 2015-2019 redistributable package - x64.
    # https://aka.ms/vs/16/release/VC_redist.x64.exe or https://aka.ms/vs/16/release/VC_redist.x86.exe 
    # The file should be stored in the $medialib folder. This functions assumes 64bit installation
    # 
    #>
    $fullPathToVC_Redist = "$mediaLib\VC_redist.x64.exe"
    if (Test-Path -Path $fullPathToVC_Redist)
    {
        Log-SetupStep -message "Installing VC_Redist '$fullPathToVC_Redist'" -level Information
        Start-Process -FilePath $fullPathToVC_Redist -ArgumentList "/quiet /passive /norestart /log $logFullname" -Wait
        Log-SetupStep -message "Installed VC_Redist '$fullPathToVC_Redist'"  -level Information      
    }
    else
    {
        Log-SetupStep -message "Did not find any VC_Redist to install. Expected '$fullPathToVC_Redist'"  -level Error
    }

}


function Install-OleDBDriver ($mediaLib,$logFullname)
{
    <#
    # Download and install the Microsoft® OLE DB Driver 18 for SQL Server®.
    # https://docs.microsoft.com/en-us/sql/connect/oledb/download-oledb-driver-for-sql-server?view=sql-server-ver15
    # The file should be stored in the $medialib folder. This functions assumes 64bit installation
    # 
    #>
    $fullPathToOleDBDriver = "$mediaLib\msoledbsql_18.3.0.0_x64.msi"
    if (Test-Path -Path $fullPathToOleDBDriver)
    {
        Log-SetupStep -message "Installing OleDBDriver '$fullPathToOleDBDriver'" -level Information
        Start-Process -FilePath $fullPathToOleDBDriver -ArgumentList "IACCEPTMSOLEDBSQLLICENSETERMS=YES /quiet /passive /norestart /log $logFullname" -Wait
        Log-SetupStep -message "Installed OleDBDriver '$fullPathToOleDBDriver'"  -level Information      
    }
    else
    {
        Log-SetupStep -message "Did not find any OleDBDriver to install. Expected '$fullPathToOleDBDriver'"  -level Error
    }

}

function Install-SQL_AS_ADOMD ($mediaLib,$logFullname)
{
    <#
    # Download and install SQL Server 2016 Analysis Services ADOMD.NET.
    # https://www.microsoft.com/download/details.aspx?id=52676
    # The files should be stored in the $medialib folder. This functions assumes the files are msi files and starts with SQL_AS_ADOMD
    # 
    #>
    Log-SetupStep -message "Install-SQL_AS_ADOMD - Start" 
    $adomdmsi_files = @(Get-ChildItem -Path $media -Filter SQL_AS_ADOMD*.msi)

    foreach ($file in $adomdmsi_files)
    {
        
        Log-SetupStep -message "Installing SQL_AS_ADOMD '$($file.Fullname)'" -level Information
        Start-Process -FilePath $file.Fullname -ArgumentList "/quiet /passive /norestart /log $logFullname" -Wait
        Log-SetupStep -message "Installed SQL_AS_ADOMD '$($file.Fullname)'"  -level Information      
    }
    Log-SetupStep -message "Install-SQL_AS_ADOMD - Done"
}


################################################################
# Maincode
################################################################ 

$scriptfolder = [System.IO.Path]::GetDirectoryName( $MyInvocation.InvocationName)

Set-Location $scriptfolder
Import-Module "$scriptfolder\BtsSetupHelper.psm1" -Global -DisableNameChecking
Check-64Bit
Get-ScriptDirectory
$timestamp = [System.DateTime]::Now.ToString("yyyyMMdd_HHmmss")
$media = "E:\Media"


Install-VCRedist -mediaLib $media -logFullname "$media\$($timestamp)-VC_Redist.log"
Install-OleDBDriver -mediaLib $media -logFullname "$media\$($timestamp)-OleDbDriver.log"
Install-SQL_AS_ADOMD -mediaLib $media -logFullname "$media\$($timestamp)-SQL_AS_ADOMD.log"
