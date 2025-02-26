function Write-Console {
  # .SYNOPSIS
  #   Writes to the console in 24-bit colors.
  # .DESCRIPTION
  #   Writes colored output on the console using 24-bit color depth.
  #   You can specify colors using color names or RGB values.
  # .EXAMPLE
  #   Write-Console 'Hello World'
  #   Will write the Object using the default colors.
  # .EXAMPLE
  #   Write-Console 'Hello world' -f Pink
  #   Will write the Object in a pink foreground color.
  # .EXAMPLE
  #   [string]::Join([char]10, (tree | Out-String)) | Write-Console -f SlateBlue
  #   Will write the string result of the tree command in a SlateBlue foreground color.
  # .LINK
  #   https://github.com/chadnpc/cliHelper.Core/blob/main/Public/Write-Console.ps1
  # .INPUTS
  #   String
  # .OUTPUTS
  #   String to pipline if -Passthru is used.
  [CmdletBinding(DefaultParameterSetName = 'Name')]
  [OutputType([string])][Alias('Write-RGB')]
  param (
    # The Object you want to write.
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrEmpty()]
    [string]$Text,

    # foreground color name of the object you want to write.
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'Name')]
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
        [ConsoleWriter]::Colors.Where({ $_ -like "$wordToComplete*" }) |
          ForEach-Object {
            $CompletionResults.Add([System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_))
          }
        return $CompletionResults
      })][ValidateScript( { return [bool][color]$_ })]
    [string]$ForegroundColor = "LightGray",

    # The rgb foreground color of the Object. Defaults to LightGray.
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'Code')]
    [Alias('fr')]
    [rgb]$Foreground = [rgb]::new(211, 211, 211),

    # Not always needed, so defaults to transparent.
    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'Name')]
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
        [ConsoleWriter]::Colors.Where({ $_ -like "$wordToComplete*" }) |
          ForEach-Object {
            $CompletionResults.Add([System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_))
          }
        return $CompletionResults
      })][ValidateScript( { return [bool][color]$_ })]
    [string]$BackgroundColor,

    # The background color of the Object. Defaults to transparent if not set.
    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'Code')]
    [Alias('br')]
    [rgb]$Background = [rgb]::new(0, 0, 0),

    # No newline after the Object.
    [Alias('nn')]
    [switch]$NoNewLine,

    # Adds typewriter animation
    [Alias('a')]
    [switch]$Animate,

    # Write the Object to the pipeline
    [switch]$PassThru
  )

  DynamicParam {
    $DynamicParams = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
    $attributes = [System.Management.Automation.ParameterAttribute]::new(); $attHash = @{
      Position                        = 6
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
    return $DynamicParams
  }

  Begin {
    $escape = [char]27 + '['
    $f = ''; $b = ''; $resetAttributes = "$($escape)0m"
    $IAP = $InformationPreference; $InformationPreference = 'Continue'
  }
  Process {
    if ($PsCmdlet.ParameterSetName -eq 'Name') {
      $f = "$($escape)38;2;$([color]::$ForegroundColor.Red);$([color]::$ForegroundColor.Green);$([color]::$ForegroundColor.Blue)m"
      if ($BackgroundColor) {
        $b = "$($escape)48;2;$([color]::$BackgroundColor.Red);$([color]::$BackgroundColor.Green);$([color]::$BackgroundColor.Blue)m"
      }
    } elseif ($PsCmdlet.ParameterSetName -eq 'Code') {
      $f = "$($escape)38;2;$($Foreground.Red);$($Foreground.Green);$($Foreground.Blue)m"
      if ($Background) {
        $b = "$($escape)48;2;$($Background.Red);$($Background.Green);$($Background.Blue)m"
      }
    }
    $str = $f + $b + $Text + $resetAttributes
    if (!$NoNewLine.IsPresent) {
      $Animate ? $([void][ConsoleWriter]::write($str); [Console]::WriteLine()) : ([Console]::WriteLine($str))
    } else {
      $Animate ? $([void][ConsoleWriter]::write($str)) : ([Console]::Write($str))
    }
  }
  End {
    $InformationPreference = $IAP
    if ($PassThru.IsPresent) { return $Text }
  }
}
