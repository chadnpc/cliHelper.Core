function Wait-Task {
  # .SYNOPSIS
  #     Waits for a scriptblock or job to complete
  # .OUTPUTS
  #     TaskResult.Result
  [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
  [OutputType([psobject])][Alias('await')]
  param (
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = '__AllparameterSets')]
    [Alias('m')][ValidateNotNullOrEmpty()]
    [string]$progressMsg,

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'scriptBlock')]
    [Alias('s')][ValidateNotNullOrEmpty()]
    [scriptblock]$scriptBlock,

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'job')]
    [Alias('j')][ValidateNotNullOrEmpty()]
    [System.Management.Automation.Job]$xJob
  )
  begin {
    $Result = TaskResult($null);
    # $Tasks = @()
  }
  process {
    if ($PSCmdlet.ParameterSetName -in ('job', 'scriptBlock')) {
      [System.Management.Automation.Job]$_Job = $(if ($PSCmdlet.ParameterSetName -eq 'scriptBlock') { Get-Job -Id $(Start-Job -ScriptBlock $scriptBlock).Id } else { $Job })
      [Console]::CursorVisible = $false;
      [ProgressUtil]::frames = [ProgressUtil]::_twirl[0]
      [int]$length = [ProgressUtil]::frames.Length;
      $originalY = [Console]::CursorTop
      while ($_Job.JobStateInfo.State -notin ('Completed', 'failed')) {
        for ($i = 0; $i -lt $length; $i++) {
          [ProgressUtil]::frames | ForEach-Object { [Console]::Write("$progressMsg $($_[$i])") }
          [System.Threading.Thread]::Sleep(50)
          [Console]::Write(("`b" * ($length + $progressMsg.Length)))
          [Console]::CursorTop = $originalY
        }
      }
      # i.e: Gives an illusion of loading animation.
      [void][cli]::Write("`b$progressMsg", [ConsoleColor]::Blue)
      [System.Management.Automation.Runspaces.RemotingErrorRecord[]]$Errors = $_Job.ChildJobs.Where({
          $null -ne $_.Error
        }
      ).Error;
      $LogMsg = ''; $_Success = ($null -eq $Errors); $attMSg = Get-AttemptMSg;
      if (![string]::IsNullOrWhiteSpace($attMSg)) { $LogMsg += $attMSg } else { $LogMsg += "... " }
      if ($_Job.JobStateInfo.State -eq "Failed" -or $Errors.Count -gt 0) {
        $errormessages = ""; $errStackTrace = ""
        if ($null -ne $Errors) {
          $errormessages = $Errors.Exception.Message -join "`n"
          $errStackTrace = $Errors.ScriptStackTrace
          if ($null -ne $Errors.Exception.InnerException) {
            $errStackTrace += "`n`t"
            $errStackTrace += $Errors.Exception.InnerException.StackTrace
          }
        }
        $Result = TaskResult($_Job, $Errors);
        $_Success = $false; $LogMsg += " Completed with errors.`n`t$errormessages`n`t$errStackTrace"
      } else {
        $Result = TaskResult($_Job)
      }
      Write-Log $LogMsg -s:$_Success
      [Console]::CursorVisible = $true; Set-AttemptMSg ' '
    } else {
      # $Tasks += $Task
      # While (![System.Threading.Tasks.Task]::WaitAll($Tasks, 200)) {}
      # $Tasks.ForEach( { $_.GetAwaiter().GetResult() })
      $threads = New-Object System.Collections.ArrayList;
      $result = [PSCustomObject]@{
        Task   = $null
        Shell  = $PowerShell
        Result = $PowerShell.BeginInvoke()
      }
      $threads.Add($result) | Out-Null;
      $completed = $false; $_r = @{ true = 'Completed'; false = 'Still open' }
      while ($completed -eq $false) {
        $completed = $true;
        foreach ($thread in $threads) {
          $result.Task = $thread.Shell.EndInvoke($thread.Result);
          $threadHandle = $thread.Result.AsyncWaitHandle.Handle;
          $threadIsCompleted = $thread.Result.IsCompleted;
          Write-Verbose ("[Task] ThreadHandle {0} is {1}" -f $threadHandle, $_r["$threadIsCompleted"])
          if ($threadIsCompleted -eq $false) {
            $completed = $false;
          }
        }
        Start-Sleep -Milliseconds 500;
      }
      foreach ($thread in $threads) {
        $thread.Shell.Dispose();
      }
      return $result
      throw [System.NotSupportedException]::new("Sorry, ParameterSetName task is not yet supported")
    }
  }
  end {
    return $Result
  }
}
