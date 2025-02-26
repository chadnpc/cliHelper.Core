function Write-Marquee {
  #.DESCRIPTION
  #   Writes text as marquee
  # .PARAMETER text
  #   Specifies the text to write
  # .PARAMETER speed
  #   Specifies the marquee speed (60 ms per default)
  # .EXAMPLE
  #   PS> Write-Marquee "Hello_World"
  [CmdletBinding()]
  [Reflection.AssemblyMetadata("title", "Write-Marquee")]
  param (
    [string]$text = "PowerShell is powerful! PowerShell is cross-platform! PowerShell is open-source! PowerShell is easy to learn! Powershell is fully documented",
    [int]$Count = 12,
    [int]$speed = 60
  )

  begin {
    $IAP = $InformationPreference; $InformationPreference = 'Continue'
    [int]$SepLength = 3
    $o = [string][char]124
    $spc = [string][char]0x20
    $sep = [string][char]43 * $SepLength
  }

  process {
    try {
      $looptxt = $($spc * 84) + $(((1..$Count | ForEach-Object { $sep + $spc + $text }) -join $spc) + $spc + $sep) + $($spc * 84)
      [int]$Length = $looptxt.Length
      [int]$Start = 1
      [int]$End = $($Length - 80)
      Clear-Host
      $cnvs = ($o + ([string][char]32 * 82) + $o)
      $line = ([char]45).ToString() * 84
      Write-Output $line; $StartPosition = $Host.UI.RawUI.CursorPosition; $StartPosition.X = 2
      Write-Output $cnvs
      Write-Output $line
      foreach ($Pos in $Start .. $End) {
        $Host.UI.RawUI.CursorPosition = $StartPosition
        $TextToDisplay = $text.Substring($Pos, 80)
        Write-Host -NoNewline $TextToDisplay
        Start-Sleep -Milliseconds $speed
      }
      Write-Output ([Environment]::NewLine)
    } catch {
      $null
    }
  }

  end {
    $InformationPreference = $IAP
    Write-Output ([Environment]::NewLine)
  }
}
