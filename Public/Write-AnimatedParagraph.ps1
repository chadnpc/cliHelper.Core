function Write-AnimatedParagraph {
  # .SYNOPSIS
  #     Writes animated text
  # .DESCRIPTION
  #     Writes animated text
  # .NOTES
  #     Information or caveats about the function e.g. 'This function is not supported in Linux'
  # .LINK
  #     Specify a URI to a help page, this will show when Get-Help -Online is used.
  # .EXAMPLE
  #     Write-Animated -Verbose
  #     Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
  [CmdletBinding()]
  param (
    $Line1 = "", $Line2 = "", $Line3 = "", $Line4 = "", $Line5 = "", $Line6 = "", $Line7 = "", $Line8 = "", $Line9 = "",
    [int]$Speed = 30
  )

  begin {
    function Write-Line {
      param([string]$Line, [int]$Speed)
      [int]$Start = 1
      [int]$End = $Line.Length
      $StartPosition = $ExecutionContext.Host.UI.RawUI.CursorPosition
      $Spaces = [string][char]32 * 69

      if ($Line -eq "") { return }
      foreach ($Pos in @($Start .. $End)) {
        try {
          $TextToDisplay = $Spaces.Substring(0, $([console]::BufferWidth) / 2 - $pos / 2) + $Line.Substring(0, $Pos)
        } catch [System.Management.Automation.MethodInvocationException], [System.ArgumentOutOfRangeException] {
          # BUG HERE:
          # Exception calling "Substring" with "2" argument(s): "Length cannot be less than zero.
          Write-Debug "Yep BUG Still here!"
          $TextToDisplay = $Spaces.Substring(0, 120 / 2 - $pos / 2) + $Line.Substring(0, $Pos)
        }
        [Console]::write($TextToDisplay)
        Start-Sleep -Milliseconds $Speed
        $Host.UI.RawUI.CursorPosition = $StartPosition
      }
      [console]::WriteLine()
    }
    if ($Line1 -eq "") {
      $Line1 = "Welcome to Write-Animated PowerShell function"
      $Line2 = " "
      $Line3 = "This function is based on Markus Fleschutz's write-animated.ps1"
      $Line4 = " "
      $Line5 = "Visit https://github.com/fleschutz/PowerShell for More Cool scripts like this."
      $Line6 = " "
      $Line7 = "Best regards,"
      $Line8 = " "
      $Line9 = "Alain"
    }
  }

  process {
    [console]::WriteLine()
    Write-Line $Line1 $Speed
    Write-Line $Line2 $Speed
    Write-Line $Line3 $Speed
    Write-Line $Line4 $Speed
    Write-Line $Line5 $Speed
    Write-Line $Line6 $Speed
    Write-Line $Line7 $Speed
    Write-Line $Line8 $Speed
    Write-Line $Line9 $Speed
    [console]::WriteLine()
  }

  end {}
}