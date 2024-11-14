function Out-Verbose {
  <#
    .SYNOPSIS
        The function tries to use Write-verbose, when it fails it Falls back to Write-Output
    .DESCRIPTION
        Some platforms cannot utilize Write-Verbose (Azure Functions, for instance).
        I was getting tired of write werbose errors, so this is a workaround
    .EXAMPLE
        Out-Verbose "Hello World" -Verbose
    .NOTES
        There is also a work around to enable verbose:
        By editing the Host.json file location in Azure Functions app (every app!)
        https://www.koskila.net/how-to-enable-verbose-logging-for-azure-functions/
    .LINK
        https://github.com/alainQtec/.files/blob/main/src/scripts/Console/Writers/Out-verbose.ps1
    #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, Position = 0)]
    [Alias('Fxn', 'Fcn', 'Function')]
    [string]$Fn,
    [Parameter(Mandatory = $false, Position = 1)]
    [Alias('str')]
    [string]$string
  )
  Process {
    if ($VerbosePreference -eq 'Continue' -or $PSBoundParameters['Verbose'] -eq $true) {
      $HostForeground = $Host.UI.RawUI.ForegroundColor
      $VerboseForeground = $Host.PrivateData.VerboseForegroundColor
      try {
        $Host.PrivateData.VerboseForegroundColor = "DarkYellow" # So I know This verbose Msg came from Out-Verbose
        $Host.UI.WriteVerboseLine("$Fn $string")
      } catch {
        # We just use Information stream
        $Host.UI.RawUI.ForegroundColor = 'Cyan' # So When the color is different you know somethin's gone wrong with write-verbose
        [double]$VersionNum = $($PSVersionTable.PSVersion.ToString().split('.')[0..1] -join '.')
        if ([bool]$($VersionNum -gt [double]4.0)) {
          $Host.UI.RawUI.ForegroundColor = $VerboseForeground.ToString()
          $Host.UI.WriteLine("VERBOSE: $Fn $string")
        } else {
          # $Host.UI.WriteErrorLine("ERROR: version $VersionNum is not supported by $Fn")
          $Host.UI.WriteInformation("VERBOSE: $Fn $string") # Wrong but meh?! Better than no output at all.
        }
      } finally {
        $Host.UI.RawUI.ForegroundColor = $HostForeground
        $Host.PrivateData.VerboseForegroundColor = $VerboseForeground
      }
    }
  }
}

function Out-Warning {
  <#
    .SYNOPSIS
        The function tries to use Write-Warning, when it fails it Falls back to Write-Output
    .DESCRIPTION
        Some platforms cannot utilize Write-Warning (Azure Functions, for instance).
        I was getting tired of write werbose errors, so this is a workaround
    .EXAMPLE
        Out-Warning "Hello World"
    .LINK
        https://github.com/alainQtec/.files/blob/main/src/scripts/Console/Writers/Out-Warning.ps1
    #>
  [Alias('Warn')]
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, Position = 0)]
    [Alias('Fxn', 'Fcn', 'Function')]
    [string]$Fn,
    [Parameter(Mandatory = $false, Position = 1)]
    [Alias('str')]
    [string]$string
  )
  Process {
    if ($WarningPreference -eq 'Continue') {
      $WarningForeground = $Host.PrivateData.WarningForegroundColor
      try {
        $Host.PrivateData.WarningForegroundColor = "DarkYellow" # So I know This verbose Msg came from Out-Verbose
        $Host.UI.WriteWarningLine("$Fn $string")
      } finally {
        $Host.PrivateData.WarningForegroundColor = $WarningForeground
      }
    }
  }
}

function Show-Tree {
  [CmdletBinding(DefaultParameterSetName = "Path")]
  [alias("pstree", "shtree")]
  Param(
    [Parameter(Position = 0,
      ParameterSetName = "Path",
      ValueFromPipeline,
      ValueFromPipelineByPropertyName
    )]
    [ValidateNotNullOrEmpty()]
    [alias("FullName")]
    [string[]]$Path = ".",

    [Parameter(Position = 0,
      ParameterSetName = "LiteralPath",
      ValueFromPipelineByPropertyName
    )]
    [ValidateNotNullOrEmpty()]
    [string[]]$LiteralPath,

    [Parameter(Position = 1)]
    [ValidateRange(0, 2147483647)]
    [int]$Depth = [int]::MaxValue,

    [Parameter()]
    [ValidateRange(1, 100)]
    [int]$IndentSize = 3,

    [Parameter()]
    [alias("files")]
    [switch]$ShowItem,

    [Parameter(HelpMessage = "Display item properties. Use * to show all properties or specify a comma separated list.")]
    [alias("properties")]
    [string[]]$ShowProperty
  )
  DynamicParam {
    #define the InColor parameter if the path is a FileSystem path
    if ($PSBoundParameters.containsKey("Path")) {
      $here = $psboundParameters["Path"]
    } elseif ($PSBoundParameters.containsKey("LiteralPath")) {
      $here = $psboundParameters["LiteralPath"]
    } else {
      $here = (Get-Location).path
    }
    if (((Get-Item -Path $here).PSprovider.Name -eq 'FileSystem' ) -OR ((Get-Item -LiteralPath $here).PSprovider.Name -eq 'FileSystem')) {
      #define a parameter attribute object
      $attributes = New-Object System.Management.Automation.ParameterAttribute
      $attributes.HelpMessage = "Show tree and item colorized."

      #add an alias
      $alias = [System.Management.Automation.AliasAttribute]::new("ansi")

      #define a collection for attributes
      $attributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
      $attributeCollection.Add($attributes)
      $attributeCollection.Add($alias)

      #define the dynamic param
      $dynParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("InColor", [Switch], $attributeCollection)

      #create array of dynamic parameters
      $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
      $paramDictionary.Add("InColor", $dynParam1)
      #use the array
      return $paramDictionary
    }
  }

  Begin {
    if (!$Path -and $psCmdlet.ParameterSetName -eq "Path") {
      $Path = Get-Location
    }

    if ($PSBoundParameters.containskey("InColor")) {
      $Colorize = $True
      $script:top = ($script:PSAnsiFileMap).where( { $_.description -eq 'TopContainer' }).Ansi
      $script:child = ($script:PSAnsiFileMap).where( { $_.description -eq 'ChildContainer' }).Ansi
    }
    function GetIndentString {
      [CmdletBinding()]
      Param([bool[]]$IsLast)

      #  $numPadChars = 1
      $str = ''
      for ($i = 0; $i -lt $IsLast.Count - 1; $i++) {
        $sepChar = if ($IsLast[$i]) { ' ' } else { '┃' }
        $str += "$sepChar"
        $str += " " * ($IndentSize - 1)
      }
      $teeChar = if ($IsLast[-1]) { '╰' } else { '┃' }
      $str += "$teeChar"
      $str += "━" * ($IndentSize - 1)
      $str
    }
    function ShowProperty() {
      [cmdletbinding()]
      Param(
        [string]$Name,
        [string]$Value,
        [bool[]]$IsLast
      )
      $indentStr = GetIndentString $IsLast
      $propStr = "${indentStr} $Name = "
      $availableWidth = $host.UI.RawUI.BufferSize.Width - $propStr.Length - 1
      if ($Value.Length -gt $availableWidth) {
        $ellipsis = '...'
        $val = $Value.Substring(0, $availableWidth - $ellipsis.Length) + $ellipsis
      } else {
        $val = $Value
      }
      $propStr += $val
      $propStr
    }
    function ShowItem {
      [CmdletBinding()]
      Param(
        [string]$Path,
        [string]$Name,
        [bool[]]$IsLast,
        [bool]$HasChildItems = $false,
        [switch]$Color,
        [ValidateSet("topcontainer", "childcontainer", "file")]
        [string]$ItemType
      )
      if ($IsLast.Count -eq 0) {
        if ($Color) {
          # Write-Output "$([char]0x1b)[38;2;0;255;255m$("$(Resolve-Path $Path)")$([char]0x1b)[0m"
          Write-Output "$($script:top)$("$(Resolve-Path $Path)")$([char]0x1b)[0m"
        } else {
          "$(Resolve-Path $Path)"
        }
      } else {
        $indentStr = GetIndentString $IsLast
        if ($Color) {
          #ToDo - define a user configurable color map
          Switch ($ItemType) {
            "topcontainer" {
              Write-Output "$indentStr$($script:top)$($Name)$([char]0x1b)[0m"
              #Write-Output "$indentStr$([char]0x1b)[38;2;0;255;255m$("$Name")$([char]0x1b)[0m"
            }
            "childcontainer" {
              Write-Output "$indentStr$($script:child)$($Name)$([char]0x1b)[0m"
              #Write-Output "$indentStr$([char]0x1b)[38;2;255;255;0m$("$Name")$([char]0x1b)[0m"
            }
            "file" {
              #only use map items with regex patterns
              foreach ($item in ($script:PSAnsiFileMap | Where-Object Pattern)) {
                if ($name -match $item.pattern -AND (-not $done)) {
                  Write-Output "$indentStr$($item.ansi)$($Name)$([char]0x1b)[0m"
                  #set a flag indicating we've made a match to stop looking
                  $done = $True
                }
              }
              #no match was found so just write the item.
              if (!$done) {
                # No ansi match for $Name
                Write-Output "$indentStr$Name$([char]0x1b)[0m"
              }
            } #file
            Default {
              Write-Output "$indentStr$Name"
            }
          } #switch
        } #if color
        else {
          "$indentStr$Name"
        }
      }
      if ($ShowProperty) {
        $IsLast += @($false)

        $excludedProviderNoteProps = 'PSChildName', 'PSDrive', 'PSParentPath', 'PSPath', 'PSProvider'
        $props = @(Get-ItemProperty $Path -ea 0)
        if ($props[0] -is [pscustomobject]) {
          if ($ShowProperty -eq "*") {
            $props = @($props[0].psobject.properties | Where-Object { $excludedProviderNoteProps -notcontains $_.Name })
          } else {
            $props = @($props[0].psobject.properties |
                Where-Object { $excludedProviderNoteProps -notcontains $_.Name -AND $showproperty -contains $_.name })
          }
        }

        for ($i = 0; $i -lt $props.Count; $i++) {
          $prop = $props[$i]
          $IsLast[-1] = ($i -eq $props.count - 1) -and (-Not $HasChildItems)
          $showParams = @{
            Name   = $prop.Name
            Value  = $prop.Value
            IsLast = $IsLast
          }
          ShowProperty @showParams
        }
      }
    }
    function ShowContainer {
      [CmdletBinding()]
      Param (
        [string]$Path,
        [string]$Name = $(Split-Path $Path -Leaf),
        [bool[]]$IsLast = @(),
        [switch]$IsTop,
        [switch]$Color
      )
      if ($IsLast.Count -gt $Depth) { return }

      $childItems = @()
      if ($IsLast.Count -lt $Depth) {
        try {
          $rpath = Resolve-Path -LiteralPath $Path -ErrorAction stop
        } catch {
          Throw "Failed to resolve $path. This PSProvider and path may be incompatible with this command."
          #bail out
          return
        }
        $childItems = @(Get-ChildItem $rpath -ErrorAction $ErrorActionPreference | Where-Object { $ShowItem -or $_.PSIsContainer })
      }
      $hasChildItems = $childItems.Count -gt 0

      # Show the current container
      $sParams = @{
        path          = $Path
        name          = $Name
        IsLast        = $IsLast
        hasChildItems = $hasChildItems
        Color         = $Color
        ItemType      = If ($isTop) { "topcontainer" } else { "childcontainer" }
      }
      ShowItem @sParams

      # Process the children of this container
      $IsLast += @($false)
      for ($i = 0; $i -lt $childItems.count; $i++) {
        $childItem = $childItems[$i]
        $IsLast[-1] = ($i -eq $childItems.count - 1)
        if ($childItem.PSIsContainer) {
          $iParams = @{
            path   = $childItem.PSPath
            name   = $childItem.PSChildName
            isLast = $IsLast
            Color  = $color
          }
          ShowContainer @iParams
        } elseif ($ShowItem) {
          $unresolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($childItem.PSPath)
          $name = Split-Path $unresolvedPath -Leaf
          $iParams = @{
            Path     = $childItem.PSPath
            Name     = $name
            IsLast   = $IsLast
            Color    = $Color
            ItemType = "File"
          }
          ShowItem @iParams
        }
      }
    }
  }

  Process {
    if ($psCmdlet.ParameterSetName -eq "Path") {
      # In the -Path (non-literal) resolve path in case it is wildcarded.
      $resolvedPaths = @($Path | Resolve-Path | ForEach-Object { $_.Path })
    } else {
      # Must be -LiteralPath
      $resolvedPaths = @($LiteralPath)
    }
    foreach ($rpath in $resolvedPaths) {
      $showParams = @{
        Path  = $rpath
        Color = $colorize
        IsTop = $True
      }
      ShowContainer @showParams
    }
  }
}

function Invoke-PathShortener {
  [CmdletBinding()]
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
    [Parameter()]
    [string]$Separator = [System.IO.Path]::DirectorySeparatorChar,

    # Truncate character(s). Default is '...'
    # Use '[char]8230' to use the horizontal ellipsis character instead.
    [Parameter()]
    [string]$TruncateChar = [char]8230
  )
  process {
    $Path = (Resolve-Path -Path $Path).Path
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

Function Write-ANSIBar {
  [cmdletbinding(DefaultParameterSetName = "standard")]
  [outputtype([System.string])]

  Param(
    [Parameter(Mandatory, HelpMessage = "Enter a range of 256 color values, e.g. (232..255)")]
    [ValidateNotNullOrEmpty()]
    [int[]]$Range,
    [Parameter(HelpMessage = "How many characters do you want in the bar of each value? This will increase the overall length of the bar.")]
    [int]$Spacing = 1,
    [Parameter(ParameterSetName = "standard", HelpMessage = "Specify a character to use for the bar.")]
    [ValidateSet("FullBlock", "LightShade", "MediumShade", "DarkShade", "BlackSquare", "WhiteSquare")]
    [string]$Character = "FullBlock",
    [Parameter(ParameterSetName = "custom", HelpMessage = "Specify a custom character.")]
    [char]$Custom,
    [Parameter(HelpMessage = "Display as a single gradient from the first value to the last.")]
    [switch]$Gradient
  )
  Write-Verbose "Using parameter set $($pscmdlet.ParameterSetName)"

  if ($pscmdlet.ParameterSetName -eq "Standard") {
    Write-Verbose "Using standard character $character"
    Switch ($Character) {
      "FullBlock" {
        $ch = $([char]0x2588)
      }
      "LightShade" {
        $ch = $([char]0x2591)
      }
      "MediumShade" {
        $ch = $([char]0x2592)
      }
      "DarkShade" {
        $ch = $([char]0x2593)
      }
      "BlackSquare" {
        $ch = $([char]0x25A0)
      }
      "WhiteSquare" {
        $ch = [char]0x25A1
      }
    }
  } else {
    $ch = $Custom
  }
  $esc = "$([char]0x1b)"
  $out = @()
  $blank = "$($ch)" * $spacing

  if ($Gradient) {
    Write-Verbose "Creating gradient ANSI bar from $($range[0]) to $($range[-1])"
    $out += $range | ForEach-Object { "$esc[38;5;$($_)m$($blank)$esc[0m" }
  } else {
    Write-Verbose "Creating standard ANSI bar from $($range[0]) to $($range[-1])"
    $out += $range | ForEach-Object {
      "$esc[38;5;$($_)m$($blank)$esc[0m"
    }

    $out += $range | Sort-Object -Descending | ForEach-Object {
      "$esc[38;5;$($_)m$($blank)$esc[0m"
    }
  }
  $out -join ""
}
function Write-Bar {
  <#
    .SYNOPSIS
        A short one-line action-based description, e.g. 'Tests if a function is valid'
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        Write-Bar -Text "Sales" -Value 40.0 -Max 100 -change 2

        # A +2% increase in sales

        Write-Bar -Text "Sales" -Value 28 -Max 100 -Change -2

        # A -2% decrease in sales
    #>
  [Alias('Write-ChartBar')]
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, Position = 0)]
    [Alias('Message', 'msg')]
    [string]$Text,

    [Parameter(Mandatory = $true, Position = 1)]
    [float]$Value,

    [Parameter(Mandatory = $false, Position = 2)]
    [Alias('OutOf')]
    [float]$Max,

    [Parameter(Mandatory = $false, Position = 3)]
    [Alias('PercentChange')]
    [float]$Change
  )
  Begin {
    $IAp = $InformationPreference ; $InformationPreference = "Continue"
  }

  process {
    $Num = ($Value * 100.0) / $Max
    while ($Num -ge 1.0) {
      Write-Host -NoNewline "█"
      $Num -= 1.0
    }
    if ($Num -ge 0.875) {
      Write-Host -NoNewline "▉"
    } elseif ($Num -ge 0.75) {
      Write-Host -NoNewline "▊"
    } elseif ($Num -ge 0.625) {
      Write-Host -NoNewline "▋"
    } elseif ($Num -ge 0.5) {
      Write-Host -NoNewline "▌"
    } elseif ($Num -ge 0.375) {
      Write-Host -NoNewline "▍"
    } elseif ($Num -ge 0.25) {
      Write-Host -NoNewline "▎"
    } elseif ($Num -ge 0.125) {
      Write-Host -NoNewline "▏"
    }
    Write-Host -NoNewline " $Text ", "$Value%" -Color Yellow, Blue
    if ($Change -ge 0.0) {
      Write-Host -f green " +$($Change)%"
    } else {
      Write-Host -f red " $($Change)%"
    }
  }

  End {
    $InformationPreference = $IAp
  }
}
function Write-Border {
  [CmdletBinding(DefaultParameterSetName = "single")]
  [alias('ab')]
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
        $txtarray | ForEach-Object -Begin { $tempLen = @() } -Process {
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

function Write-cLog {
  <#
    .SYNOPSIS
        Emits a log record
    .DESCRIPTION
        This function write a log record to configured targets with the matching level
    .PARAMETER Level
        The log level of the message. Valid values are DEBUG, INFO, WARNING, ERROR, NOTSET
        Other custom levels can be added and are a valid value for the parameter
        INFO is the default
    .PARAMETER Message
        The text message to write
    .PARAMETER Arguments
        An array of objects used to format <Message>
    .PARAMETER Body
        An object that can contain additional log metadata (used in target like ElasticSearch)
    .PARAMETER ExceptionInfo
        An optional ErrorRecord
    .EXAMPLE
        PS C:\> Write-cLog 'Hello, World!'
    .EXAMPLE
        PS C:\> Write-cLog -Level ERROR -Message 'Hello, World!'
    .EXAMPLE
        PS C:\> Write-cLog -Level ERROR -Message 'Hello, {0}!' -Arguments 'World'
  #>
  [CmdletBinding()]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Invalid rule result')]
  param(
    [Parameter(Position = 2, Mandatory = $true)]
    [string]$Message,
    [Parameter(Position = 3, Mandatory = $false)]
    [array]$Arguments,
    [Parameter(Position = 4, Mandatory = $false)]
    [object]$Body = $null,
    [Parameter(Position = 5, Mandatory = $false)]
    [System.Management.Automation.ErrorRecord]$ExceptionInfo = $null
  )

  begin {
    #region Set LoggingVariables
    #Already setup
    if ($Script:Logging -and $Script:LevelNames) {
      return
    }

    Out-Verbose 'Setting up vars'

    $Script:NOTSET = 0
    $Script:DEBUG = 10
    $Script:INFO = 20
    $Script:WARNING = 30
    $Script:ERROR_ = 40

    New-Variable -Name LevelNames -Scope Script -Option ReadOnly -Value ([hashtable]::Synchronized(@{
          $NOTSET   = 'NOTSET'
          $ERROR_   = 'ERROR'
          $WARNING  = 'WARNING'
          $INFO     = 'INFO'
          $DEBUG    = 'DEBUG'
          'NOTSET'  = $NOTSET
          'ERROR'   = $ERROR_
          'WARNING' = $WARNING
          'INFO'    = $INFO
          'DEBUG'   = $DEBUG
        }
      )
    )

    New-Variable -Name ScriptRoot -Scope Script -Option ReadOnly -Value ([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Module.Path))
    New-Variable -Name Defaults -Scope Script -Option ReadOnly -Value @{
      Level       = $LevelNames[$LevelNames['NOTSET']]
      LevelNo     = $LevelNames['NOTSET']
      Format      = '[%{timestamp:+%Y-%m-%d %T%Z}] [%{level:-7}] %{message}'
      Timestamp   = '%Y-%m-%d %T%Z'
      CallerScope = 1
    }

    New-Variable -Name Logging -Scope Script -Option ReadOnly -Value ([hashtable]::Synchronized(@{
          Level          = $Defaults.Level
          LevelNo        = $Defaults.LevelNo
          Format         = $Defaults.Format
          CallerScope    = $Defaults.CallerScope
          CustomTargets  = [String]::Empty
          Targets        = ([System.Collections.Concurrent.ConcurrentDictionary[string, hashtable]]::new([System.StringComparer]::OrdinalIgnoreCase))
          EnabledTargets = ([System.Collections.Concurrent.ConcurrentDictionary[string, hashtable]]::new([System.StringComparer]::OrdinalIgnoreCase))
        }
      )
    )
    #endregion
  }

  DynamicParam {
    $DynamicParams = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
    $attribute = [System.Management.Automation.ParameterAttribute]::new()
    $attribute.ParameterSetName = '__AllParameterSets'
    $attribute.Mandatory = $Mandatory
    $attribute.Position = 1
    $attributeCollection.Add($attribute)
    [String[]]$allowedValues = @()
    switch ($PSCmdlet.ParameterSetName) {
      "DynamicTarget" {
        $allowedValues += $Script:Logging.Targets.Keys
      }
      "DynamicLevel" {
        $l = $Script:LevelNames[[int]$Level]
        $allowedValues += if ($l) { $l } else { $('Level {0}' -f [int]$Level) }
      }
    }
    try {
      $validateSetAttribute = [System.Management.Automation.ValidateSetAttribute]::new($allowedValues)
    } catch [System.Management.Automation.PSArgumentOutOfRangeException] {
      Write-Error "`$allowedValues is out of range`n[`$allowedValues = $allowedValues]"
      break
    }
    $attributeCollection.Add($validateSetAttribute)
    $dynamicParam = [System.Management.Automation.RuntimeDefinedParameter]::new("Level", [string], $attributeCollection)
    $DynamicParams.Add("Level", $dynamicParam)
    $DynamicParams
    $PsCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
  }

  End {
    $PsCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
    $levelNumber = if ($Level -is [int] -and $Level -in $Script:LevelNames.Keys) { $Level }elseif ([string]$Level -eq $Level -and $Level -in $Script:LevelNames.Keys) { $Script:LevelNames[$Level] }else { throw ('Level not a valid integer or a valid string: {0}' -f $Level) }
    $invocationInfo = $(Get-PSCallStack)[$Script:Logging.CallerScope]

    # Split-Path throws an exception if called with a -Path that is null or empty.
    [string] $fileName = [string]::Empty
    if (-not [string]::IsNullOrEmpty($invocationInfo.ScriptName)) {
      $fileName = Split-Path -Path $invocationInfo.ScriptName -Leaf
    }

    $logMessage = [hashtable] @{
      timestamp    = [datetime]::now
      timestamputc = [datetime]::UtcNow
      level        = & { $l = $Script:LevelNames[$levelNumber]; if ($l) { $l } else { $('Level {0}' -f $levelNumber) } }
      levelno      = $levelNumber
      lineno       = $invocationInfo.ScriptLineNumber
      pathname     = $invocationInfo.ScriptName
      filename     = $fileName
      caller       = $invocationInfo.Command
      message      = [string] $Message
      rawmessage   = [string] $Message
      body         = $Body
      execinfo     = $ExceptionInfo
      pid          = $PID
    }

    if ($PSBoundParameters.ContainsKey('Arguments')) {
      $logMessage["message"] = [string] $Message -f $Arguments
      $logMessage["args"] = $Arguments
    }

    #This variable is initiated via Start-LoggingManager
    if (!$Script:LoggingEventQueue) {
      New-Variable -Name LoggingEventQueue -Scope Script -Value ([System.Collections.Concurrent.BlockingCollection[hashtable]]::new(100))
    }
    $Script:LoggingEventQueue.Add($logMessage)
  }
}

# function Stop-LoggingManager {
#   param ()

#   $Script:LoggingEventQueue.CompleteAdding()
#   $Script:LoggingEventQueue.Dispose()

#   [void] $Script:LoggingRunspace.Powershell.EndInvoke($Script:LoggingRunspace.Handle)
#   [void] $Script:LoggingRunspace.Powershell.Dispose()

#   $ExecutionContext.SessionState.Module.OnRemove = $null
#   Get-EventSubscriber | Where-Object { $_.Action.Id -eq $Script:LoggingRunspace.EngineEventJob.Id } | Unregister-Event

#   Remove-Variable -Scope Script -Force -Name LoggingEventQueue
#   Remove-Variable -Scope Script -Force -Name LoggingRunspace
#   Remove-Variable -Scope Script -Force -Name TargetsInitSync
# }

<#
function Start-LoggingManager {
    [CmdletBinding()]
    param(
        [TimeSpan]$ConsumerStartupTimeout = "00:00:10"
    )

    New-Variable -Name LoggingEventQueue    -Scope Script -Value ([System.Collections.Concurrent.BlockingCollection[hashtable]]::new(100))
    New-Variable -Name LoggingRunspace      -Scope Script -Option ReadOnly -Value ([hashtable]::Synchronized(@{ }))
    New-Variable -Name TargetsInitSync      -Scope Script -Option ReadOnly -Value ([System.Threading.ManualResetEventSlim]::new($false))

    $Script:InitialSessionState = [initialsessionstate]::CreateDefault()

    if ($Script:InitialSessionState.psobject.Properties['ApartmentState']) {
        $Script:InitialSessionState.ApartmentState = [System.Threading.ApartmentState]::MTA
    }

    # Importing variables into runspace
    foreach ($sessionVariable in 'ScriptRoot', 'LevelNames', 'Logging', 'LoggingEventQueue', 'TargetsInitSync') {
        $Value = Get-Variable -Name $sessionVariable -ErrorAction Continue -ValueOnly
        Out-Verbose "Importing variable $sessionVariable`: $Value into runspace"
        $v = New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $sessionVariable, $Value, '', ([System.Management.Automation.ScopedItemOptions]::AllScope)
        $Script:InitialSessionState.Variables.Add($v)
    }

    # Importing functions into runspace
    foreach ($Function in 'Format-Pattern', 'Initialize-LoggingTarget', 'Get-LevelNumber') {
        Out-Verbose "Importing function $($Function) into runspace"
        $Body = Get-Content Function:\$Function
        $f = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $Function, $Body
        $Script:InitialSessionState.Commands.Add($f)
    }

    #Setup runspace
    $Script:LoggingRunspace.Runspace = [runspacefactory]::CreateRunspace($Script:InitialSessionState)
    $Script:LoggingRunspace.Runspace.Name = 'LoggingQueueConsumer'
    $Script:LoggingRunspace.Runspace.Open()
    $Script:LoggingRunspace.Runspace.SessionStateProxy.SetVariable('ParentHost', $Host)
    $Script:LoggingRunspace.Runspace.SessionStateProxy.SetVariable('VerbosePreference', $VerbosePreference)

    # Spawn Logging Consumer
    $Consumer = {
        Initialize-LoggingTarget

        $TargetsInitSync.Set(); # Signal to the parent runspace that logging targets have been loaded

        foreach ($Log in $Script:LoggingEventQueue.GetConsumingEnumerable()) {
            if ($Script:Logging.EnabledTargets) {
                $ParentHost.NotifyBeginApplication()

                try {
                    #Enumerating through a collection is intrinsically not a thread-safe procedure
                    for ($targetEnum = $Script:Logging.EnabledTargets.GetEnumerator(); $targetEnum.MoveNext(); ) {
                        [string] $LoggingTarget = $targetEnum.Current.key
                        [hashtable] $TargetConfiguration = $targetEnum.Current.Value
                        $Logger = [scriptblock] $Script:Logging.Targets[$LoggingTarget].Logger

                        $targetLevelNo = Get-LevelNumber -Level $TargetConfiguration.Level

                        if ($Log.LevelNo -ge $targetLevelNo) {
                            Invoke-Command -ScriptBlock $Logger -ArgumentList @($Log.PSObject.Copy(), $TargetConfiguration)
                        }
                    }
                }
                catch {
                    $ParentHost.UI.WriteErrorLine($_)
                }
                finally {
                    $ParentHost.NotifyEndApplication()
                }
            }
        }
    }

    $Script:LoggingRunspace.Powershell = [Powershell]::Create().AddScript($Consumer, $true)
    $Script:LoggingRunspace.Powershell.Runspace = $Script:LoggingRunspace.Runspace
    $Script:LoggingRunspace.Handle = $Script:LoggingRunspace.Powershell.BeginInvoke()

    #region Handle Module Removal
    $OnRemoval = {
        $Module = Get-Module Logging

        if ($Module) {
            $Module.Invoke({
                Wait-Logging
                Stop-LoggingManager
            })
        }

        [System.GC]::Collect()
    }

    # This scriptblock would be called within the module scope
    $ExecutionContext.SessionState.Module.OnRemove += $OnRemoval

    # This scriptblock would be called within the global scope and wouldn't have access to internal module variables and functions that we need
    $Script:LoggingRunspace.EngineEventJob = Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action $OnRemoval
    #endregion Handle Module Removal

    if(-not $TargetsInitSync.Wait($ConsumerStartupTimeout)){
        throw 'Timed out while waiting for logging consumer to start up'
    }
}
#>
function Write-ColorOutput {
  <#
    .SYNOPSIS
        Colored Write-Output
    .DESCRIPTION
        Produce colored output on the console without compromising the expected Output object type.
        Useful when showing info in the console host while avoiding producing strings in the output Objects.
    .EXAMPLE
        C:\> ls -Force | Write-ColorOutput -f 'Green'
    .EXAMPLE
        Help about_foreach | Write-ColorOutput -f Green
    .INPUTS
        Parsable Object
    .OUTPUTS
        Default output object type.
    .LINK
        Online version: https://github.com/alainQtec/.files/blob/main/src/scripts/Console/Writers/Write-ColorOutput.ps1
    .NOTES
        #BUG: Some commands don't work! Example:
        $list = foreach ($file in Get-ChildItem) { if ($file.length -gt 100) { $($file | Select-Object Name, @{l = 'Size'; e = { $_.Length } }) } }
        $list | Write-ColorOutput -F Green -b Black
        #BUG This command works:
        Help about_foreach | Write-ColorOutput -f Green -b Black # but,
    #>
  [alias('Cecho')]
  [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Name')]
  param(
    [Parameter(Mandatory = $false, ParameterSetName = 'Name')]
    [Alias('f')]
    [ArgumentCompleter({
        [OutputType([System.Management.Automation.CompletionResult])]
        param(
          [string]$CommandName,
          [string]$ParameterName,
          [string]$WordToComplete,
          [System.Management.Automation.Language.CommandAst]$CommandAst,
          [System.Collections.IDictionary]$FakeBoundParameters
        )
        $CompletionResults = [System.Collections.Generic.List[System.Management.Automation.CompletionResult]]::new()
        [Enum]::GetValues([ConsoleColor]) | Where-Object { $_.ToString() -like "$wordToComplete*" } | ForEach-Object {
          $CompletionResults.Add([System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_))
        }
        return $CompletionResults
      })]
    [string]$ForegroundColor,
    [Parameter(Mandatory = $false, ParameterSetName = 'Name')]
    [Alias('b')]
    [ArgumentCompleter({
        [OutputType([System.Management.Automation.CompletionResult])]
        param(
          [string]$CommandName,
          [string]$ParameterName,
          [string]$WordToComplete,
          [System.Management.Automation.Language.CommandAst]$CommandAst,
          [System.Collections.IDictionary]$FakeBoundParameters
        )
        $CompletionResults = [System.Collections.Generic.List[System.Management.Automation.CompletionResult]]::new()
        [Enum]::GetValues([ConsoleColor]) | Where-Object { $_.ToString() -like "$wordToComplete*" } | ForEach-Object {
          $CompletionResults.Add([System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_))
        }
        return $CompletionResults
      })]
    [string]$BackgroundColor,
    # Object to write
    [parameter(Mandatory = $false, ParameterSetName = 'Name', valueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ValueFromRemainingArguments = $true)]
    [Alias('i')]
    [Object[]]$InputObject
  )

  begin {
    $fc = $ExecutionContext.Host.UI.RawUI.ForegroundColor
    $bc = $ExecutionContext.Host.UI.RawUI.BackgroundColor
  }
  process {
    $ConsoleColors = $([ConsoleColor].GetMembers() | Where-Object { $_.MemberType -eq 'Field' -and $null -eq $_.FieldHandle }).Name
    try {
      if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ForegroundColor')) {
        if ($ForegroundColor -in $ConsoleColors) {
          if ($PSCmdlet.ShouldProcess("Host.UI", "Set ForegroundColor")) { $ExecutionContext.Host.UI.RawUI.ForegroundColor = $ForegroundColor }
        } else {
          $PSCmdlet.WriteWarning("$fxn Used Invalid ForegroundColor Parameter.")
        }
      }
      if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('BackgroundColor')) {
        if ($BackgroundColor -in $ConsoleColors) {
          if ($PSCmdlet.ShouldProcess("Host.UI", "Set BackgroundColor")) { $ExecutionContext.Host.UI.RawUI.BackgroundColor = $BackgroundColor }
        } else {
          $PSCmdlet.WriteWarning("$fxn Used Invalid BackgroundColor Parameter.")
        }
      }
      $(if ($PSBoundParameters.Keys.Contains("InputObject")) { $InputObject } else { $input }) | ForEach-Object { Write-Output $_ }
    } catch [System.Management.Automation.SetValueInvocationException] {
      $ErrRecord = New-ErrorRecord -Exception [System.Management.Automation.SetValueInvocationException]::New('Invalid Color Name used. Take a walk, come back, then try using Tab Completion.')
      $PSCmdlet.WriteError($ErrRecord)
    } catch {
      $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]$_)
    } finally {
      $ExecutionContext.Host.UI.RawUI.ForegroundColor = $fc
      $ExecutionContext.Host.UI.RawUI.BackgroundColor = $bc
    }
  }
}
function Write-Invocation {
  <#
    .SYNOPSIS
        Writes on line that shows the PSCmdlet's invocation and the calling functions.
    .DESCRIPTION
        Reads the CallStack using Get-PSCallStack cmdlet and verbose output as one line
    .LINK
        https://github.com/alainQtec/.files/blob/main/src/scripts/Console/Writers/Write-Invocation.ps1
    .EXAMPLE
        $PSCmdletName = $(Get-Variable PSCmdlet -Scope ($NestedPromptLevel + 1) -ValueOnly).MyInvocation.InvocationName
        Write-Invocation -Invocation $MyInvocation-msg "$PSCmdletName Started"
    #>
  param (
    # Invocation Info
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.InvocationInfo]$Invocation = $(Get-Variable MyInvocation -Scope ($NestedPromptLevel + 1) -ValueOnly),
    #number of levels to go back in the call stack
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 99)]
    [int]$level,
    [Switch]$FullStack,
    [switch]$IncludeArgs
  )
  begin { $oeap = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue' }
  Process {
    $Stack = Get-PSCallStack
    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('levels') -and ![string]::IsNullOrEmpty($level.ToString())) {
      $level = [Math]::Min( $level, $Stack.Length - 1 )
      if ($FullStack) {
        $WHOLEstack = @($Stack[$level])
      } else {
        $CommandList = @($Stack[$level] | Select-Object -ExpandProperty Command)
      }
    } else {
      if ($FullStack) {
        $WHOLEstack = @($Stack)
      } else {
        $CommandList = @($Stack | Select-Object -ExpandProperty Command)
      }
    }
    $rStack = & {
      if ($FullStack -and [bool]$WHOLEstack) {
        $stackHash = @{
          Command          = $WHOLEstack.Command
          Position         = $WHOLEstack.Position
          Location         = $WHOLEstack.Location
          FunctionName     = $WHOLEstack.FunctionName
          ScriptLineNumber = $WHOLEstack.ScriptLineNumber
        }
        return $($stackHash.Keys | ForEach-Object { "$_ = $($stackHash.$_)" }) -join ', '
      } else {
        [void][System.Array]::Reverse($CommandList)
        $FilteredL = @($CommandList | ForEach-Object { $i = if (![string]::IsNullOrEmpty($MyInvocation.MyCommand.Name)) { $_.Replace($MyInvocation.MyCommand.Name, '') }else { [string]::Empty }; try { $i.Replace('<ScriptBlock>', '') } catch { $i } })
        $stackLine = $(@(for ($i = 0; $i -lt $FilteredL.Count; $i++) { if ($i -eq 0) { "[$(if ([string]::IsNullOrEmpty($FilteredL[$i])) { 'Command' }else { $FilteredL[$i] })] Started" } else { $FilteredL[$i] } }) -join ' ')
        if ($IncludeArgs) { $stackLine += $('Argslist : ' + $(($Invocation.BoundParameters.Keys | ForEach-Object { "-$_ `"$($Invocation.BoundParameters[$_])`"" }) -join ' ')) }
        $stackLine += ' ...'
        return $stackLine
      }
    }
    Out-Verbose $rStack
  }
  end {
    $ErrorActionPreference = $oeap
  }
}
function Write-Log {
  <#
    .SYNOPSIS
        Write-Log
    .DESCRIPTION
        Log an error message to the log file, the event log and show it on the current console.
        It can also use an error record conataining an exception as input. The exception will be converted into a log message.
        The log message is timestamped so that the file entry has the time the message was written.

    .EXAMPLE
        #Create the Log file
        $Date = (Get-Date).ToString('yyyyMMdd-HHmm')
        $LogFolder = New-Item -ItemType Directory ".\Logs" -Force
        $Log = New-Item -ItemType File "$LogFolder\$($Setup.BaseName)-$Date.log" -Force
        Write-Log -Message "Error during install - exit code: $ExitCode" -Type 3 -Component $Computer -LogFile $Log
    .EXAMPLE
        throw [InvalidVersionException]::new("The input version is invalid, too long or too short.") | Write-Log
    .INPUTS
        [System.String[]]
    .OUTPUTS
        Output (if any)
    .LINK
        https://github.com/alainQtec/.files/blob/main/src/scripts/Console/Loggers/Write-Log.ps1
    #>
  [CmdletBinding(SupportsShouldProcess)]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Invalid rule result')]
  param (
    # The error message.
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Message')]
    [System.String[]]
    $Message,

    # The error record containing an exception to log.
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'ErrorRecord')]
    [System.Management.Automation.ErrorRecord[]]
    $ErrorRecord,

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = '__AllParameterSets')]
    [ValidateSet('INFO', 'ERROR', 'FATAL', 'DEBUG', 'SUCCESS', 'WARNING', 'VERBOSE')]
    [string]$LogLevel = 'INFO',

    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = '__AllParameterSets')]
    [string]$LogFile
  )

  DynamicParam {
    $DynamicParams = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    #region IgnoredArguments
    $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
    $attributes = [System.Management.Automation.ParameterAttribute]::new(); $attHash = @{
      Position                        = 5
      ParameterSetName                = '__AllParameterSets'
      Mandatory                       = $False
      ValueFromPipeline               = $true
      ValueFromPipelineByPropertyName = $true
      ValueFromRemainingArguments     = $true
      HelpMessage                     = 'Allows splatting with arguments that do not apply. Do not use directly.'
      DontShow                        = $False
    }; $attHash.Keys | ForEach-Object { $attributes.$_ = $attHash.$_ }
    $attributeCollection.Add($attributes)
    $RuntimeParam = [System.Management.Automation.RuntimeDefinedParameter]::new("IgnoredArguments", [Object[]], $attributeCollection)
    $DynamicParams.Add("IgnoredArguments", $RuntimeParam)
    #endregion IgnoredArguments
    return $DynamicParams
  }

  begin {
    $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
    $PsCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
    $s = [string][char]32
    $lvlNames = @(); @('INFO', 'ERROR', 'FATAL', 'DEBUG', 'SUCCESS', 'WARNING', 'VERBOSE') | ForEach-Object { $lvlNames += @{$_ = "[$($_.ToString().ToUpper())]" + $s * (9 - $_.length) } }
  }

  process {
    # Fix Any LongPaths Problem by Enabling Developer Mode. (You can't Be writing Logs if you are not A developer !?)
    # $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('LogFile')
    <#
        $Ordner = 'c:\program files'
        $(robocopy.exe $Ordner $env:Temp /zb /e /l /r:1 /w:1 /nfl /ndl /nc /fp /bytes /np /njh) | Where-Object {$_ -like "*Bytes*"} | ForEach-Object { (-split $_)[1] }
        #>
    $LogFile = if ([IO.File]::Exists($LogFile)) { $([System.IO.FileInfo]"$LogFile") } else {
      $newLogPath = [IO.Path]::Combine($([environment]::GetFolderPath('MyDocuments')), 'WindowsPowerShell', 'log', "$((Get-Date -Format o).replace( ':', '.')).log")
      New-Item -Path $newLogPath
    }
    if ($PSCmdlet.ParameterSetName -eq 'ErrorRecord') {
      $Message = @()
      foreach ($rec in $ErrorRecord) {
        $Message += "{0} ({1}: {2}:{3} char:{4})" -f $rec.Exception.Message,
        $rec.FullyQualifiedErrorId,
        $rec.InvocationInfo.ScriptName,
        $rec.InvocationInfo.ScriptLineNumber,
        $rec.InvocationInfo.OffsetInLine
      }
    }
    $TimeStamp = $(Get-Date -Format o).Replace('.', ' ').Replace('-', '/').Replace('T', ' ').Split('+')[0]; $TimeStamp += $s * (30 - $TimeStamp.length)
    $LogMessage = $TimeStamp + $($lvlNames."$LogLevel") + $ProcessName + $s + "PID=${PID} TID=$TID" + $Component + $Message
    if ($PSCmdlet.ShouldProcess("$fxn Writing log entry to $($LogFile.FullName) ...", "$($LogFile.FullName)", "WriteLogEntry")) {
      $FSProps = [PSCustomObject]@{
        Path     = $LogFile.FullName
        Mode     = [system.IO.FileMode]::Append
        Access   = [System.IO.FileAccess]::Write
        Sharing  = [System.IO.FileShare]::ReadWrite
        Encoding = [System.Text.Encoding]::UTF8
      }
      $fileStream = New-Object System.IO.FileStream($FSProps.Path, $FSProps.Mode, $FSProps.Access, $FSProps.Sharing)
      $writer = New-Object System.IO.StreamWriter($fileStream, $FSProps.Encoding)
      try {
        $s = [System.Text.StringBuilder]::new();
        [void]$s.Append($LogMessage);
        $writer.WriteLine($s.ToString())
      } finally {
        Out-Verbose $fxn "Created LogFile $($LogFile.FullName)"
        # Pretty print: $([xml]$LogMessage).Save($LogFile)
        $writer.Dispose()
        $fileStream.Dispose()
      }
    }
  }
  end {}
}
function Write-Marquee {
  <#
    .SYNOPSIS
    Writes text as marquee
    .DESCRIPTION
    Writes text as marquee
    .PARAMETER text
    Specifies the text to write
    .PARAMETER speed
    Specifies the marquee speed (60 ms per default)
    .EXAMPLE
    PS> Write-Marquee "Hello_World"
    .NOTES
    Original Author: Markus Fleschutz / License: CC0
    .LINK
    https://github.com/fleschutz/PowerShell
    .LINK
    https://github.com/alainQtec/.files/blob/dev/src/scripts/Console/Write-Marque.ps1
    #>
  [CmdletBinding()]
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
function Write-Morse {
  <#
	.SYNOPSIS
		Writes text in Morse code
	.DESCRIPTION
		Writes text in Morse code
	.EXAMPLE
		PS C:\> Write-Morse "Hello World"
		Explanation of what the example does
	.NOTES
		Original Author: Author: Markus Fleschutz / License: CC0
	.LINK
		https://github.com/fleschutz/PowerShell
	.LINK
		https://github.com/alainQtec/devHelper/blob/main/Private/devHelper.Cli/Public/Write-Morse.ps1
	#>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelinebyPropertyName = $True)]
    [string]$text = [string]::Empty,
    [Parameter(Mandatory = $false)]
    [int]$speed = 10
  )

  begin {
    $IAP = $InformationPreference; $InformationPreference = 'Continue'
    function gap {
      param([int]$Length)
      for ([int]$i = 1; $i -lt $Length; $i++) {
        Write-Host " " -NoNewline
      }
      Start-Sleep -Milliseconds ($Length * $speed)
    }

    function dot {
      Write-Host "." -NoNewline
      Start-Sleep -Milliseconds $speed # signal
    }

    function dash {
      Write-Host "_" -NoNewline
      Start-Sleep -Milliseconds (3 * $speed) # signal
    }
    function Char2MorseCode {
      param([string]$Char)
      switch ($Char) {
        'A' { dot; gap 1; dash; gap 3 }
        'B' { dash; gap 1; dot; gap 1; dot; gap 1; dot; gap 3 }
        'C' { dash; gap 1; dot; gap 1; dash; gap 1; dot; gap 3 }
        'D' { dash; gap 1; dot; gap 1; dot; gap 3 }
        'E' { dot; gap 3 }
        'F' { dot; gap 1; dot; gap 1; dash; gap 1; dot; gap 3 }
        'G' { dash; gap 1; dash; gap 1; dot; gap 3 }
        'H' { dot; gap 1; dot; gap 1; dot; gap 1; dot; gap 3 }
        'I' { dot; gap 1; dot; gap 3 }
        'J' { dot; gap 1; dash; gap 1; dash; gap 1; dash; gap 3 }
        'K' { dash; gap 1; dot; gap 1; dash; gap 3 }
        'L' { dot; gap 1; dash; gap 1; dot; gap 1; dot; gap 3 }
        'M' { dash; gap 1; dash; gap 3 }
        'N' { dash; gap 1; dot; gap 3 }
        'O' { dash; gap 1; dash; gap 1; dash; gap 3 }
        'P' { dot; gap 1; dash; gap 1; dash; gap 1; dot; gap 3 }
        'Q' { dash; gap 1; dash; gap 1; dot; gap 1; dash; gap 3 }
        'R' { dot; gap 1; dash; gap 1; dot; gap 3 }
        'S' { dot; gap 1; dot; gap 1; dot; gap 3 }
        'T' { dash; gap 3 }
        'U' { dot; gap 1; dot; gap 1; dash; gap 3 }
        'V' { dot; gap 1; dot; gap 1; dot; gap 1; dash; gap 3 }
        'W' { dot; gap 1; dash; gap 1; dash; gap 3 }
        'X' { dash; gap 1; dot; gap 1; dot; gap 1; dash; gap 3 }
        'Y' { dash; gap 1; dot; gap 1; dash; gap 1; dash; gap 3 }
        'Z' { dash; gap 1; dash; gap 1; dot; gap 1; dot; gap 3 }
        '1' { dot; gap 1; dash; gap 1; dash; gap 1; dash; gap 1; dash; gap 3 }
        '2' { dot; gap 1; dot; gap 1; dash; gap 1; dash; gap 1; dash; gap 3 }
        '3' { dot; gap 1; dot; gap 1; dot; gap 1; dash; gap 1; dash; gap 3 }
        '4' { dot; gap 1; dot; gap 1; dot; gap 1; dot; gap 1; dash; gap 3 }
        '5' { dot; gap 1; dot; gap 1; dot; gap 1; dot; gap 1; dot; gap 3 }
        '6' { dash; gap 1; dot; gap 1; dot; gap 1; dot; gap 1; dot; gap 3 }
        '7' { dash; gap 1; dash; gap 1; dot; gap 1; dot; gap 1; dot; gap 3 }
        '8' { dash; gap 1; dash; gap 1; dash; gap 1; dot; gap 1; dot; gap 3 }
        '9' { dash; gap 1; dash; gap 1; dash; gap 1; dash; gap 1; dot; gap 3 }
        '0' { dash; gap 1; dash; gap 1; dash; gap 1; dash; gap 1; dash; gap 3 }
        default { gap 7 } # medium gap (between words)
      }
    }
  }

  process {
    try {
      [char[]]$ArrayOfChars = $text.ToUpper()
      foreach ($Char in $ArrayOfChars) {
        Char2MorseCode $Char
      }
      Write-Host $([Environment]::NewLine)
    } catch {
      # Write-Log $_.Exception.ErrorRecord
      Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
      break
    }
  }

  end {
    $InformationPreference = $IAP
  }
}
function Read-Morse {
  <#
    .SYNOPSIS
        Converts Morse code to text
    .DESCRIPTION
        Converts Morse code input (using dots and dashes) back to readable text
    .EXAMPLE
        PS C:\> Read-Morse "... --- ..."
        Output: SOS
    .NOTES
        Pairs with Write-Morse function for bidirectional conversion
    #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelinebyPropertyName = $True)]
    [string]$morseCode = [string]::Empty
  )

  begin {
    # Create hashtable for Morse code to character mapping
    $morseMap = @{
      '.-'    = 'A'
      '-...'  = 'B'
      '-.-.'  = 'C'
      '-..'   = 'D'
      '.'     = 'E'
      '..-.'  = 'F'
      '--.'   = 'G'
      '....'  = 'H'
      '..'    = 'I'
      '.---'  = 'J'
      '-.-'   = 'K'
      '.-..'  = 'L'
      '--'    = 'M'
      '-.'    = 'N'
      '---'   = 'O'
      '.--.'  = 'P'
      '--.-'  = 'Q'
      '.-.'   = 'R'
      '...'   = 'S'
      '-'     = 'T'
      '..-'   = 'U'
      '...-'  = 'V'
      '.--'   = 'W'
      '-..-'  = 'X'
      '-.--'  = 'Y'
      '--..'  = 'Z'
      '.----' = '1'
      '..---' = '2'
      '...--' = '3'
      '....-' = '4'
      '.....' = '5'
      '-....' = '6'
      '--...' = '7'
      '---..' = '8'
      '----.' = '9'
      '-----' = '0'
    }
  }

  process {
    try {
      # Clean up input - replace underscore with dash for consistency
      $morseCode = $morseCode.Replace('_', '-')

      # Split into words (multiple spaces between words)
      $words = $morseCode -split '   '

      # Process each word
      $result = foreach ($word in $words) {
        # Split word into individual characters (single space between letters)
        $letters = $word -split ' '

        # Convert each letter and join them
        $($letters | ForEach-Object {
            if ($morseMap.ContainsKey($_)) {
              $morseMap[$_]
            } else {
              # Write-Warning "Unknown Morse code sequence: $_"
              '?'
            }
          }) -join ''
      }

      # Join words with spaces
      ($result -join ' ').Replace('?', '')
    } catch {
      Write-Error "Error processing Morse code: $_"
    }
  }
}
function Write-MOTD {
  <#
	.SYNOPSIS
		Writes the message of the day
	.DESCRIPTION
		Writes the message of the day (MOTD)
	.NOTES
		Author: Markus Fleschutz /License: CC0
        https://github.com/fleschutz/PowerShell
	.LINK
		https://github.com/alainQtec/devHelper/blob/main/Private/devHelper.Cli/Public/Write-MOTD.ps1
	#>
  [CmdletBinding()]
  [OutputType([System.string])]
  param (
  )

  Begin {
    $IAp = $InformationPreference ; $InformationPreference = "Continue"
  }

  process {
    if ($IsWindows) {
      # Retrieve information:
      $TimeZone = (Get-TimeZone).id
      $UserName = [Environment]::USERNAME
      $ComputerName = [System.Net.Dns]::GetHostName().ToLower()
      $OSName = "$((Get-CimInstance Win32_OperatingSystem).Caption) Build: $([System.Environment]::OSVersion.Version.Build)" # (Get-CimInstance Win32_OperatingSystem).Name
      $PowerShellVersion = $PSVersionTable.PSVersion
      $PowerShellEdition = $PSVersionTable.PSEdition
      $dt = [datetime]::Now; $day = $dt.ToLongDateString().split(',')[1].trim()
      if ($day.EndsWith('1')) { $day += 'st' }elseif ($day.EndsWith('2')) { $day += 'nd' }elseif ($day.EndsWith('3')) { $day += 'rd' }else { $day += 'th' }
      $CurrentTime = "$day, $($dt.Year) $($dt.Hour):$($dt.Minute)"
      $Uptime = 'S' + $(net statistics workstation | find "Statistics since").Substring(12).Trim();
      $NumberOfProcesses = (Get-Process).Count
      $CPU_Info = $env:PROCESSOR_IDENTIFIER + ' Rev: ' + $env:PROCESSOR_REVISION
      # $Logical_Disk = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object -Property DeviceID -eq $OS.SystemDrive
      $Current_Load = "{0}%" -f $(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average)
      # $Memory_Size = "{0}mb/{1}mb Used" -f (([math]::round($ReturnedValues.Operating_System.TotalVisibleMemorySize / 1KB)) - ([math]::round($ReturnedValues.Operating_System.FreePhysicalMemory / 1KB))), ([math]::round($ReturnedValues.Operating_System.TotalVisibleMemorySize / 1KB))
      # $Disk_Size = "{0}gb/{1}gb Used" -f (([math]::round($ReturnedValues.Logical_Disk.Size / 1GB) - [math]::round($ReturnedValues.Logical_Disk.FreeSpace / 1GB))), ([math]::round($ReturnedValues.Logical_Disk.Size / 1GB))
      # Print Results
      [Console]::Write([Environment]::NewLine)
      Write-Host " ,.=:^!^!t3Z3z., " -f Red
      Write-Host " :tt:::tt333EE3 " -f Red
      Write-Host " Et:::ztt33EEE " -f Red -NoNewline
      Write-Host " @Ee., ..,     " -f green -NoNewline
      Write-Host "      Time: " -f Red -NoNewline
      Write-Host "$CurrentTime" -f Cyan
      Write-Host " ;tt:::tt333EE7" -f Red -NoNewline
      Write-Host " ;EEEEEEttttt33# " -f Green -NoNewline
      Write-Host "    Timezone: " -f Red -NoNewline
      Write-Host "$TimeZone" -f Cyan
      Write-Host " :Et:::zt333EEQ." -NoNewline -f Red
      Write-Host " SEEEEEttttt33QL " -NoNewline -f Green
      Write-Host "   User: " -NoNewline -f Red
      Write-Host "$UserName" -f Cyan
      Write-Host " it::::tt333EEF" -NoNewline -f Red
      Write-Host " @EEEEEEttttt33F " -NoNewline -f Green
      Write-Host "    Hostname: " -NoNewline -f Red
      Write-Host "$ComputerName" -f Cyan
      Write-Host " ;3=*^``````'*4EEV" -NoNewline -f Red
      Write-Host " :EEEEEEttttt33@. " -NoNewline -f Green
      Write-Host "   OS: " -NoNewline -f Red
      Write-Host "$OSName" -f Cyan
      Write-Host " ,.=::::it=., " -NoNewline -f Cyan
      Write-Host "``" -NoNewline -f Red
      Write-Host " @EEEEEEtttz33QF " -NoNewline -f Green
      Write-Host "    Kernel: " -NoNewline -f Red
      Write-Host "NT " -NoNewline -f Cyan
      Write-Host "$Kernel_Info" -f Cyan
      Write-Host " ;::::::::zt33) " -NoNewline -f Cyan
      Write-Host " '4EEEtttji3P* " -NoNewline -f Green
      Write-Host "     Uptime: " -NoNewline -f Red
      Write-Host "$Uptime" -f Cyan
      Write-Host " :t::::::::tt33." -NoNewline -f Cyan
      Write-Host ":Z3z.. " -NoNewline -f Yellow
      Write-Host " ````" -NoNewline -f Green
      Write-Host " ,..g. " -NoNewline -f Yellow
      Write-Host "   PowerShell: " -NoNewline -f Red
      Write-Host "$PowerShellVersion $PowerShellEdition" -f Cyan
      Write-Host " i::::::::zt33F" -NoNewline -f Cyan
      Write-Host " AEEEtttt::::ztF " -NoNewline -f Yellow
      Write-Host "    CPU: " -NoNewline -f Red
      Write-Host "$CPU_Info" -f Cyan
      Write-Host " ;:::::::::t33V" -NoNewline -f Cyan
      Write-Host " ;EEEttttt::::t3 " -NoNewline -f Yellow
      Write-Host "    Processes: " -NoNewline -f Red
      Write-Host "$NumberOfProcesses" -f Cyan
      Write-Host " E::::::::zt33L" -NoNewline -f Cyan
      Write-Host " @EEEtttt::::z3F " -NoNewline -f Yellow
      Write-Host "    Current Load: " -NoNewline -f Red
      Write-Host "$Current_Load" -f Cyan
      Write-Host " {3=*^``````'*4E3)" -NoNewline -f Cyan
      Write-Host " ;EEEtttt:::::tZ`` " -NoNewline -f Yellow
      Write-Host "   Memory: " -NoNewline -f Red
      Write-Host "$Memory_Size" -f Cyan
      Write-Host "              ``" -NoNewline -f Cyan
      Write-Host " :EEEEtttt::::z7 " -NoNewline -f Yellow
      Write-Host "    System Volume: " -NoNewline -f Red
      Write-Host "$Disk_Size" -f Cyan
      Write-Host "                 'VEzjt:;;z>*`` " -f Yellow
      [Console]::Write([Environment]::NewLine)
    }
  }

  end {
    $InformationPreference = $IAp
  }
}

function Write-RGB {
  <#
    .SYNOPSIS
        Write to the console in 24-bit colors!
    .DESCRIPTION
        This function lets you write to the console using 24-bit color depth.
        You can specify colors using its RGB values.
    .EXAMPLE
        Write-RGB 'Hello World'
        Will write the text using the default colors.
    .EXAMPLE
        Write-RGB 'Hello world' -f Pink
        Will write the text in a pink foreground color.
    .EXAMPLE
        Write-RGB 'Hello world' -f violet -BackgroundColor Olive
        Will write the text in a pink foreground color and an olive background color.
    .EXAMPLE
        Write-RGB $alainQtec_ascii -f SlateBlue -BackgroundColor black ; $Host.UI.WriteLine([Environment]::NewLine)
    .LINK
        Online version : https://github.com/alainQtec/.files/blob/main/src/scripts/Console/Writers/Write-RGB.ps1
    #>
  [CmdletBinding(DefaultParameterSetName = 'Name')]
  param (
    # The text you want to write.
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrEmpty()]
    [string]$Text,

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Name')]
    $ForegroundColor,

    # The foreground color of the text. Defaults to white.
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'Code')]
    [rgb]$Foreground = [rgb]::new(255, 255, 255),

    [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'Name')]
    $BackgroundColor,

    # The background color of the text. Defaults to PowerShell Blue.
    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'Code')]
    [rgb]$Background = [rgb]::new(1, 36, 86),

    # No newline after the text.
    [switch]$NoNewLine
  )
  Begin {
    $escape = [char]27 + '['
    $resetAttributes = "$($escape)0m"
    $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
    $IAP = $InformationPreference; $InformationPreference = 'Continue'
  }
  Process {
    $psBuild = $PSVersionTable.PSVersion.Build
    [double]$VersionNum = $($PSVersionTable.PSVersion.ToString().split('.')[0..1] -join '.')
    if ([bool]$($VersionNum -le [double]5.1)) {
      if ($PsCmdlet.ParameterSetName -eq 'Name') {
        $f = "$($escape)38;2;$($colors.$ForegroundColor.Red);$($colors.$ForegroundColor.Green);$($colors.$ForegroundColor.Blue)m"
        $b = "$($escape)48;2;$($colors.$BackgroundColor.Red);$($colors.$BackgroundColor.Green);$($colors.$BackgroundColor.Blue)m"
      } elseif ($PsCmdlet.ParameterSetName -eq 'Code') {
        $f = "$($escape)38;2;$($Foreground.Red);$($Foreground.Green);$($Foreground.Blue)m"
        $b = "$($escape)48;2;$($Background.Red);$($Background.Green);$($Background.Blue)m"
      }
      if ([bool](Get-Command Write-Host -ErrorAction SilentlyContinue)) {
        Write-Host ($f + $b + $Text + $resetAttributes) -NoNewline:$NoNewLine
      } else {
        Write-Host ($f + $b + $Text + $resetAttributes) -NoNewline:$NoNewLine
      }
    } else {
      $Host.UI.WriteLine($Text)
      Write-Error "$fxn This function can only work with PowerShell versions lower than '5.1 build 14931' or above.`nBut yours is '$VersionNum' build '$psBuild'"
    }
  }
  End {
    $InformationPreference = $IAP
  }
}
function Write-ROT13 {
  <#
	.SYNOPSIS
		Writes text encoded or decoded with ROT13
	.EXAMPLE
		(Set-Variable -Name Enc -Value $(Write-ROT13 -text "Hello World!") -PassThru).Value
		$Enc | Write-ROT13
	.NOTES
		Original Author: Author: Markus Fleschutz / License: CC0
	.LINK
		https://github.com/fleschutz/PowerShell
	.LINK
		https://github.com/alainQtec/devHelper/blob/main/Private/devHelper.Cli/Public/Write-ROT13.ps1
	#>
  [CmdletBinding()]
  param (
    # Parameter help description
    [Parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelinebyPropertyName = $True)]
    [string]$text = [string]::Empty
  )

  process {
    try {
      $text.ToCharArray() | ForEach-Object {
        if ((([int] $_ -ge 97) -and ([int] $_ -le 109)) -or (([int] $_ -ge 65) -and ([int] $_ -le 77))) {
          $Result += [char] ([int] $_ + 13);
        } elseif ((([int] $_ -ge 110) -and ([int] $_ -le 122)) -or (([int] $_ -ge 78) -and ([int] $_ -le 90))) {
          $Result += [char] ([int] $_ - 13);
        } else {
          $Result += $_
        }
      }
      Write-Output $Result
    } catch {
      # Write-Log $_.Exception.ErrorRecord
      Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
      break
    }
  }

  end {
  }
}
function Write-StringArray {
  <#
    .SYNOPSIS
        Takes [string] or [string[]] input and writes the code that would create a string array with that information.
    .DESCRIPTION
        Takes [string] or [string[]] input and writes the code that would create a string array with that information. Encloses strings in single quotes replacing any existing single quotes with 2 x single quotes.
    .PARAMETER Text
        The text to be included in the string array
    .PARAMETER VariableName
        The name of the string array variable
    .PARAMETER ExcludeDollarSign
        Switch to exclude the dollar sign in front of the variable name. Useful when trying to create string array for *.psd1 files
    .EXAMPLE
        Write-StringArray -Text Hello,World,"it's me"

        Would return
        $StringArray = @(
            'Hello',
            'World',
            'it''s me'
        )
    .EXAMPLE
        1,2,99 | Write-StringArray -VariableName MyVariable

        Would return
        $MyVariable = @(
            '1',
            '2',
            '99'
        )
    .EXAMPLE
        1,2,99 | Write-StringArray -VariableName MyVariable -ExcludeDollarSign

        Would return
        MyVariable = @(
            '1',
            '2',
            '99'
        )
    .OUTPUTS
        [string[]]
    #>
  [CmdletBinding(ConfirmImpact = 'None')]
  [OutputType('string')]
  Param(
    [Parameter(Mandatory, HelpMessage = 'Enter a series of values', Position = 0, ValueFromPipeline)]
    [string[]] $Text,

    [string] $VariableName = 'StringArray',

    [switch] $ExcludeDollarSign
  )
  #endregion Parameter

  begin {
    Write-Invocation $MyInvocation
    if ($ExcludeDollarSign) {
      $ReturnVal = "$VariableName = @(`n"
    } else {
      $ReturnVal = "`$$VariableName = @(`n"
    }
  }

  process {
    foreach ($CurLine in $Text) {
      $ReturnVal += "    `'$($CurLine -replace "`'", "`'`'")',`n"
    }
  }

  end {
    $ReturnVal = $ReturnVal -replace ",`n$", "`n"
    $ReturnVal += ')'
    Write-Output -InputObject $ReturnVal
    Out-Verbose $fxn "Complete."
  }
}
function Write-StringHash {
  <#
.SYNOPSIS
    Takes [hashtable] input and writes the code that would create a hashtable with that information.
.DESCRIPTION
    Takes [hashtable] input and writes the code that would create a hashtable with that information.
.PARAMETER Hash
    The hash to be defined
.PARAMETER VariableName
    The name of the hash table variable
.PARAMETER Ordered
    Switch to use [ordered] when created hash, will sort entries by value
.PARAMETER QuoteField
    Switch to enclose the name and value attributes in single quotes
.EXAMPLE
    @{ A =1; B=2; C=3} | Write-StringHash

    $StringHash = @{
        C = 3
        B = 2
        A = 1
    }
.EXAMPLE
    @{ A =1; B=2; C=3} | Write-StringHash -QuoteField

    $StringHash = @{
        'C' = '3'
        'B' = '2'
        'A' = '1'
    }
.EXAMPLE
    @{ A =1; B=2; C=3} | Write-StringHash -Ordered

    $StringHash = ([ordered] @{
        A = 1
        B = 2
        C = 3
    })
.EXAMPLE
    @{A =1; C=3; B=2} | Write-StringHash -Ordered -VariableName MyHashTable

    $MyHashTable = ([ordered] @{
        A = 1
        B = 2
        C = 3
    })
.OUTPUTS
    [string[]]
#>

  #region Parameter
  [CmdletBinding(ConfirmImpact = 'None')]
  [OutputType('string')]
  Param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [hashtable] $Hash,

    [string] $VariableName = 'StringHash',

    [switch] $Ordered,

    [switch] $QuoteField
  )
  #endregion Parameter

  begin {
    Write-Invocation $MyInvocation
    $ReturnVal = @()
  }

  process {
    if ($Ordered) {
      $ReturnVal += "`$$VariableName = ([ordered] @{"
      $WorkingHash = $Hash.GetEnumerator() | Select-Object -Property Name, Value | Sort-Object -Property Value, Name
    } else {
      $ReturnVal += "`$$VariableName = @{"
      $WorkingHash = $Hash.GetEnumerator() | Select-Object -Property Name, Value
    }
    foreach ($CurEntry in $WorkingHash) {
      if ($QuoteField) {
        $ReturnVal += $CurEntry | ForEach-Object { "    '{0}' = '{1}'" -f $_.Name, $_.value }
      } else {
        $ReturnVal += $CurEntry | ForEach-Object { '    {0} = {1}' -f $_.Name, $_.value }
      }
    }
    if ($Ordered) {
      $ReturnVal += '})'
    } else {
      $ReturnVal += '}'
    }
    Write-Output -InputObject $ReturnVal
  }

  end {
    Out-Verbose $fxn "Complete."
  }
}
function Write-TextMenu {
  <#
.SYNOPSIS
    Creates the logic for a new simple text based menu. Originally published as script New-TextMenu in the PowerShellGallery
.DESCRIPTION
    Creates the logic for a new simple text based menu. Originally published as script New-TextMenu in the PowerShellGallery
.PARAMETER Option
    An array of [string] indicating the menu options. If you need to create a menu with a single option enclose the option in @().
.PARAMETER Title
    The title of the menu. Defaults to 'Menu Title'.
.PARAMETER VariableName
    The name of the choice variable. Defaults to 'Choice'.
.PARAMETER TestMenu
    If this switch is enabled then the menu is saved to a temporary file and run.
.PARAMETER Clipboard
    If this switch is enabled then the menu logic is copied to the clipboard.
.NOTES
    * The resulting output is a relatively small string array so the shorthand way of adding
      to an array ( += ) is used.
    * Removed extraneous temporary file.
    * Cleaned up formatting.
    * Only set of parameters so removing ParameterSetName and DefaultParameterSetName
.EXAMPLE
    Write-TextMenu -Title 'Menu Title' -Option 'One', 'Two', 'Three'
    Creates a 3 option menu.
.EXAMPLE
    Write-TextMenu -Title 'My Menu' -Option 'One' -VariableName 'Choice2'

    Creates a 1 option menu that looks like:

$Choice2 = ''
while ($Choice2 -ne 'q') {
    Write-Host 'My Menu'
    Write-Host '======='
    Write-Host ' '
    Write-Host '1 - One'
    Write-Host 'Q - Quit'
    Write-Host ' '
    $Choice2 = Read-Host 'Selection'
    switch ($Choice2) {
        q { 'Exit message and code' }
        1 { 'Option 1 code' }
        default { Write-Host 'Please enter a valid selection' }
    }
}
.EXAMPLE
    Write-TextMenu -Option 'Uno'

    Creates a 1 option menu that looks like:

$Choice = ''
while ($Choice -ne 'q') {
    Write-Host 'Menu Title'
    Write-Host '=========='
    Write-Host ' '
    Write-Host '1 - Uno'
    Write-Host 'Q - Quit'
    Write-Host ' '
    $Choice = Read-Host 'Selection'
    switch ($Choice) {
        q { 'Exit message and code' }
        1 { 'Option 1 code' }
        default { Write-Host 'Please enter a valid selection' }
    }
}
.OUTPUTS
    [string[]]
.LINK
    about_while
    Write-Host
    Read-Host
    about_switch
#>

  #region Parameter
  [cmdletbinding(ConfirmImpact = 'Low')]
  [OutputType([string[]])]
  Param(
    [Parameter(Mandatory, HelpMessage = 'Enter the text of the menu option.', Position = 0, ValueFromPipeline = $True)]
    [string[]] $Option,
    [Parameter(Position = 1)]
    [string] $Title = 'Menu Title',
    [Parameter(Position = 2)]
    [string] $VariableName = 'Choice',
    [Parameter()]
    [switch] $TestMenu,
    [Parameter()]
    [switch] $Clipboard
  )
  #endregion Parameter

  begin {
    Write-Invocation $MyInvocation
  }

  process {
    $result = [string[]] @()
    $result += "`$$VariableName = ''"
    $result += "while (`$$VariableName -ne 'q') {"
    $result += "    Write-Host '$title'"
    $result += "    Write-Host '$('='*$title.length)'"
    $result += "    Write-Host ' '"
    for ($i = 0; $i -lt $option.count; $i++) {
      $result += "    Write-Host '$($i+1) - $($option[$i])'"
    }
    $result += "    Write-Host 'Q - Quit'"
    $result += "    Write-Host ' '"
    $result += "    `$$VariableName = Read-Host 'Selection'"
    $result += "    switch (`$$VariableName) {"
    $result += "        q { 'Exit message and code' }"
    #$result += "             break }"
    for ($i = 0; $i -lt $option.count; $i++) { $result += "        $($i+1) { 'Option $($i+1) code' }" }
    $result += "        default { Write-Host 'Please enter a valid selection' }"
    $result += '    }'
    $result += '}'
  }

  end {
    if ($TestMenu) {
      $tempFilename = New-TemporaryFile
      Remove-Item -Path $tempFilename
      $tempFilename = $tempFilename.Directory.ToString() + '\' + $tempFilename.BaseName + '.ps1'
      $result | Out-File -FilePath $tempFilename
      & $tempFilename
      Remove-Item -Path $tempFilename
    } else {
      Write-Output -InputObject $result
    }
    if ($Clipboard) {
      $result | clip.exe
      Write-Warning -Message 'Menu logic copied to clipboard'
    }
    Out-Verbose $fxn "Complete."
  }
}
function Write-TitleCase {
  [cmdletbinding()]
  [OutputType([string])]
  param(
    [parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$String,
    [switch]$ToLowerFirst,
    [switch]$IncludeInput
  )

  process {
    $TextInfo = (Get-Culture).TextInfo
    foreach ($curString in $String) {
      if ($ToLowerFirst) {
        $ReturnVal = $TextInfo.ToTitleCase($curString.ToLower())
      } else {
        $ReturnVal = $TextInfo.ToTitleCase($curString)
      }
      Write-Output -InputObject $ReturnVal
    }
  }
}
function Write-Typewriter {
  <#
	.SYNOPSIS
		Writes text with the typewriter effect
	.EXAMPLE
		$random_Paragraph = Get-LoremIpsum
		$random_Paragraph | Write-Typewriter
	.LINK
		https://github.com/alainQtec/devHelper/blob/main/Private/devHelper.Cli/Public/Write-Typewriter.ps1
	#>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelinebyPropertyName = $True)]
    [string]$text = [string]::Empty,
    [int]$speed = 200
  )
  Begin {
    $IAP = $InformationPreference; $InformationPreference = 'Continue'
  }

  process {
    $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
    try {
      $text -split '' | ForEach-Object {
        Write-Host -NoNewline $_
        Start-Sleep -Milliseconds $(1 + [System.Random]::new().Next($speed))
      }
    } catch {
      Write-Host "Error: $($Error[0]) $fxn : $($_.InvocationInfo.ScriptLineNumber))"
      break
    }
  }

  end {
    $InformationPreference = $IAP
  }
}