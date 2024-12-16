function New-CliArt {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
  [CmdletBinding()]
  [OutputType([CliArt])]
  param (
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'fromfile')]
    [string]$FilePath,

    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'bytes')]
    [byte[]]$bytes
  )
  process {
    if ($PSCmdlet.ParameterSetName -eq 'fromfile') {
      return [CliArt]::new($FilePath)
    } else {
      return [CliArt]::new($bytes)
    }
  }
}