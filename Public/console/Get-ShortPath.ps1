function Get-ShortPath {
  <#
  .SYNOPSIS
    A short one-line action-based description, e.g. 'Tests if a function is valid'
  .DESCRIPTION
    A longer description of the function, its purpose, common use cases, etc.
  .LINK
    https://github.com/chadnpc/cliHelper.Core/blob/main/Public/console/Get-ShortPath.ps1
  .EXAMPLE
    pwd | gsp
  #>
  [CmdletBinding()][OutputType([string])]
  [Reflection.AssemblyMetadata("title", "Get-ShortPath")]
  [Alias("gsp", "Invoke-PathShortener")]
  param (
    # Path to shorten.
    [Parameter(Position = 0, Mandatory = $false , ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullorEmpty()]
    [string]$Path = $ExecutionContext.SessionState.Path.CurrentLocation.Path,

    # Number of parts to keep before truncating. Default value is 2.
    [Parameter()]
    [ValidateRange(0, [int32]::MaxValue)]
    [int]$KeepBefore = 2,

    # Number of parts to keep after truncating. Default value is 1.
    [Parameter()]
    [ValidateRange(1, [int32]::MaxValue)]
    [int]$KeepAfter = 1,

    # Path separator character.
    [Parameter(Mandatory = $false)]
    [string]$Separator = [System.IO.Path]::DirectorySeparatorChar,

    # Truncate character(s). Default is '...'
    # Use '[char]8230' to use the horizontal ellipsis character instead.
    [Parameter()]
    [string]$TruncateChar = [char]8230
  )

  process {
    if (![xcrypt]::IsValidUrl($Path)) {
      $Path = [xcrypt]::GetUnResolvedPath($Path)
    } else {
      $PSBoundParameters["separator"] = "/"
    }
    $splitPath = $Path.Split($Separator, [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($splitPath.Count -gt ($KeepBefore + $KeepAfter)) {
      $outPath = [string]::Empty
      for ($i = 0; $i -lt $KeepBefore; $i++) {
        $outPath += $splitPath[$i] + $Separator
      }
      $outPath += "$($TruncateChar)$($Separator)"
      for ($i = ($splitPath.Count - $KeepAfter); $i -lt $splitPath.Count; $i++) {
        if ($i -eq ($splitPath.Count - 1)) {
          $outPath += $splitPath[$i]
        } else {
          $outPath += $splitPath[$i] + $Separator
        }
      }
    } else {
      $outPath = $splitPath -join $Separator
      if ($splitPath.Count -eq 1) {
        $outPath += $Separator
      }
    }
  }
  End {
    return $outPath
  }
}
