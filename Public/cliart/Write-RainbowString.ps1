function Write-RainbowString {
  [CmdletBinding()]
  [Reflection.AssemblyMetadata("title", "Write-RainbowString")]
  param(
    [Parameter(Mandatory = $false)]
    [String] $Line,

    [Parameter(Mandatory = $false)]
    [String] $ForegroundColor = '',

    [Parameter(Mandatory = $false)]
    [String] $BackgroundColor = ''
  )

  begin {
    $Colors = @(
      'Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow',
      'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White'
    )
  }

  process {
    # $Colors[(Get-Random -Min 0 -Max 16)]
    [Char[]] $Line | ForEach-Object {
      if ($ForegroundColor -and $ForegroundColor -ieq 'rainbow') {

        if ($BackgroundColor -and $BackgroundColor -ieq 'rainbow') {
          Write-Host -ForegroundColor $Colors[(
            Get-Random -Min 0 -Max 16
          )] -BackgroundColor $Colors[(
            Get-Random -Min 0 -Max 16
          )] -NoNewline $_
        } elseif ($BackgroundColor) {
          Write-Host -ForegroundColor $Colors[(
            Get-Random -Min 0 -Max 16
          )] -BackgroundColor $BackgroundColor `
            -NoNewline $_
        } else {
          Write-Host -ForegroundColor $Colors[(
            Get-Random -Min 0 -Max 16
          )] -NoNewline $_
        }
      } else {
        # One of them has to be a rainbow, so we know the background is a rainbow here...
        if ($ForegroundColor) {
          Write-Host -ForegroundColor $ForegroundColor -BackgroundColor $Colors[(
            Get-Random -Min 0 -Max 16
          )] -NoNewline $_
        } else {
          Write-Host -BackgroundColor $Colors[(Get-Random -Min 0 -Max 16)] -NoNewline $_
        }
      }
    }
    Write-Host ''
  }
}
