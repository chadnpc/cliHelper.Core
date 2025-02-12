using namespace System.Management.Automation
using namespace System.Collections.ObjectModel

#Requires -Psedition Core
function Invoke-RetriableCommand {
  <#
  .SYNOPSIS
    Runs Retriable Commands
  .DESCRIPTION
    Retries a script or command for a number of times (3 times by default) or until it succeeds.
    This is handy if you know a command or script will fail sometimes and you want to retry it a few times.
    In the return value, example: $result.HasErrors tells you if there were any errors during retries.
    See: Get-Help Invoke-RetriableCommand -Examples
  .EXAMPLE
   # Run a simple ScriptBlock with Attempts
   $result = Invoke-RetriableCommand -ScriptBlock {
       Write-Output "Running retry test..."
       Start-Sleep -Seconds 1

       # Simulate success after a few retries using current second
       if ([DateTime]::Now.Second % 5 -eq 0) {
          return [PSCustomObject]@{ StatusCode = 200; Message = "Success" }
       } else {
          throw "Simulated failure. Reason: $([DateTime]::Now.Second)%5 -eq 0 is false"
        }
    } -MaxAttempts 4 -Message "Simulate success after a few attempts"

  .EXAMPLE
   # Retry a remote command on a target machine
   $scriptBlock = {
       param($arg1)
       Write-Output "Processing on remote computer with argument: $arg1"
       # Simulate conditional success
       if ($arg1 -eq 'SuccessValue') {
           return 0 # Success return code
       }
       throw "Execution failed on remote machine"
   }
   $result = Invoke-RetriableCommand -ComputerName 'Server01' -ScriptBlock $scriptBlock -ArgumentList 'SuccessValue' -MaxAttempts 3 -Message "Executing remote retry"

  .EXAMPLE
   # Retry execution of a local file/script
   $result = Invoke-RetriableCommand -FilePath "C:\Scripts\TestScript.ps1" -ArgumentList "Param1", "Param2" -MaxAttempts 4 -Timeout 60 -Message "Retrying file execution"

  .EXAMPLE
   # Customizing success return codes
   $result = Invoke-RetriableCommand -ScriptBlock {
       # Simulate success with custom return code 200
       Write-Output "Custom success return code"
       Start-Sleep -Seconds 1
       return 200
   } -MaxAttempts 3 -SuccessReturnCodes @(0, 200) -Message "Custom success code retry"

  .EXAMPLE
   # Retry with a CancellationToken
   $cancellationTokenSource = New-Object System.Threading.CancellationTokenSource
   Start-Job -ScriptBlock {
       Start-Sleep -Seconds 3
       $cancellationTokenSource.Cancel()
   }
   $result = Invoke-RetriableCommand -ScriptBlock {
       Write-Output "Attempting long-running command execution"
       Start-Sleep -Seconds 10 # Simulated long-running task
   } -MaxAttempts 5 -Timeout 15 -CancellationToken $cancellationTokenSource.Token -Message "Retry with cancellation token"

  .NOTES
    - Requires Core Psedition due to ternary-operator
      https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_if?view=powershell-7.4#using-the-ternary-operator-syntax

    - All Unnamed arguments will be passed as arguments to the script or command
  .LINK
    Online Version: https://github.com/chadnpc/cliHelper.Core/blob/main/Public/Psrunner/Invoke-RetriableCommand.ps1
  #>
  [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ScriptBlock')]
  [OutputType([Results])][Alias('Invoke-RtCommand')]
  param (
    [Parameter(Mandatory = $false, Position = 0, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$ComputerName,

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'ScriptBlock')]
    [Alias('Script')][ValidateNotNullOrEmpty()]
    [ScriptBlock]$ScriptBlock,

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'Command')]
    [Alias('Command')][ValidateNotNullOrWhiteSpace()]
    [string]$FilePath,

    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = '__AllParameterSets')]
    [Object[]]$ArgumentList,


    [Parameter(Mandatory = $false, Position = 3, ParameterSetName = '__AllParameterSets')]
    [Alias('Retries', 'MaxRetries')][ValidateNotNullOrEmpty()]
    [int]$MaxAttempts = 3,

    [Parameter(Mandatory = $false, Position = 4, ParameterSetName = '__AllParameterSets')]
    [uint32[]]$SuccessReturnCodes = @(0, 3010),

    [Parameter(Mandatory = $false, Position = 5, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrWhiteSpace()]
    [string]$WorkingDirectory,

    # Timeout in milliseconds
    [Parameter(Mandatory = $false, Position = 6, ParameterSetName = '__AllParameterSets')]
    [Alias('t')][ValidateNotNullOrEmpty()]
    [int]$Timeout = 500,

    [Parameter(Mandatory = $false, Position = 7, ParameterSetName = '__AllParameterSets')]
    [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None,

    # The message to display in the verbose stream
    [Parameter(Mandatory = $false, Position = 8, ParameterSetName = '__AllParameterSets')]
    [Alias('msg')][ValidateNotNullOrWhiteSpace()]
    [string]$Message,

    [Parameter(Mandatory = $false, Position = 9, ParameterSetName = 'Command')]
    [switch]$ExpandStrings
  )
  DynamicParam {
    $DynamicParams = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
    $attributes = [System.Management.Automation.ParameterAttribute]::new(); $attHash = @{
      Position                        = 10
      ParameterSetName                = '__AllParameterSets'
      Mandatory                       = $false
      ValueFromPipeline               = $false
      ValueFromPipelineByPropertyName = $false
      ValueFromRemainingArguments     = $true
      HelpMessage                     = 'Allows splatting with arguments that do not apply. Do not use directly.'
      DontShow                        = $False
    }; $attHash.Keys | ForEach-Object { $attributes.$_ = $attHash.$_ }
    $attributeCollection.Add($attributes)
    $RuntimeParam = [System.Management.Automation.RuntimeDefinedParameter]::new("IgnoredArguments", [Object[]], $attributeCollection)
    $DynamicParams.Add("IgnoredArguments", $RuntimeParam)
    return $DynamicParams
  }

  begin {
    [ActionPreference]$eap = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    $fxn = '[PsRunner]'; $PsBoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
    $cmdColors = [PsCustomObject]@{
      Verbose     = 'LemonChiffon'
      Debug       = 'Lavender'
      Error       = 'Salmon'
      Warning     = 'Yellow'
      Progress    = 'SpringGreen'
      Information = 'LawnGreen'
    }
    class Result {
      [System.Management.Automation.PSDataCollection[PsObject]]$Output = [System.Management.Automation.PSDataCollection[PsObject]]::new()
      [bool]$IsSuccess = $false
      [System.Management.Automation.ErrorRecord]$ErrorRecord = $null
      hidden [double]$ET = 0 # ElapsedTime
    }
    class Results {
      hidden [System.Collections.ObjectModel.Collection[Result]]$Items = [System.Collections.ObjectModel.Collection[Result]]::new()
      hidden [System.Management.Automation.ErrorRecord[]]$Errors = @()
      Results() {
        $this.PsObject.Properties.Add([PSScriptProperty]::new('ElapsedTime', { if ($this.Items.Count -gt 0) { return [double](($this.Items.ET | Measure-Object -Sum).Sum) }; return [double]0 }))
        $this.PsObject.Properties.Add([PSScriptProperty]::new('IsSuccess', { $r = [bool]($this.Items.Count -gt 0 -and $this.Items.Where({ $_.IsSuccess }).Count -gt 0); $this.Errors = $this.Items.ErrorRecord; return $r }))
        $this.PsObject.Properties.Add([PSScriptProperty]::new('HasErrors', { return  $this.Errors.Count -gt 0 }))
        $this.PsObject.Properties.Add([PSScriptProperty]::new('Output', { return $this.Items.Output }))
        $this.PsObject.Properties.Add([PSScriptProperty]::new('Count', { return $this.Items.Count }))
      }
      [void] Add([Result]$item) { $this.Items.Add($item) }
    }
  }

  process {
    $Attempts = 1; $Results = [Results]::new()
    if ($PsBoundParameters.ContainsKey("Message") -and $verbose) {
      Write-Console "$fxn $Message" -f $cmdColors.Information
    }
    while (($Attempts -le $MaxAttempts) -and !$Results.IsSuccess) {
      $CommandStartTime = Get-Date; $Retries = $MaxAttempts - $Attempts
      if ($cancellationToken.IsCancellationRequested) { $verbose ? (Write-Console "$fxn CancellationRequested when $Retries retries were left." -f $cmdColors.Verbose) : $null; throw }
      $Result = [Result]::new()
      try {
        $AttemptStartTime = Get-Date
        $verbose ? (Write-Console "$fxn Attempt # $Attempts/$MaxAttempts ..." -f $cmdColors.Progress) : $null
        if ($PSCmdlet.ParameterSetName -eq 'Command') {
          try {
            $verbose ? (Write-Console "Running command line [$FilePath $ArgumentList] on $ComputerName" -f LemonChiffon) : $null
            $Result.Output += Invoke-Command -ComputerName $ComputerName -ScriptBlock {
              $VerbosePreference = $using:VerbosePreference
              $WhatIfPreference = $using:WhatIfPreference
              $ps = [System.Diagnostics.Process]::new()
              $ps_startInfo = [System.Diagnostics.ProcessStartInfo]::new()
              $ps_startInfo.FileName = $Using:FilePath;
              if ($Using:ArgumentList) {
                $ps_startInfo.Arguments = $Using:ArgumentList;
                if ($Using:ExpandStrings) {
                  $ps_startInfo.Arguments = $ExecutionContext.InvokeCommandWithCred.ExpandString($Using:ArgumentList);
                }
              }
              if ($Using:WorkingDirectory) {
                $ps_startInfo.WorkingDirectory = $Using:WorkingDirectory;
                if ($Using:ExpandStrings) {
                  $ps_startInfo.WorkingDirectory = $ExecutionContext.InvokeCommandWithCred.ExpandString($Using:WorkingDirectory);
                }
              }
              $ps_startInfo.UseShellExecute = $false; # This is critical for installs to function on core servers
              $ps.StartInfo = $ps_startInfo;
              $verbose ? (Write-Console "Starting Process path [$($ps_startInfo.FileName)] - Args: [$($ps_startInfo.Arguments)] - Working dir: [$($Using:WorkingDirectory)]" -f LemonChiffon) : $null
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
            $Result.IsSuccess = [bool]$?
          } catch {
            $Result.IsSuccess = $false
            $Result.ErrorRecord = $_.Exception.ErrorRecord
            $verbose ? (Write-Console "$fxn Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)" -f LemonChiffon) : $null
          }
        } else {
          $Result.Output += Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
          $Result.IsSuccess = [bool]$?
        }
      } catch {
        $Result.IsSuccess = $false
        $Result.ErrorRecord = [System.Management.Automation.ErrorRecord]$_
        $verbose ? (Write-Console "$fxn Error after $([math]::Round(($(Get-Date) - $AttemptStartTime).TotalSeconds, 2)) seconds:" -f $cmdColors.Verbose) : $null
        $verbose ? (Write-Console "   $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)" -f $cmdColors.Error) : $null
      } finally {
        $Result.ET = [math]::Round(($(Get-Date) - $CommandStartTime).TotalSeconds, 2)
        [void]$Results.Add($Result)
        if (!$cancellationToken.IsCancellationRequested -and ($Retries -ne 0) -and !$Result.IsSuccess) {
          $verbose ? (Write-Console "$fxn Waiting $Timeout ms before retrying. Retries left: $Retries" -f $cmdColors.Verbose) : $null
          [System.Threading.Thread]::Sleep($Timeout);
        }
        $Attempts++
      }
    }
  }

  end {
    if ($verbose) {
      $e = @{
        0 = @{
          c = "Error"
          m = "$Message Completed With Errors. Total time elapsed $($Results.ElapsedTime). Check the log file `$LogPath".Trim()
        };
        1 = @{
          c = "Information"
          m = "$Message Completed Successfully. Total time elapsed $($Results.ElapsedTime)".Trim()
        }
      }[[int]$Results.IsSuccess]
      Write-Console "$fxn $($e.m)" -f $cmdColors.($e.c)
    }
    $ErrorActionPreference = $eap;
    return $Results
  }
}