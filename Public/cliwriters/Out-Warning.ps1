function Out-Warning {
  # .SYNOPSIS
  #     The function tries to use Write-Warning, when it fails it Falls back to Write-Output
  # .DESCRIPTION
  #     Some platforms cannot utilize Write-Warning (Azure Functions, for instance).
  #     I was getting tired of write werbose errors, so this is a workaround
  # .EXAMPLE
  #     Out-Warning "Hello World"
  # .LINK
  #     https://www.koskila.net/how-to-enable-verbose-logging-for-azure-functions/
  [Alias('Warn')]
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, Position = 0)]
    [Alias('Fxn', 'Fcn', 'Function')]
    [string]$Fn,
    [Parameter(Mandatory = $false, Position = 1)]
    [Alias('str')]
    [string]$string
  )
  Process {
    if ($WarningPreference -eq 'Continue') {
      $WarningForeground = $Host.PrivateData.WarningForegroundColor
      try {
        $Host.PrivateData.WarningForegroundColor = "DarkYellow" # So I know This verbose Msg came from Out-Verbose
        $Host.UI.WriteWarningLine("$Fn $string")
      } finally {
        $Host.PrivateData.WarningForegroundColor = $WarningForeground
      }
    }
  }
}
