function Invoke-RetriableCommand {
  # .SYNOPSIS
  #   Runs Retriable Commands
  # .DESCRIPTION
  #   Retries a script process for a number of times or until it completes without terminating errors.
  #   All Unnamed arguments will be passed as arguments to the script
  # .NOTES
  #   Information or caveats about the function e.g. 'This function is not supported in Linux'
  # .LINK
  #   https://github.com/alainQtec/PsRunner/blob/main/Public/Invoke-RetriableCommand.ps1
  # .EXAMPLE
  #   Invoke-RetriableCommand -ScriptBlock $downloadScript -Verbose
  #   Retries the download script 3 times (default)
  [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ScriptBlock')]
  [OutputType([PSCustomObject])][Alias('Invoke-rtCommand')]
  param (
    [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ScriptBlock')]
    [Alias('Script')]
    [ScriptBlock]$ScriptBlock,

    [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'Command')]
    [Alias('Command', 'CommandPath')]
    [string]$FilePath,

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = '__AllParameterSets')]
    [Object[]]$ArgumentList,

    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = '__AllParameterSets')]
    [CancellationToken]$CancellationToken = [CancellationToken]::None,

    [Parameter(Mandatory = $false, Position = 3, ParameterSetName = '__AllParameterSets')]
    [Alias('Retries', 'MaxRetries')]
    [int]$MaxAttempts = 3,

    [Parameter(Mandatory = $false, Position = 4, ParameterSetName = '__AllParameterSets')]
    [int]$MillisecondsAfterAttempt = 500,

    [Parameter(Mandatory = $false, Position = 5, ParameterSetName = '__AllParameterSets')]
    [string]$Message = "Running $('[' + $MyInvocation.MyCommand.Name + ']')"
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
    # $attributeCollection.Add([System.Management.Automation.ValidateSetAttribute]::new([System.Object[]]$ValidateSetOption))
    # $attributeCollection.Add([System.Management.Automation.ValidateRangeAttribute]::new([System.Int32[]]$ValidateRange))
    # $attributeCollection.Add([System.Management.Automation.ValidateNotNullOrEmptyAttribute]::new())
    # $attributeCollection.Add([System.Management.Automation.AliasAttribute]::new([System.String[]]$Aliases))
    $RuntimeParam = [System.Management.Automation.RuntimeDefinedParameter]::new("IgnoredArguments", [Object[]], $attributeCollection)
    $DynamicParams.Add("IgnoredArguments", $RuntimeParam)
    return $DynamicParams
  }

  begin {
    [System.Management.Automation.ActionPreference]$eap = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    $fxn = '[PsRunner]'; $PsBoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
    $Output = [string]::Empty
    $Result = [PSCustomObject]@{
      Output      = $Output
      IsSuccess   = [bool]$IsSuccess # $false in this case
      ErrorRecord = $null
    }
  }

  process {
    $Attempts = 1; $CommandStartTime = Get-Date
    while (($Attempts -le $MaxAttempts) -and !$Result.IsSuccess) {
      $Retries = $MaxAttempts - $Attempts
      if ($cancellationToken.IsCancellationRequested) {
        Write-Verbose "$fxn CancellationRequested when $Retries retries were left."
        throw
      }
      try {
        $downloadAttemptStartTime = Get-Date
        if ($PSCmdlet.ShouldProcess("$fxn Retry Attempt # $Attempts/$MaxAttempts ...", ' ', '')) {
          if ($PSCmdlet.ParameterSetName -eq 'Command') {
            try {
              $Output = & $FilePath $ArgumentList
              $IsSuccess = [bool]$?
            } catch {
              $IsSuccess = $false
              $ErrorRecord = $_.Exception.ErrorRecord
              # Write-Log $_.Exception.ErrorRecord
              Write-Verbose "$fxn Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
            }
          } else {
            $Output = Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
            $IsSuccess = [bool]$?
          }
        }
      } catch {
        $IsSuccess = $false
        $ErrorRecord = [System.Management.Automation.ErrorRecord]$_
        # Write-Log $_.Exception.ErrorRecord
        Write-Verbose "$fxn Error encountered after $([math]::Round(($(Get-Date) - $downloadAttemptStartTime).TotalSeconds, 2)) seconds"
      } finally {
        $Result = [PSCustomObject]@{
          Output      = $Output
          IsSuccess   = $IsSuccess
          ErrorRecord = $ErrorRecord
        }
        if ($Retries -eq 0 -or $Result.IsSuccess) {
          $ElapsedTime = [math]::Round(($(Get-Date) - $CommandStartTime).TotalSeconds, 2)
          $EndMsg = $(if ($Result.IsSuccess) { "Completed Successfully. Total time elapsed $ElapsedTime" } else { "Completed With Errors. Total time elapsed $ElapsedTime. Check the log file $LogPath" })
        } elseif (!$cancellationToken.IsCancellationRequested -and $Retries -ne 0) {
          Write-Verbose "$fxn Waiting $MillisecondsAfterAttempt seconds before retrying. Retries left: $Retries"
          [System.Threading.Thread]::Sleep($MillisecondsAfterAttempt);
        }
        $Attempts++
      }
    }
  }

  end {
    Write-Verbose "$fxn $EndMsg"
    $ErrorActionPreference = $eap;
    return $Result
  }
}

<# inspiration
function Invoke-Program {
	# .SYNOPSIS
	# This is a helper function that will invoke the SQL installers via command-line.
	# .EXAMPLE
	# PS> Invoke-Program -FilePath C:\file.exe -ComputerName SRV1
  [CmdletBinding()]
  [OutputType([System.Management.Automation.PSObject])]
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath,

    [Parameter(Mandatory)]
    [string]$ComputerName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ArgumentList,

    [Parameter()]
    [bool]$ExpandStrings = $false,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$WorkingDirectory,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [uint32[]]$SuccessReturnCodes = @(0, 3010)
  )
  begin {
    $ErrorActionPreference = 'Stop'
  }
  process {
    try {
      Write-Verbose -Message "Acceptable success return codes are [$($SuccessReturnCodes -join ',')]"

      $scriptBlock = {
        $VerbosePreference = $using:VerbosePreference

        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo;
        $processStartInfo.FileName = $Using:FilePath;
        if ($Using:ArgumentList) {
          $processStartInfo.Arguments = $Using:ArgumentList;
          if ($Using:ExpandStrings) {
            $processStartInfo.Arguments = $ExecutionContext.InvokeCommandWithCred.ExpandString($Using:ArgumentList);
          }
        }
        if ($Using:WorkingDirectory) {
          $processStartInfo.WorkingDirectory = $Using:WorkingDirectory;
          if ($Using:ExpandStrings) {
            $processStartInfo.WorkingDirectory = $ExecutionContext.InvokeCommandWithCred.ExpandString($Using:WorkingDirectory);
          }
        }
        $processStartInfo.UseShellExecute = $false; # This is critical for installs to function on core servers
        $ps = New-Object System.Diagnostics.Process;
        $ps.StartInfo = $processStartInfo;
        Write-Verbose -Message "Starting process path [$($processStartInfo.FileName)] - Args: [$($processStartInfo.Arguments)] - Working dir: [$($Using:WorkingDirectory)]"
        $null = $ps.Start();
        if (!$ps) {
          throw "Error running program: $($ps.ExitCode)"
        } else {
          $ps.WaitForExit()
        }

        # Check the exit code of the process to see if it succeeded.
        if ($ps.ExitCode -notin $Using:SuccessReturnCodes) {
          throw "Error running program: $($ps.ExitCode)"
        }
      }

      # Run program on specified computer.
      Write-Verbose -Message "Running command line [$FilePath $ArgumentList] on $ComputerName"

      Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptblock
    } catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }
  }
}
#>
