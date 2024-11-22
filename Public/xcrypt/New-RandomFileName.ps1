function New-RandomFileName {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification = "Not changing state")]
  [cmdletbinding(DefaultParameterSetName = "none")]
  [Alias("rfn")]
  [outputtype([string])]
  Param(
    [parameter(Position = 0)]
    [Parameter(ParameterSetName = 'none')]
    [Parameter(ParameterSetName = 'home')]
    [Parameter(ParameterSetName = 'temp')]
    #enter an extension without the leading period e.g 'bak'
    [string]$Extension,
    [Parameter(ParameterSetName = 'temp')]
    [alias("temp")]
    [Switch]$UseTempFolder,
    [Parameter(ParameterSetName = 'home')]
    [alias("home")]
    [Switch]$UseHomeFolder
  )

  process {
    if ($UseTempFolder) {
      $filename = [system.io.path]::GetTempFileName()
    } elseif ($UseHomeFolder) {
      $homedocs = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
      $filename = Join-Path -Path $homedocs -ChildPath ([system.io.path]::GetRandomFileName())
    } else {
      $filename = [system.io.path]::GetRandomFileName()
    }

    if ($Extension) {
      $original = [system.io.path]::GetExtension($filename).Substring(1)
      $filename -replace "$original$", $Extension
    } else {
      $filename
    }
  }
}
