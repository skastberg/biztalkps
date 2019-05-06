
#Requires -RunAsAdministrator


function Check-32Bit
{
    if ($env:PROCESSOR_ARCHITECTURE -ne "x86")
    {
        $scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value
        
        $errorText = "The script $($scriptInvocation.MyCommand) must run in a 32 bit PowerShell Host. Found architecture $env:PROCESSOR_ARCHITECTURE"
        Write-Error $errorText
        Exit
    }
    
}

function Check-64Bit
{
    if ($env:PROCESSOR_ARCHITECTURE -eq "x86")
    {
        $scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value
        
        $errorText = "The script $($scriptInvocation.MyCommand) must run in a 64 bit PowerShell Host. Found architecture $env:PROCESSOR_ARCHITECTURE"
        Write-Error $errorText
        Exit
    }
    
} 


function Prompt-YesNo ($title,$message, $yesText, $noText)
{
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", $yesText
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", $noText

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

    return $result -eq 0
    
}

function Get-ScriptDirectory
{
    $scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value
    return Split-Path $scriptInvocation.MyCommand.Path
} 

function Log-SetupStep ($message, [ValidateSet('Information','Warning','Error')]$level )
{
    $timestamp = [System.DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
    switch ($level)
    {
        'Warning' 
        {
            Write-Host "$timestamp $message" -ForegroundColor DarkYellow
        }
        'Error' 
        {
            Write-Host "$timestamp $message" -ForegroundColor Red
        }
        Default 
        {
            Write-Host "$timestamp $message" -ForegroundColor Gray
        }
    }

}



################################################################
# Maincode
################################################################ 

