function Out-Verbose {
  # .SYNOPSIS
  #     The function tries to use Write-verbose, when it fails it Falls back to Write-Output
  # .DESCRIPTION
  #     Some platforms cannot utilize Write-Verbose (Azure Functions, for instance).
  #     I was getting tired of write werbose errors, so this is a workaround
  # .EXAMPLE
  #     Out-Verbose "Hello World" -Verbose
  # .NOTES
  #     There is also a work around to enable verbose:
  #     By editing the Host.json file location in Azure Functions app (every app!)
  # .LINK
  #     https://www.koskila.net/how-to-enable-verbose-logging-for-azure-functions/
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
    if ($VerbosePreference -eq 'Continue' -or $PSBoundParameters['Verbose'] -eq $true) {
      $HostForeground = $Host.UI.RawUI.ForegroundColor
      $VerboseForeground = $Host.PrivateData.VerboseForegroundColor
      try {
        $Host.PrivateData.VerboseForegroundColor = "DarkYellow" # So I know This verbose Msg came from Out-Verbose
        $Host.UI.WriteVerboseLine("$Fn $string")
      } catch {
        # We just use Information stream
        $Host.UI.RawUI.ForegroundColor = 'Cyan' # So When the color is different you know somethin's gone wrong with write-verbose
        [double]$VersionNum = $($PSVersionTable.PSVersion.ToString().split('.')[0..1] -join '.')
        if ([bool]$($VersionNum -gt [double]4.0)) {
          $Host.UI.RawUI.ForegroundColor = $VerboseForeground.ToString()
          $Host.UI.WriteLine("VERBOSE: $Fn $string")
        } else {
          # $Host.UI.WriteErrorLine("ERROR: version $VersionNum is not supported by $Fn")
          $Host.UI.WriteInformation("VERBOSE: $Fn $string") # Wrong but meh?! Better than no output at all.
        }
      } finally {
        $Host.UI.RawUI.ForegroundColor = $HostForeground
        $Host.PrivateData.VerboseForegroundColor = $VerboseForeground
      }
    }
  }
}
