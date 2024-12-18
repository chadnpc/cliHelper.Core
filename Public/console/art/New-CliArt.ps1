function New-CliArt {
  <#
  .SYNOPSIS
    Creates a new CliArt object to store & manipulate ascii art txt.
  .DESCRIPTION
    Makes it easy to store ascii art txt in small compressed format than the original string.
  .EXAMPLE
    $art = Create-CliArt "https://pastebin.com/raw/JVciSv1S" -Taglines "f**k s0c137y💀";
    $art.Write("... Give a man a mask & he will become his true self.");
  .EXAMPLE
    [cliart]"https://pastebin.com/raw/JVciSv1S" | Write-Host -f Green
  .EXAMPLE
    $art = Create-CliArt ./tmp/hacker.txt
    $art | Write-Console -f SpringGreen
  .LINK
    Online version: https://github.com/alainQtec/cliHelper.Core/blob/main/Public/console/art/New-CliArt.ps1
    get yours: https://getcliart.vercel.app/
  .NOTES
    Requires -Modules cliHelper.core
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
  [CmdletBinding(DefaultParameterSetName = 'FilePath')]
  [OutputType([CliArt])][Alias('Create-CliArt')]
  param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'FilePath')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$FilePath,

    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Uri')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Uri,

    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'b64String')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$b64String,

    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'bytes')]
    [ValidateNotNullOrEmpty()]
    [byte[]]$bytes,

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrEmpty()]
    [string[]]$Taglines
  )
  begin {
    $a = $null
  }

  process {
    if ($PSCmdlet.ParameterSetName -in ('FilePath', 'b64String', 'Uri')) {
      $s = $PSBoundParameters[$PSCmdlet.ParameterSetName] -as [string]
      $a = $PSBoundParameters.ContainsKey('Taglines') ? [CliArt]::Create($s, $Taglines) : [CliArt]::Create($s)
    } else {
      $a = $PSBoundParameters.ContainsKey('Taglines') ? ([CliArt]::Create($bytes, $Taglines)) : ([CliArt]::Create($bytes))
    }
  }
  end {
    return $a
  }
}