function Write-cLog {
  #.SYNOPSIS
  #     Emits a log record
  # .DESCRIPTION
  #     This function write a log record to configured targets with the matching level
  # .PARAMETER Level
  #     The log level of the message. Valid values are DEBUG, INFO, WARNING, ERROR, NOTSET
  #     Other custom levels can be added and are a valid value for the parameter
  #     INFO is the default
  # .PARAMETER Message
  #     The text message to write
  # .PARAMETER Arguments
  #     An array of objects used to format <Message>
  # .PARAMETER Body
  #     An object that can contain additional log metadata (used in target like ElasticSearch)
  # .PARAMETER ExceptionInfo
  #     An optional ErrorRecord
  # .EXAMPLE
  #     PS C:\> Write-cLog 'Hello, World!'
  # .EXAMPLE
  #     PS C:\> Write-cLog -Level ERROR -Message 'Hello, World!'
  # .EXAMPLE
  #     PS C:\> Write-cLog -Level ERROR -Message 'Hello, {0}!' -Arguments 'World'
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
    if (![string]::IsNullOrEmpty($invocationInfo.ScriptName)) {
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
