function Write-Info {
  # .SYNOPSIS
  #       Like Write-Information but with Color options
  # .DESCRIPTION
  #       **requires PS version 5 or Higher **
  #       This function uses Write-Info to Output to INFORMATION Stream
  #       Options include
  #       - Colored Information
  #       - Logging outputto logfile
  #
  #       > [!NOTE] > Write-Host does also 'Output to Information stream' but it always show up In the console; It does not obey $InformationActionPreference. This function does.
  #       This is because Starting in Windows PowerShell 5.0, `Write-Host` is a wrapper for `Write-Information` This allows > you to use `Write-Host` to emit output to the
  #       information stream. This enables the capture or suppression of data written using `Write-Host` while preserving backwards compatibility.
  #       The `$InformationPreference` preference variable and `InformationAction` common parameter do not > affect `Write-Host` messages.

  #       So this is a workaround to produce colored INFO pus it follows same rules as Write-Information (It will not show unless you set '-InformationAction Continue').

  #   .EXAMPLE
  #       Write-Info "This is text in Green ", "followed by red ", "and then we have Magenta... ", "isn't it fun? ", "Here goes DarkCyan" -Color Green,Red,Magenta,White,DarkCyan -StartTab 3 -LinesBefore 1 -LinesAfter 1

  #   .EXAMPLE
  #       Write-Info "1. ", "Option 1" -Color Yellow, Green;`
  #       Write-Info "2. ", "Option 2" -Color Yellow, Green;`
  #       Write-Info "3. ", "Option 3" -Color Yellow, Green;`
  #       Write-Info "4. ", "Option 4" -Color Yellow, Green; Write-Info "9. ", "Press 9 to exit" -Color Yellow, Gray -LinesBefore 1

  #   .EXAMPLE
  #       Write-Info -LinesBefore 2 -Obj "This little ","message is ", "written to log ", "file as well." -Color Yellow, White, Green, Red, Red -LogFile "C:\testing.txt" -TimeFormat "yyyy-MM-dd HH:mm:ss"

  #   .EXAMPLE
  #       Write-Info -Obj "This can get ","handy if ", "want to display things, and log actions to file ", "at the same time." -Color Yellow, White, Green, Red, Red -LogFile "C:\testing.txt"

  #   .EXAMPLE
  #       Write-Info -Obj "My text", " is ", "all colorful" -C Yellow, Red, Green -B Green, Green, Yellow

  #   .EXAMPLE
  #       Write-Info "Sometimes ", "its the same as using ", "Write-Host", '!' -NoNewline -ForegroundColor Green, Gray, Cyan

  #   .LINK
  #       https://github.com/alainQtec/.files/blob/main/src/scripts/Console/Writers/Write-Info.ps1

  #   .NOTES
  #       Reference:
  #           - WriteColor Original idea by Josh (https://stackoverflow.com/users/81769/josh)
  #           - PSWriteColor Module      by EvotecIT Przemyslaw.klys at evotec.pl & https://evotec.xyz
  #       Additional Notes:
  #           - TimeFormat https://msdn.microsoft.com/en-us/library/8kb3ddd4.aspx
  [alias('Write-Hostc')]
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, Position = 0)]
    [alias ('Text', 'Obj')]
    [System.Object[]]$Object,

    [Parameter(Mandatory = $false, Position = 1)]
    [alias ('C', 'ForegroundColor', 'FGC')]
    [ConsoleColor[]]$Color = [ConsoleColor]::White,

    [Parameter(Mandatory = $false, Position = 2)]
    [alias ('B', 'BGC')]
    [ConsoleColor[]]$BackGroundColor = $null,

    [Parameter(Mandatory = $false, Position = 3, HelpMessage = 'Add TABS before Object')]
    [alias ('StartTab')]
    [int]$Indent = 0,

    [Parameter(Mandatory = $false, Position = 4, HelpMessage = 'Add empty line before')]
    [int]$LinesBefore = 0,

    [Parameter(Mandatory = $false, Position = 5)]
    [int]$LinesAfter = 0,

    [Parameter(Mandatory = $false, Position = 6, HelpMessage = 'Add SPACES before Object')]
    [int]$StartSpaces = 0,

    [Parameter(Mandatory = $false, Position = 7)]
    [Alias('DateFormat', 'TimeFormat')]
    [string]$DateTimeFormat = 'yyyy-MM-dd HH:mm:ss',

    [Parameter(Mandatory = $false, Position = 8)]
    [ValidateSet('unknown', 'string', 'unicode', 'bigendianunicode', 'utf8', 'utf7', 'utf32', 'ascii', 'default', 'oem')]
    [string]$Encoding = 'Unicode',

    [Parameter(Mandatory = $false, Position = 9)]
    [Alias('LogPath', 'LogFileName')]
    [string]$LogFile,
    # Uses Write-Log to log OUTPUT
    [switch]$LogOutput,
    # Add Time before output
    [switch]$ShowTime,
    [switch]$NoNewLine
  )
  begin {
    $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('LogFile') -and [IO.File]::Exists($([IO.FileInfo]"$LogFile").FullName)) {
      # Out-Verbose $fxn "Verifying DateFormat string"
      $LogOutput = $true
    } else {
      $LogOutput = $false
    }
  }

  process {
    if ($InformationPreference -eq "Continue") {
      $DefaultColor = $Color[0]
      if ($null -ne $BackGroundColor -and $BackGroundColor.Count -ne $Color.Count) {
        throw "Colors, BackGroundColors parameters count doesn't match. Terminated."
      }
      if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('DateTimeFormat')) {
        # Out-Verbose $fxn "Verifying DateFormat string"
        $ShowTime = $true
      } else {
        $ShowTime = $false
      }
      [double]$VersionNum = $($PSVersionTable.PSVersion.ToString().split('.')[0..1] -join '.')
      if ([bool]$($VersionNum -gt [double]4.0)) {
        if ($LinesBefore -ne 0) { for ($i = 0; $i -lt $LinesBefore; $i++) { Write-Host -Object "`n" -NoNewline } }
        if ($Indent -ne 0) { for ($i = 0; $i -lt $Indent; $i++) { Write-Host -Object "`t" -NoNewline } }
        if ($StartSpaces -ne 0) { for ($i = 0; $i -lt $StartSpaces; $i++) { Write-Host -Object ' ' -NoNewline } }
        if ($ShowTime) { Write-Host -Object "[$([datetime]::Now.ToString($DateTimeFormat))] " -NoNewline }
        if ($PsCmdlet.MyInvocation.BoundParameters.ContainsKey('Object')) {
          if ($Object.Count -ne 0) {
            if ($Color.Count -ge $Object.Count) {
              if ($null -eq $BackGroundColor) {
                for ($i = 0; $i -lt $Object.Length; $i++) { Write-Host -Object $Object[$i] -ForegroundColor $Color[$i] -NoNewline }
              } else {
                for ($i = 0; $i -lt $Object.Length; $i++) { Write-Host -Object $Object[$i] -ForegroundColor $Color[$i] -BackgroundColor $BackGroundColor[$i] -NoNewline }
              }
            } else {
              if ($null -eq $BackGroundColor) {
                for ($i = 0; $i -lt $Color.Length ; $i++) { Write-Host -Object $Object[$i] -ForegroundColor $Color[$i] -NoNewline }
                for ($i = $Color.Length; $i -lt $Object.Length; $i++) { Write-Host -Object $Object[$i] -ForegroundColor $DefaultColor -NoNewline }
              } else {
                for ($i = 0; $i -lt $Color.Length ; $i++) { Write-Host -Object $Object[$i] -ForegroundColor $Color[$i] -BackgroundColor $BackGroundColor[$i] -NoNewline }
                for ($i = $Color.Length; $i -lt $Object.Length; $i++) { Write-Host -Object $Object[$i] -ForegroundColor $DefaultColor -BackgroundColor $BackGroundColor[0] -NoNewline }
              }
            }
          }
          if ($NoNewLine -eq $true) { Write-Host -NoNewline } else { Write-Host }
          if ($LinesAfter -ne 0) { for ($i = 0; $i -lt $LinesAfter; $i++) { Write-Host -Object "`n" -NoNewline } }
        }
      } else {
        # $Host.UI.Write("TEXT")
        $Host.UI.WriteErrorLine("ERROR: version $VersionNum is not supported by $fxn")
        $Host.UI.writeInformation("$Object")
      }
    }
  }
  end {
    if ($LogOutput) {
      foreach ($item in $Object) {
        Write-Log $item
      }
    }
  }
}