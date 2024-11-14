function New-CliArt {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
  [CmdletBinding()]
  [OutputType([CliArt])]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Base64String
  )
  process {
    return [CliArt]::new($Base64String)
  }
}