#!/usr/bin/env pwsh
<#PSScriptInfo
.VERSION 1.1
.GUID edaca5fb-a697-4a10-9193-d57b8ab4f7db
.AUTHOR Alain Herve
.LICENSEURI https://github.com/chadnpc/CliStyler/blob/main/LICENSE
.TAGS Powershell Profile
#>
function Initialize-CliProfile {
  <#
    .SYNOPSIS
        Initialize or Reload $PROFILE and the core functions necessary for displaying your custom prompt.
    .DESCRIPTION
        As you might guess it is used to Load/reload PowerShell $Profile
        Its usefull when you want to reload powershell session after making changes to your PSProfile.
        Instead of re-opening the terminal window, you just Run:
        PS C:\> Load-PsProfile -dev

        Running with the -auto switch will make sure it loads only when necessary
        which can be usefull if you want the function to run only on first launch of the terminal.
    .EXAMPLE
        PS C:\> Load-PsProfile -dev

        When you want to reload changes in your $Profile and see DEBUG output.
    .LINK
        https://gist.github.com/chadnpc/4ba67f5edf4face251615f9b714ee046
    #>
  [alias('Init-PsProfile', 'Load-PsProfile')]
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [string[]]$Modules,
    [Parameter(Mandatory = $false)]
    [string[]]$Assemblies,
    [switch]$dev,
    [switch]$auto
  )

  Begin {
    $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
    Write-Debug "$fxn Starting ..."
    $dbp = $DebugPreference;
    if ($dev) { $DebugPreference = 'Continue' }
  }

  Process {
    [CliStyler]::Initialize()
  }

  end {
    Write-Debug "$fxn Completed $(if ($IsSuccess) {'Successfully'}else {'With Errors'})"
    $DebugPreference = $dbp
  }
}