function Write-RainbowString {

  param([String] $Line,
    [String] $ForegroundColor = '',
    [String] $BackgroundColor = '')

  $Colors = @('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow',
    'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White')


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
