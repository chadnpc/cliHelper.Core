function Write-AnimatedHost {
  [CmdletBinding()]
  [OutputType([void])]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [Alias('t')][AllowEmptyString()]
    [string]$text,

    [Parameter(Mandatory = $true, Position = 1)]
    [Alias('f')]
    [System.ConsoleColor]$foregroundColor
  )
  process {
    [void][cli]::Write($text, $foregroundColor)
  }
}