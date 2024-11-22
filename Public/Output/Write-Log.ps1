function Write-Log {
  # .SYNOPSIS
  #     Write-Log
  # .DESCRIPTION
  #     Log an error message to the log file, the event log and show it on the current console.
  #     It can also use an error record conataining an exception as input. The exception will be converted into a log message.
  #     The log message is timestamped so that the file entry has the time the message was written.
  #
  # .EXAMPLE
  #     #Create the Log file
  #     $Date = (Get-Date).ToString('yyyyMMdd-HHmm')
  #     $LogFolder = New-Item -ItemType Directory ".\Logs" -Force
  #     $Log = New-Item -ItemType File "$LogFolder\$($Setup.BaseName)-$Date.log" -Force
  #     Write-Log -m "Error during install - exit code: $ExitCode" -Type 3 -f $Log
  #
  # .EXAMPLE
  #     throw [InvalidVersionException]::new("The input version is invalid, too long or too short.") | Write-Log
  # .INPUTS
  #     [System.String[]]
  # .OUTPUTS
  #     Output (if any)
  [CmdletBinding(SupportsShouldProcess)]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '', Justification = 'Invalid rule result')]
  param (
    # The error message.
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Message')]
    [System.String[]][Alias('m')]
    $Messages,

    # The error record containing an exception to log.
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'ErrorRecord')]
    [System.Management.Automation.ErrorRecord[]]
    $ErrorRecord,

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = '__AllParameterSets')]
    [ValidateSet('INFO', 'ERROR', 'FATAL', 'DEBUG', 'SUCCESS', 'WARNING', 'VERBOSE')]
    [Alias('l')][string]
    $LogLevel = 'INFO',

    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = '__AllParameterSets')]
    [Alias('f')][string]
    $LogFile,

    [Parameter(Mandatory = $false, Position = 3, ParameterSetName = '__AllParameterSets')]
    [Alias('s')][switch]
    $Success
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
    $colors = @{ true = 'Green'; false = 'Red' }
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
    Write-Host $LogMessage -f $colors.($Success.IsPresent)
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
