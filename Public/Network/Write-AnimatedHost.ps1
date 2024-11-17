function Write-AnimatedHost {
  [CmdletBinding()]
  [OutputType([void])]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [Alias('t')][AllowEmptyString()]
    [string]$text,

    [Parameter(Mandatory = $false, Position = 1)]
    [Alias('f')]
    [System.ConsoleColor]$foregroundColor = "White"
  )
  process {
    [void][cli]::Write($text, $foregroundColor)
  }
}