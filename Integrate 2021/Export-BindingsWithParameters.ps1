param(
    [parameter(Mandatory = $false)][string]$BindingsPath ="C:\scripts\CarSample.BindingInfo.xml",
    [parameter(Mandatory = $false)][string]$OutFolder = "c:\scripts\Out"
)
<#
    Script to process a binding file to export two files, a bindings file with parameterized and one with tokens and replaced values
    This is an example that handles Receive and Send for FILE and SFTP
    Orchestration handlers
#>

function Set-TokenObject {
    param (
        [parameter(Mandatory = $true)][string]$Token,
        [parameter(Mandatory = $true)][AllowEmptyString()][string]$Value,
        [parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$TokenList
    )
    $t = [PSCustomObject] @{
        Token = $Token
        Value = $Value
    }
    $TokenList.Add( $t) | Out-Null
}

function Set-SendPortDefault  {
    param (
        [parameter(Mandatory = $true)][System.Xml.XmlElement]$Node,
        [parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$TokenList
    )
    $TName = "$($Node.Name)_Address"
    $address = $Node.PrimaryTransport.Address 
    $Node.PrimaryTransport.Address = "`$($TName)"

    # Handler
    $TName = "$($Node.Name)_Handler"
    $handler = $Node.PrimaryTransport.SendHandler.Name 
    $Node.PrimaryTransport.SendHandler.Name = "`$($TName)"
    Set-TokenObject -Token $TName -Value $handler -TokenList $TokenList

    Set-TokenObject -Token $TName -Value $address -TokenList $TokenList
    
}

function Set-SendPortFILE  {
    param (
        [parameter(Mandatory = $true)][System.Xml.XmlElement]$Node,
        [parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$TokenList
    )
    # Address
    $TName = "$($Node.Name)_Address"
    $address = $Node.PrimaryTransport.Address 
    $Node.PrimaryTransport.Address = "`$($TName)"
    Set-TokenObject -Token $TName -Value $address -TokenList $TokenList

    # Handler
    $TName = "$($Node.Name)_Handler"
    $handler = $Node.PrimaryTransport.SendHandler.Name 
    $Node.PrimaryTransport.SendHandler.Name = "`$($TName)"
    Set-TokenObject -Token $TName -Value $handler -TokenList $TokenList

    # TransportTypeData FileName 
    $FName= "$($Node.Name)_FileName"
    [XML]$TransportTypeData = $Node.PrimaryTransport.TransportTypeData
    $Filename = $TransportTypeData.CustomProps.FileName.InnerText 
    $TransportTypeData.CustomProps.FileName.InnerText = "`$($FName)"
    $Node.PrimaryTransport.TransportTypeData = $TransportTypeData.CustomProps.OuterXml
    Set-TokenObject -Token $FName -Value $Filename -TokenList $TokenList
}

function Set-SendPortSFTP  {
    param (
        [parameter(Mandatory = $true)][System.Xml.XmlElement]$Node,
        [parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$TokenList
    )
    # Address
    $TName = "$($Node.Name)_Address"
    $address = $Node.PrimaryTransport.Address 
    $Node.PrimaryTransport.Address = "`$($TName)"
    Set-TokenObject -Token $TName -Value $address -TokenList $TokenList
    
    # Handler
    $TName = "$($Node.Name)_Handler"
    $handler = $Node.PrimaryTransport.SendHandler.Name 
    $Node.PrimaryTransport.SendHandler.Name = "`$($TName)"
    Set-TokenObject -Token $TName -Value $handler -TokenList $TokenList

    # TransportTypeData 
    [XML]$TransportTypeData = $Node.PrimaryTransport.TransportTypeData

    # TargetFileName 
    $FName= "$($Node.Name)_TargetFileName"
    $Filename = $TransportTypeData.CustomProps.TargetFileName.InnerText 
    $TransportTypeData.CustomProps.TargetFileName.InnerText = "`$($FName)"
    Set-TokenObject -Token $FName -Value $Filename -TokenList $TokenList

    #  ServerAddress 
    $SName= "$($Node.Name)_ServerAddress"
    $ServerAddress = $TransportTypeData.CustomProps.ServerAddress.InnerText 
    $TransportTypeData.CustomProps.ServerAddress.InnerText = "`$($SName)"
    Set-TokenObject -Token $SName -Value $ServerAddress -TokenList $TokenList

    # FolderPath 
    $SName= "$($Node.Name)_FolderPath"
    $FolderPath = $TransportTypeData.CustomProps.FolderPath.InnerText 
    $TransportTypeData.CustomProps.FolderPath.InnerText = "`$($SName)"
    Set-TokenObject -Token $SName -Value $FolderPath -TokenList $TokenList

    if ($TransportTypeData.CustomProps.ClientAuthenticationMode.'#text' -eq "Password") {
        # Password
        $TName = "$($Node.Name)_Password"
        Set-TokenObject -Token $TName -Value "" -TokenList $TokenList
        $TransportTypeData.CustomProps.Password.InnerText = "`$($TName)"
        # UserName
        $UName = "$($Node.Name)_UserName"
        Set-TokenObject -Token $UName -Value $TransportTypeData.CustomProps.UserName.InnerText -TokenList $TokenList
        $TransportTypeData.CustomProps.UserName.InnerText = "`$($UName)"
    }

    $Node.PrimaryTransport.TransportTypeData = $TransportTypeData.CustomProps.OuterXml
}

function Set-SendPorts  {
    param (
        [parameter(Mandatory = $true)][XML]$Bindings,
        [parameter(Mandatory = $true)][ AllowEmptyCollection()][System.Collections.ArrayList]$TokenList
    )
    
    Write-Host "Processing SendPorts" -ForegroundColor Green
    foreach ($sp in $Bindings.BindingInfo.SendportCollection.Sendport) {
        Write-Host "Processing '$($sp.Name)'" -ForegroundColor Gray
        switch ($sp.PrimaryTransport.TransportType.Name) {
            "FILE" { 
                Set-SendPortFILE -Node $sp -TokenList $TokenList
             }
             "SFTP" { 
                Set-SendPortSFTP -Node $sp -TokenList $TokenList
             }
            Default {
                Set-SendPortDefault -Node $sp -TokenList $TokenList
            }
        }
    }
}
function Set-ReceiveLocations  {
    param (
        [parameter(Mandatory = $true)][XML]$Bindings,
        [parameter(Mandatory = $true)][ AllowEmptyCollection()][System.Collections.ArrayList]$TokenList
    )
    
    Write-Host "Processing ReceiveLocations" -ForegroundColor Green
    foreach ($rp in $Bindings.BindingInfo.ReceivePortCollection.ReceivePort) {
        Write-Host "Processing '$($rp.Name)'" -ForegroundColor Gray
        foreach ($rl in $rp.ReceiveLocations.ReceiveLocation) {
            switch ($rl.ReceiveLocationTransportType.Name) {
              
                 "SFTP" { 
                    Set-ReceiveLocationSFTP -Node $rl -TokenList $TokenList
                 }
                Default {
                    Set-ReceiveLocationDefault -Node $rl -TokenList $TokenList
                }
            }
        }

    }
}

function Set-ReceiveLocationDefault  {
    param (
        [parameter(Mandatory = $true)][System.Xml.XmlElement]$Node,
        [parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$TokenList
    )
    $TName = "$($Node.Name)_Address"
    $address = $Node.Address 
    $Node.Address = "`$($TName)"
    Set-TokenObject -Token $TName -Value $address -TokenList $TokenList

    $TName = "$($Node.Name)_Handler"
    $handler = $Node.ReceiveHandler.Name 
    $Node.ReceiveHandler.Name = "`$($TName)"
    Set-TokenObject -Token $TName -Value $handler -TokenList $TokenList

    
}

function Set-ReceiveLocationSFTP  {
    param (
        [parameter(Mandatory = $true)][System.Xml.XmlElement]$Node,
        [parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.ArrayList]$TokenList
    )
    $TName = "$($Node.Name)_Address"
    $address = $Node.Address 
    $Node.Address = "`$($TName)"
    Set-TokenObject -Token $TName -Value $address -TokenList $TokenList
    
    $TName = "$($Node.Name)_Handler"
    $handler = $Node.ReceiveHandler.Name 
    $Node.ReceiveHandler.Name = "`$($TName)"
    Set-TokenObject -Token $TName -Value $handler -TokenList $TokenList

    # TransportTypeData 
    [XML]$TransportTypeData = $Node.ReceiveLocationTransportTypeData

    #  ServerAddress 
    $SName= "$($Node.Name)_ServerAddress"
    $ServerAddress = $TransportTypeData.CustomProps.ServerAddress.InnerText 
    $TransportTypeData.CustomProps.ServerAddress.InnerText = "`$($SName)"
    Set-TokenObject -Token $SName -Value $ServerAddress -TokenList $TokenList

    # FolderPath 
    $SName= "$($Node.Name)_FolderPath"
    $FolderPath = $TransportTypeData.CustomProps.FolderPath.InnerText 
    $TransportTypeData.CustomProps.FolderPath.InnerText = "`$($SName)"
    Set-TokenObject -Token $SName -Value $FolderPath -TokenList $TokenList

    if ($TransportTypeData.CustomProps.ClientAuthenticationMode.'#text' -eq "Password") {
        # Password
        $TName = "$($Node.Name)_Password"
        Set-TokenObject -Token $TName -Value "" -TokenList $TokenList
        $TransportTypeData.CustomProps.Password.InnerText = "`$($TName)"
        # UserName
        $UName = "$($Node.Name)_UserName"
        Set-TokenObject -Token $UName -Value $TransportTypeData.CustomProps.UserName.InnerText -TokenList $TokenList
        $TransportTypeData.CustomProps.UserName.InnerText = "`$($UName)"
    }

    $Node.ReceiveLocationTransportTypeData = $TransportTypeData.CustomProps.OuterXml
}


function Set-Orchestrations  {
    param (
        [parameter(Mandatory = $true)][XML]$Bindings,
        [parameter(Mandatory = $true)][ AllowEmptyCollection()][System.Collections.ArrayList]$TokenList
    )
    
    Write-Host "Processing Orchestrations" -ForegroundColor Green
    foreach ($orch in $Bindings.BindingInfo.ModuleRefCollection.ModuleRef.Services.Service) {
        Write-Host "Processing '$($orch.Name)'" -ForegroundColor Gray
        $TName = "$($orch.Name.Replace(".","_"))_Handler"
        $handler = $orch.Host.Name 
        $orch.Host.Name = "`$($TName)"
        Set-TokenObject -Token $TName -Value $handler -TokenList $TokenList
    }
}

################################################################
# Maincode
################################################################

Set-Location $PSScriptRoot

$list = New-Object -TypeName 'System.Collections.ArrayList'
[XML]$myBindings = Get-Content -Path $BindingsPath -Encoding UTF8


Set-SendPorts -bindings $myBindings -TokenList $list
Set-ReceiveLocations -bindings $myBindings -TokenList $list
Set-Orchestrations -bindings $myBindings -TokenList $list

$fileName = [System.IO.Path]::GetFileNameWithoutExtension($BindingsPath)

$myBindings.Save("$OutFolder\$fileName.xml")

$list | Select-Object | Export-Csv -Encoding UTF8 -Path "$OutFolder\$fileName.csv" -NoTypeInformation -UseCulture