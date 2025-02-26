function Write-Border {
  [CmdletBinding(DefaultParameterSetName = "single")]
  [Reflection.AssemblyMetadata("title", "Write-Border")]
  [OutputType([System.String])]
  Param(
    # The string of text to process
    [Parameter(Position = 0, Mandatory, ValueFromPipeline, ParameterSetName = 'single')]
    [ValidateNotNullOrEmpty()]
    [string]$Text,

    [Parameter(Position = 0, Mandatory, ParameterSetName = 'block')]
    [ValidateNotNullOrEmpty()]
    [Alias("tb")]
    [string[]]$TextBlock,

    # The character to use for the border. It must be a single character.
    [ValidateNotNullOrEmpty()]
    [alias("border")]
    [string]$Character = "*",

    # add blank lines before and after text
    [Switch]$InsertBlanks,

    # insert X number of tabs
    [int]$Tab = 0,

    [Parameter(HelpMessage = "Enter an ANSI escape sequence to color the border characters." )]
    [string]$ANSIBorder,

    [Parameter(HelpMessage = "Enter an ANSI escape sequence to color the text." )]
    [string]$ANSIText
  )

  Begin {
    # "Starting $($myinvocation.mycommand)" -Prefix begin | Write-Verbose
    $tabs = "`t" * $tab
    # "Using a tab of $tab" -Prefix BEGIN | Write-Verbose

    # "Using border character $Character" -Prefix begin | Write-Verbose
    $ansiClear = "$([char]0x1b)[0m"
    if ($PSBoundParameters.ContainsKey("ANSIBorder")) {
      # "Using an ANSI border Color" -Prefix Begin | Write-Verbose
      $Character = "{0}{1}{2}" -f $PSBoundParameters.ANSIBorder, $Character, $ansiClear
    }

    #define regex expressions to detect ANSI escapes. Need to subtract their
    #length from the string if used. Issue #79
    [regex]$ansiopen = "$([char]0x1b)\[\d+[\d;]+m"
    [regex]$ansiend = "$([char]0x1b)\[0m"
  }

  Process {

    if ($pscmdlet.ParameterSetName -eq 'single') {
      # "Processing '$text'"
      #get length of text
      $adjust = 0
      if ($ansiopen.IsMatch($text)) {
        $adjust += ($ansiopen.matches($text) | Measure-Object length -Sum).sum
        $adjust += ($ansiend.matches($text) | Measure-Object length -Sum).sum
        # "Adjusting text length by $adjust."
      }

      $len = $text.Length - $adjust
      if ($PSBoundParameters.ContainsKey("ANSIText")) {
        # "Using an ANSIText color"
        $text = "{0}{1}{2}" -f $PSBoundParameters.ANSIText, $text, $AnsiClear
      }
    } else {
      # "Processing text block"
      #test if text block is already using ANSI
      if ($ansiopen.IsMatch($TextBlock)) {
        # "Text block contains ANSI sequences"
        $txtarray | ForEach-Object -Begin { Set-Variable -Name tempLen -Value @() } -Process {
          $adjust = 0
          $adjust += ($ansiopen.matches($_) | Measure-Object length -Sum).sum
          $adjust += ($ansiend.matches($_) | Measure-Object length -Sum).sum
          # "Length detected as $($_.length)"
          # "Adding adjustment $adjust"
          $tempLen += $_.length - $adjust
        }
        $len = $tempLen | Sort-Object -Descending | Select-Object -First 1
      } elseif ($PSBoundparameters.ContainsKey("ANSIText")) {
        # "Using ANSIText for the block"
        $txtarray = $textblock.split("`n").Trim() | ForEach-Object { "{0}{1}{2}" -f $PSBoundParameters.ANSIText, $_, $AnsiClear }
        $len = ($txtarray | Sort-Object -Property length -Descending | Select-Object -First 1 -ExpandProperty length) - ($psboundparameters.ANSIText.length + 4)
      } else {
        # "Processing simple text block"
        $txtarray = $textblock.split("`n").Trim()
        $len = $txtarray | Sort-Object -Property length -Descending | Select-Object -First 1 -ExpandProperty length
      }
      # "Added $($txtarray.count) text block elements"
    }

    # "Using a length of $len"
    #define a horizontal line
    $hzline = $Character * ($len + 4)

    if ($pscmdlet.ParameterSetName -eq 'single') {
      # "Defining Single body"
      $body = "$tabs$Character $text $Character"
    } else {
      # "Defining Textblock body"
      [string[]]$body = $null
      foreach ($item in $txtarray) {
        if ($item) {
          # "$item [$($item.length)]"
        } else {
          # "detected blank line"
        }
        if ($ansiopen.IsMatch($item)) {
          $adjust = $len
          $adjust += ($ansiopen.matches($item) | Measure-Object length -Sum).sum
          $adjust += ($ansiend.matches($item) | Measure-Object length -Sum).sum
          # "Adjusting length to $adjust"
          $body += "$tabs$Character $(($item).PadRight($adjust)) $Character`r"
        } elseif ($PSBoundparameters.ContainsKey("ANSIText")) {
          #adjust the padding length to take the ANSI value into account
          $adjust = $len + ($psboundparameters.ANSIText.length + 4)
          # "Adjusting length to $adjust"
          $body += "$tabs$Character $(($item).PadRight($adjust)) $Character`r"
        } else {
          $body += "$tabs$Character $(($item).PadRight($len)) $Character`r"
        }
      }
    }
    # "Defining top border"
    [string[]]$out = "`n$tabs$hzline"
    $lines = $body.split("`n")
    # "Adding $($lines.count) lines" | Write-Verbose
    if ($InsertBlanks) {
      # "Prepending blank line"
      $out += "$tabs$character $((" ")*$len) $character"
    }
    foreach ($item in $lines ) {
      $out += $item
    }
    if ($InsertBlanks) {
      # "Appending blank line"
      $out += "$tabs$character $((" ")*$len) $character"
    }
    # "Defining bottom border"
    $out += "$tabs$hzline"
    $out
  }
}
