using namespace System.IO
using namespace System.Threading
using namespace System.Collections
using namespace System.ComponentModel
using namespace System.Threading.workers
using namespace System.Management.Automation
using namespace System.Collections.Concurrent
using namespace System.Management.Automation.Runspaces

#region    Classes

# .EXAMPLE
# [char][Barsymbol]::Box
enum BarSymbol {
  Box = 9632
  Block = 9608
  Circle = 9679
}

# .SYNOPSIS
# A simple progress utility class
# .EXAMPLE
# $OgForeground = (Get-Variable host).Value.UI.RawUI.ForegroundColor
# (Get-Variable host).Value.UI.RawUI.ForegroundColor = [ConsoleColor]::Green
# for ($i = 0; $i -le 100; $i++) {
#     [ProgressUtil]::WriteProgressBar($i)
#     [System.Threading.Thread]::Sleep(50)
# }
# (Get-Variable host).Value.UI.RawUI.ForegroundColor = $OgForeground
# [progressUtil]::WaitJob("waiting", { Start-Sleep -Seconds 3 })
class ProgressUtil {
  static hidden [string] $_block = '■';
  static hidden [string] $_back = "`b";
  static hidden [string[]] $_twirl = @(
    "◰◳◲◱",
    "◇◈◆",
    "◐◓◑◒",
    "←↖↑↗→↘↓↙",
    "┤┘┴└├┌┬┐",
    "⣾⣽⣻⢿⡿⣟⣯⣷",
    "|/-\\",
    "-\\|/",
    "|/-\\"
  );
  static [int] $_twirlIndex = 0
  static hidden [string]$frames
  static [void] WriteProgressBar([int]$percent) {
    [ProgressUtil]::WriteProgressBar($percent, $true)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update) {
    [ProgressUtil]::WriteProgressBar($percent, $update, [int]([Console]::WindowWidth * 0.7))
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength) {
    [ValidateNotNull()][int]$PBLength = $PBLength
    [ValidateNotNull()][int]$percent = $percent
    [ValidateNotNull()][bool]$update = $update
    [ProgressUtil]::_back = "`b" * [Console]::WindowWidth
    if ($update) { [Console]::Write([ProgressUtil]::_back) }
    [Console]::Write("["); $p = [int](($percent / 100.0) * $PBLength + 0.5)
    for ($i = 0; $i -lt $PBLength; $i++) {
      if ($i -ge $p) {
        [Console]::Write(' ');
      } else {
        [Console]::Write([ProgressUtil]::_block);
      }
    }
    [Console]::Write("] {0,3:##0}%", $percent);
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [scriptblock]$Job) {
    return [ProgressUtil]::WaitJob($progressMsg, $(Start-Job -ScriptBlock $Job))
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [System.Management.Automation.Job]$Job) {
    [Console]::CursorVisible = $false;
    [ProgressUtil]::frames = [ProgressUtil]::_twirl[0]
    [int]$length = [ProgressUtil]::frames.Length;
    $originalY = [Console]::CursorTop
    while ($Job.JobStateInfo.State -notin ('Completed', 'failed')) {
      for ($i = 0; $i -lt $length; $i++) {
        [ProgressUtil]::frames.Foreach({ [Console]::Write("$progressMsg $($_[$i])") })
        [System.Threading.Thread]::Sleep(50)
        [Console]::Write(("`b" * ($length + $progressMsg.Length)))
        [Console]::CursorTop = $originalY
      }
    }
    Write-Host "`b$progressMsg ... " -NoNewline -ForegroundColor Magenta
    [System.Management.Automation.Runspaces.RemotingErrorRecord[]]$Errors = $Job.ChildJobs.Where({
        $null -ne $_.Error
      }
    ).Error;
    if ($Job.JobStateInfo.State -eq "Failed" -or $Errors.Count -gt 0) {
      $errormessages = [string]::Empty
      if ($null -ne $Errors) {
        $errormessages = $Errors.Exception.Message -join "`n"
      }
      Write-Host "Completed with errors.`n`t$errormessages" -ForegroundColor Red
    } else {
      Write-Host "Done." -ForegroundColor Green
    }
    [Console]::CursorVisible = $true;
    return $Job
  }
}

class ProgressBar {
  [ValidateNotNullOrEmpty()][string]$Status
  [ValidateNotNullOrEmpty()][string]$Activity
  [validaterange(0, 100)][int]$PercentComplete

  ProgressBar([string]$activity) {
    $this.Activity = $activity
    $this.Status = "Starting..."
    $this.PercentComplete = 0
  }
  [void] Start() { $this.Start("Initializing...") }
  [void] Start([string]$initialStatus) {
    $this.Status = $initialStatus
    $this.PercentComplete = 0
    $this.DisplayProgress()
  }
  [void] Update([int]$progress) {
    $this.Update($progress, "In Progress")
  }
  [void] Update([int]$progress, [string]$status) {
    $this.PercentComplete = [math]::Min($progress, 100)
    $this.Status = $status
    $this.DisplayProgress()
  }
  [void] Complete() { $this.Complete("Complete") }
  [void] Complete([string]$finalStatus) {
    $this.PercentComplete = 100
    $this.Status = $finalStatus
    $this.DisplayProgress()
  }
}
class StackTracer {
  static [System.Collections.Concurrent.ConcurrentStack[string]]$stack = [System.Collections.Concurrent.ConcurrentStack[string]]::new()
  static [System.Collections.Generic.List[hashtable]]$CallLog = @()
  static [void] Push([string]$class) {
    $str = "[{0}]" -f $class
    if ([StackTracer]::Peek() -ne "$class") {
      [StackTracer]::stack.Push($str)
      $LAST_ERROR = $(Get-Variable -Name Error -ValueOnly)[0]
      [StackTracer]::CallLog.Add(@{ ($str + ' @ ' + [datetime]::Now.ToShortTimeString()) = $(if ($null -ne $LAST_ERROR) { $LAST_ERROR.ScriptStackTrace } else { [System.Environment]::StackTrace }).Split("`n").Replace("at ", "# ").Trim() })
    }
  }
  static [type] Pop() {
    $result = $null
    if ([StackTracer]::stack.TryPop([ref]$result)) {
      return $result
    } else {
      throw [System.InvalidOperationException]::new("Stack is empty!")
    }
  }
  static [string] Peek() {
    $result = $null
    if ([StackTracer]::stack.TryPeek([ref]$result)) {
      return $result
    } else {
      return [string]::Empty
    }
  }
  static [int] GetSize() {
    return [StackTracer]::stack.Count
  }
  static [bool] IsEmpty() {
    return [StackTracer]::stack.IsEmpty
  }
}

<#
.SYNOPSIS
  PsRunner : Main class of the module
.DESCRIPTION
  Provides simple multithreading implementation in powerhsell
.NOTES
  Author  : Alain Herve
  Created : <release_date>
  Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action ([PsRunner]::GetOnRemovalScript())

 .EXAMPLE
  $r = [PsRunner]::new();
  $worker1 = { $res = "worker running on thread $([Threading.Thread]::CurrentThread.ManagedThreadId)"; Start-Sleep -Seconds 5; return $res };
  $worker2 = { return (Get-Variable PsRunner_* -ValueOnly) };
  $worker3 = { $res = "worker running on thread $([Threading.Thread]::CurrentThread.ManagedThreadId)"; 10..20 | Get-Random | ForEach-Object {  Start-Sleep -Milliseconds ($_ * 100) }; return $res };
  $r.Add_BGWorker($worker1); $r.Add_BGWorker($worker2); $r.Add_BGWorker($worker3);
  $r.Run()

 .EXAMPLE
  $ps = $r.RunAsync()
  $or = $ps.Instance.EndInvoke($ps.AsyncHandle)

 .EXAMPLE
  $ps = [powershell]::Create([PsRunner]::CreateRunspace())
  $ps = $ps.AddScript({
    $(Get-Variable SyncHash -ValueOnly)["JobsCleanup"] = "hello from rs manager"
    return [PSCustomObject]@{
      Setup    = Get-Variable RunSpace_Setup -ValueOnly
      SyncHash = Get-Variable SyncHash -ValueOnly
    }
  })
 $h = $ps.BeginInvoke()
 $ps.EndInvoke($h)
#>
class PsRunner {
  hidden [int] $_MinThreads = 2
  hidden [int] $_MaxThreads = [PsRunner]::GetThreadCount()
  static hidden [string] $SyncId = { [void][PsRunner]::SetSyncHash(); return [PsRunner].SyncId }.Invoke() # Unique ID for each runner instance

  static PsRunner() {
    # set properties (Once-time)
    "PsRunner" | Update-TypeData -MemberName Id -MemberType ScriptProperty -Value { return [PsRunner]::SyncId } -SecondValue { throw [SetValueException]::new('Id is read-only') } -Force;
    "PsRunner" | Update-TypeData -MemberName MinThreads -MemberType ScriptProperty -Value { return $this._MinThreads } -SecondValue {
      param($value) if ($value -lt 2) { throw [ArgumentOutOfRangeException]::new("MinThreads must be greater than or equal to 2") };
      $this._MinThreads = $value
    } -Force;
    "PsRunner" | Update-TypeData -MemberName MaxThreads -MemberType ScriptProperty -Value { return $this._MaxThreads } -SecondValue {
      param($value) $m = [PsRunner]::GetThreadCount(); if ($value -gt $m) { throw [ArgumentOutOfRangeException]::new("MaxThreads must be less than or equal to $m") }
      $this._MaxThreads = $value
    } -Force;
    [PsRunner].PsObject.Properties.Add([PSScriptProperty]::new('Instance', {
          if (![PsRunner]::GetSyncHash()["Instance"]) { [PsRunner].SyncHash["Instance"] = [PsRunner]::Get_runspace_manager() };
          return [PsRunner].SyncHash["Instance"]
        }, {
          throw [SetValueException]::new('Instance is read-only')
        }
      )
    )
    "PsRunner" | Update-TypeData -MemberName GetOutput -MemberType ScriptMethod -Value {
      $o = [PsRunner]::GetSyncHash()["Output"]; [PsRunner].SyncHash["Output"] = [PSDataCollection[PsObject]]::new()
      [PsRunner].SyncHash["Runspaces"] = [ConcurrentDictionary[int, powershell]]::new()
      return $o
    } -Force;
  }
  [void] Add_BGWorker([ScriptBlock]$Worker) {
    $this.Add_BGWorker([PsRunner]::GetWorkerId(), $Worker, @())
  }
  [void] Add_BGWorker([int]$Id, [ScriptBlock]$Worker, [object[]]$Arguments) {
    [void][PsRunner]::Isvalid_NewRunspaceId($Id)
    $ps = [powershell]::Create([PsRunner]::CreateRunspace())
    $ps = $ps.AddScript($Worker)
    if ($Arguments.Count -gt 0) { $Arguments.ForEach({ [void]$ps.AddArgument($_) }) }
    # $ps.RunspacePool = [PsRunner].SyncHash["RunspacePool"] # https://github.com/PowerShell/PowerShell/issues/18934
    # Save each Worker in a dictionary, ie: {Int_Id, Powershell_instance_on_different_thread}
    if (![PsRunner]::GetSyncHash()["Runspaces"].TryAdd($Id, $ps)) { throw [System.InvalidOperationException]::new("worker $Id already exists.") }
    [PsRunner].SyncHash["Jobs"][$Id] = @{
      __PS   = ([ref]$ps).Value
      Status = ([ref]$ps).Value.Runspace.RunspaceStateInfo.State
      Result = $null
    }
  }
  [PsObject[]] Run() { $o = [PsRunner]::Run([PsRunner]::GetSyncHash()["Runspaces"]); [PsRunner].SyncHash["Output"] += $o; return $o }
  static [PsObject[]] Run([ConcurrentDictionary[int, powershell]]$Runspaces) {
    if (![PsRunner]::HasPendingJobs()) { return $null }
    [PsRunner].SyncHash["Runspaces"] = $Runspaces
    $Handle = [PsRunner].Instance.BeginInvoke()
    Write-Host ">>> Started background jobs" -f Green
    $i = 0
    while ($Handle.IsCompleted -eq $false) {
      Start-Sleep -Milliseconds 500
      Write-Progress -Activity "Running" -Status "In Progress" -PercentComplete $($i % 100)
      $i += 5
    }
    Write-Host "`n>>> All background jobs are complete." -f Green
    return [PsRunner].Instance.EndInvoke($Handle)
  }
  [PsObject] RunAsync() { return [PsRunner]::RunAsync([PsRunner]::GetSyncHash()["Runspaces"]) }
  static [PsObject] RunAsync([ConcurrentDictionary[int, powershell]]$Runspaces) {
    if (![PsRunner]::HasPendingJobs()) { return $null }
    [PsRunner]::GetSyncHash()["Runspaces"] = $Runspaces
    return [PSCustomObject]@{
      Instance    = [PsRunner].Instance
      AsyncHandle = [IAsyncResult][PsRunner].Instance.BeginInvoke()
    }
  }
  static [Runspace] CreateRunspace() {
    $defaultvars = @(
      [PSVariable]::new("RunSpace_Setup", [PsRunner]::GetRunSpace_Setup())
      [PSVariable]::new("SyncHash", [PsRunner]::GetSyncHash())
    )
    return [PsRunner]::CreateRunspace($defaultvars)
  }
  static [Runspace] CreateRunspace([PSVariable[]]$variables) {
    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables
    $automatic_variables = @('$', '?', '^', '_', 'args', 'ConsoleFileName', 'EnabledExperimentalFeatures', 'Error', 'Event', 'EventArgs', 'EventSubscriber', 'ExecutionContext', 'false', 'foreach', 'HOME', 'Host', 'input', 'IsCoreCLR', 'IsLinux', 'IsMacOS', 'IsWindows', 'LASTEXITCODE', 'Matches', 'MyInvocation', 'NestedPromptLevel', 'null', 'PID', 'PROFILE', 'PSBoundParameters', 'PSCmdlet', 'PSCommandPath', 'PSCulture', 'PSDebugContext', 'PSEdition', 'PSHOME', 'PSItem', 'PSScriptRoot', 'PSSenderInfo', 'PSUICulture', 'PSVersionTable', 'PWD', 'Sender', 'ShellId', 'StackTrace', 'switch', 'this', 'true')
    $_variables = [PsRunner]::GetVariables().Where({ $_.Name -notin $automatic_variables }); $r = [runspacefactory]::CreateRunspace()
    if ((Get-Variable PSVersionTable -ValueOnly).PSEdition -ne "Core") { $r.ApartmentState = "STA" }
    $r.ThreadOptions = "ReuseThread"; $r.Open()
    $variables.ForEach({ $r.SessionStateProxy.SetVariable($_.Name, $_.Value) })
    [void]$r.SessionStateProxy.Path.SetLocation((Resolve-Path ".").Path)
    $_variables.ForEach({ $r.SessionStateProxy.PSVariable.Set($_.Name, $_.Value) })
    return $r
  }
  static [RunspacePool] CreateRunspacePool([int]$minRunspaces, [int]$maxRunspaces, [initialsessionstate]$initialSessionState, [Host.PSHost]$PsHost) {
    Write-Verbose "Creating runspace pool and session states"
    #If specified, add variables and modules/snapins to session state
    $sessionstate = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    # if ($UserVariables.count -gt 0) {
    #   foreach ($Variable in $UserVariables) {
    #     $sessionstate.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $Variable.Name, $Variable.Value, $null) )
    #   }
    # }
    # if ($UserModules.count -gt 0) {
    #   foreach ($ModulePath in $UserModules) {
    #     $sessionstate.ImportPSModule($ModulePath)
    #   }
    # }
    # if ($UserSnapins.count -gt 0) {
    #   foreach ($PSSnapin in $UserSnapins) {
    #     [void]$sessionstate.ImportPSSnapIn($PSSnapin, [ref]$null)
    #   }
    # }
    # if ($UserFunctions.count -gt 0) {
    #   foreach ($FunctionDef in $UserFunctions) {
    #     $sessionstate.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $FunctionDef.Name, $FunctionDef.ScriptBlock))
    #   }
    # }
    $runspacepool = [runspacefactory]::CreateRunspacePool($minRunspaces, $maxRunspaces, $sessionstate, $PsHost)
    if ((Get-Variable PSVersionTable -ValueOnly).PSEdition -ne "Core") { $runspacepool.ApartmentState = "STA" }
    $runspacepool.Open()
    return $runspacepool
  }
  static [bool] Isvalid_NewRunspaceId([int]$RsId) {
    return [PsRunner]::Isvalid_NewRunspaceId($RsId, $true)
  }
  static [bool] Isvalid_NewRunspaceId([int]$RsId, [bool]$ThrowOnFail) {
    $v = $null -eq (Get-Runspace -Id $RsId)
    if (!$v -and $ThrowOnFail) {
      throw [System.InvalidOperationException]::new("Runspace with ID $RsId already exists.")
    }; return $v
  }
  static [PSVariable[]] GetVariables() {
    # Set Environment Variables
    # if ($EnvironmentVariablesToForward -notcontains '*') {
    #   $EnvVariables = foreach ($obj in $EnvVariables) {
    #     if ($EnvironmentVariablesToForward -contains $obj.Name) {
    #       $obj
    #     }
    #   }
    # }
    # Write-Verbose "Setting SyncId <=> (OneTime/Session)"
    return (Get-Variable).Where({ $o = $_.Options.ToString(); $o -notlike "*ReadOnly*" -and $o -notlike "*Constant*" })
  }
  static [Object[]] GetCommands() {
    # if ($FunctionsToForward -notcontains '*') {
    #   $Functions = foreach ($FuncObj in $Functions) {
    #     if ($FunctionsToForward -contains $FuncObj.Name) {
    #       $FuncObj
    #     }
    #   }
    # }
    # $res = [PsRunner].SyncHash["Commands"]; if ($res) { return $res }
    return (Get-ChildItem Function:).Where({ ![System.String]::IsNullOrWhiteSpace($_.Name) })
  }
  static [string[]] GetModuleNames() {
    # if ($ModulesToForward -notcontains '*') {
    #   $Modules = foreach ($obj in $Modules) {
    #     if ($ModulesToForward -contains $obj.Name) {
    #       $obj
    #     }
    #   }
    # }
    return (Get-Module).Name
  }
  static [ArrayList] GetRunSpace_Setup() {
    return [PsRunner]::GetRunSpace_Setup((Get-ChildItem Env:), [PsRunner]::GetModuleNames(), [PsRunner]::GetCommands());
  }
  static [ArrayList] GetRunSpace_Setup([DictionaryEntry[]]$EnvVariables, [string[]]$ModuleNames, [Object[]]$Functions) {
    [ArrayList]$RunSpace_Setup = @(); $EnvVariables = Get-ChildItem Env:\
    $SetEnvVarsPrep = foreach ($obj in $EnvVariables) {
      if ([char[]]$obj.Name -contains '(' -or [char[]]$obj.Name -contains ' ') {
        $strr = @(
          'try {'
          $(' ${env:' + $obj.Name + '} = ' + "@'`n$($obj.Value)`n'@")
          'catch {'
          " Write-Debug 'Unable to forward environment variable $($obj.Name)'"
          '}'
        )
      } else {
        $strr = @(
          'try {'
          $(' $env:' + $obj.Name + ' = ' + "@'`n$($obj.Value)`n'@")
          '} catch {'
          " Write-Debug 'Unable to forward environment variable $($obj.Name)'"
          '}'
        )
      }
      [string]::Join("`n", $strr)
    }
    [void]$RunSpace_Setup.Add([string]::Join("`n", $SetEnvVarsPrep))
    $Modules = Get-Module -Name $ModuleNames | Select-Object Name, @{ l = "Manifest"; e = { [IO.Path]::Combine($_.ModuleBase, $_.Name + ".psd1") } }
    $SetModulesPrep = foreach ($obj in $Modules) {
      $strr = @(
        '$tempfile = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName())'
        "if (![bool]('$($obj.Name)' -match '\.WinModule')) {"
        ' try {'
        "  Import-Module '$($obj.Name)' -NoClobber -ErrorAction Stop 2>`$tempfile"
        '} catch {'
        '  try {'
        "   Import-Module '$($obj.Manifest)' -NoClobber -ErrorAction Stop 2>`$tempfile"
        '  } catch {'
        "   Write-Debug 'Unable to Import-Module $($obj.Name)'"
        '  }'
        ' }'
        '}'
        'if ([IO.File]::Exists($tempfile)) {'
        ' Remove-Item $tempfile -Force'
        '}'
      )
      [string]::Join("`n", $strr)
    }
    [void]$RunSpace_Setup.Add([string]::Join("`n", $SetModulesPrep))
    $SetFunctionsPrep = foreach ($obj in $Functions) {
      $FunctionText = Invoke-Expression $('@(${Function:' + $obj.Name + '}.Ast.Extent.Text)')
      if ($($FunctionText -split "`n").Count -gt 1) {
        if ($($FunctionText -split "`n")[0] -match "^function ") {
          if ($($FunctionText -split "`n") -match "^'@") {
            Write-Debug "Unable to forward function $($obj.Name) due to heredoc string: '@"
          } else {
            'Invoke-Expression ' + "@'`n$FunctionText`n'@"
          }
        }
      } elseif ($($FunctionText -split "`n").Count -eq 1) {
        if ($FunctionText -match "^function ") {
          'Invoke-Expression ' + "@'`n$FunctionText`n'@"
        }
      }
    }
    [void]$RunSpace_Setup.Add([string]::Join("`n", $SetFunctionsPrep))
    return $RunSpace_Setup
  }
  static [Hashtable] SetSyncHash() {
    return [PsRunner]::SetSyncHash($False)
  }
  static [Hashtable] SetSyncHash([bool]$Force) {
    if (![PsRunner].SyncHash -or $Force) {
      $Id = [string]::Empty; $sv = Get-Variable PsRunner_* -Scope Global; if ($sv.Count -gt 0) { $Id = $sv[0].Name }
      if ([string]::IsNullOrWhiteSpace($Id)) { $Id = "PsRunner_{0}" -f [Guid]::NewGuid().Guid.substring(0, 21).replace('-', [string]::Join('', (0..9 | Get-Random -Count 1))) };
      [PsRunner].PsObject.Properties.Add([PSScriptProperty]::new('SyncId', [scriptblock]::Create("return '$Id'"), { throw [SetValueException]::new('SyncId is read-only') }))
      [PsRunner].PsObject.Properties.Add([PsNoteProperty]::new('SyncHash', [Hashtable]::Synchronized(@{
              Id          = [string]::Empty
              Jobs        = [Hashtable]::Synchronized(@{})
              Runspaces   = [ConcurrentDictionary[int, powershell]]::new()
              JobsCleanup = @{}
              Output      = [PSDataCollection[PsObject]]::new()
            }
          )
        )
      );
      New-Variable -Name $Id -Value $([ref][PsRunner].SyncHash).Value -Option AllScope -Scope Global -Visibility Public -Description "PID_$(Get-Variable PID -ValueOnly)_PsRunner_variables" -Force
      [PsRunner].SyncHash["Id"] = $Id;
    }
    return [PsRunner].SyncHash
  }
  static [PowerShell] Get_runspace_manager() {
    Write-Verbose "Creating Runspace Manager (OneTime) ..."
    $i = [powershell]::Create([PsRunner]::CreateRunspace())
    $i.AddScript({
        $Runspaces = $SyncHash["Runspaces"]
        $Jobs = $SyncHash["Jobs"]
        if ($RunSpace_Setup) {
          foreach ($obj in $RunSpace_Setup) {
            if ([string]::IsNullOrWhiteSpace($obj)) { continue }
            try {
              Invoke-Expression $obj
            } catch {
              throw ("Error {0} `n{1}" -f $_.Exception.Message, $_.ScriptStackTrace)
            }
          }
        }
        $Runspaces.Keys.ForEach({
            $Jobs[$_]["Handle"] = [IAsyncResult]$Jobs[$_]["__PS"].BeginInvoke()
            Write-Host "Started worker $_" -f Yellow
          }
        )
        # Monitor workers until they complete
        While ($Runspaces.ToArray().Where({ $Jobs[$_.Key]["Handle"].IsCompleted -eq $false }).count -gt 0) {
          # Write-Host "$(Get-Date) Still running..." -f Green
          # foreach ($worker in $Runspaces.ToArray()) {
          #   $Id = $worker.Key
          #   $status = $Jobs[$Id]["Status"]
          #   Write-Host "worker $Id Status: $status"
          # }
          Start-Sleep -Milliseconds 500
        }
        Write-Host "All workers are complete." -f Yellow
        $SyncHash["Results"] = @(); foreach ($i in $Runspaces.Keys) {
          $__PS = $Jobs[$i]["__PS"]
          try {
            $Jobs[$i] = @{
              Result = $__PS.EndInvoke($Jobs[$i]["Handle"])
              Status = "Completed"
            }
          } catch {
            $Jobs[$i] = @{
              Result = $_.Exception.Message
              Status = "Failed"
            }
          } finally {
            # Dispose of the PowerShell instance
            $__PS.Runspace.Close()
            $__PS.Runspace.Dispose()
            $__PS.Dispose()
          }
          # Store results
          $SyncHash["Results"] += [pscustomobject]@{
            Id     = $i
            Result = $Jobs[$i]["Result"]
            Status = $Jobs[$i]["Status"]
          }
        }
        return $SyncHash["Results"]
      }
    )
    return $i
  }
  static [hashtable] GetSyncHash() {
    return (Get-Variable -Name $([PsRunner]::SyncId) -ValueOnly -Scope Global)
  }
  static [bool] HasPendingJobs() {
    $hpj = [PsRunner]::GetSyncHash()["Jobs"].Values.Keys.Contains("__PS")
    if (!$hpj) { Write-Warning "There are no pending jobs. Please run GetOutput(); and Add_BGWorker(); then try again." }
    return $hpj
  }
  static [int] GetWorkerId() {
    $Id = 0; do {
      $Id = ((Get-Runspace).Id)[-1] + 1
    } until ([PsRunner]::Isvalid_NewRunspaceId($Id, $false))
    return $Id
  }
  static [int] GetThreadCount() {
    $_PID = Get-Variable PID -ValueOnly
    return $(if ((Get-Variable IsLinux, IsMacOs).Value -contains $true) { &ps huH p $_PID | wc --lines } else { $(Get-Process -Id $_PID).Threads.Count })
  }
}
#endregion Classes

function Write-ProgressBar() {}
function Write-Spinner() {}
function Write-LoadingBar() {}

function Get-ProcessBitness {
  <#
  .SYNOPSIS
    A short one-line action-based description, e.g. 'Tests if a function is valid'
  .DESCRIPTION
    A longer description of the function, its purpose, common use cases, etc.
  .NOTES
    Information or caveats about the function e.g. 'This function is not supported in Linux'
  .LINK
    https://rkeithhill.wordpress.com/2014/04/28/how-to-determine-if-a-process-is-32-or-64-bit/
  #>
  [CmdletBinding()]
  param (
    # Parameter help description
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [int[]]$Ids
  )
  begin {
    $Signature = @{
      Namespace        = "Kernel32"
      Name             = "Bitness"
      Language         = "CSharp"
      MemberDefinition = @"
[DllImport("kernel32.dll", SetLastError = true, CallingConvention = CallingConvention.Winapi)]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool IsWow64Process(
	[In] System.IntPtr hProcess,
	[Out, MarshalAs(UnmanagedType.Bool)] out bool wow64Process);
"@
    }
    if (-not ("Kernel32.Bitness" -as [type])) {
      Add-Type @Signature
    }
  }

  process {
    Get-Process -Id $Ids | ForEach-Object -Process {
      $is32Bit = [int]0
      if ([Kernel32.Bitness]::IsWow64Process($_.Handle, [ref]$is32Bit)) {
        if ($is32Bit) {
          "$($_.Name) is 32-bit"
        } else {
          "$($_.Name) is 64-bit"
        }
      }
    }
  }
}

function New-Task {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  [Alias('Create-Task')]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [scriptblock][ValidateNotNullOrEmpty()]
    $ScriptBlock,

    [Parameter(Mandatory = $false, Position = 1)]
    [Object[]]
    $ArgumentList,

    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateNotNullOrEmpty()][System.Management.Automation.Runspaces.Runspace]
    $Runspace = (Get-Variable ExecutionContext -ValueOnly).Host.Runspace
  )
  begin {
    $_result = $null
    $powershell = [System.Management.Automation.PowerShell]::Create()
  }
  process {
    $_Action = $(if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ArgumentList')) {
        { Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList } -as [System.Action]
      } else {
        { Invoke-Command -ScriptBlock $ScriptBlock } -as [System.Action]
      }
    )
    $powershell = $powershell.AddScript({
        param (
          [Parameter(Mandatory = $true)]
          [ValidateNotNull()]
          [System.Action]$Action
        )
        return [System.Threading.Tasks.Task]::Factory.StartNew($Action)
      }
    ).AddArgument($_Action)
    if (!$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Runspace')) {
      $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    } else {
      Write-Verbose "[Task] Using LocalRunspace ..."
      $Runspace = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace
    }
    if ($Runspace.RunspaceStateInfo.State -ne 'Opened') { $Runspace.Open() }
    $powershell.Runspace = $Runspace
    [ValidateNotNull()][System.Action]$_Action = $_Action;
    Write-Verbose "[Task] Runing in background ..."
  }
  end {
    return $_result
  }
}

function Start-ProcessAsAdmin {
  <#
    .SYNOPSIS
    Runs a process with administrative privileges. If `-ExeToRun` is not
    specified, it is run with PowerShell.

    .NOTES
    Administrative Access Required.

    .INPUTS
    None

    .OUTPUTS
    None

    .PARAMETER Statements
    Arguments to pass to `ExeToRun` or the PowerShell script block to be
    run.

    .PARAMETER ExeToRun
    The executable/application/installer to run. Defaults to `'powershell'`.

    .PARAMETER Elevated
    Indicate whether the process should run elevated/aS Admin.

    Available in 0.10.2+.

    .PARAMETER Minimized
    Switch indicating if a Windows pops up (if not called with a silent
    argument) that it should be minimized.

    .PARAMETER NoSleep
    Used only when calling PowerShell - indicates the window that is opened
    should return instantly when it is complete.

    .PARAMETER ValidExitCodes
    Array of exit codes indicating success. Defaults to `@(0)`.

    .PARAMETER WorkingDirectory
    The working directory for the running process. Defaults to
    `Get-Location`. If current location is a UNC path, uses
    `$env:TEMP` for default as of 0.10.14.

    Available in 0.10.1+.

    .PARAMETER SensitiveStatements
    Arguments to pass to  `ExeToRun` that are not logged.

    Note that only licensed versions of Chocolatey provide a way to pass
    those values completely through without having them in the install
    script or on the system in some way.

    Available in 0.10.1+.

    .PARAMETER IgnoredArguments
    Allows splatting with arguments that do not apply. Do not use directly.

    .EXAMPLE
    Start-ProcessAsAdmin -Statements "$msiArgs" -ExeToRun 'msiexec'

    .EXAMPLE
    Start-ProcessAsAdmin -Statements "$silentArgs" -ExeToRun $file

    .EXAMPLE
    Start-ProcessAsAdmin -Statements "$silentArgs" -ExeToRun $file -ValidExitCodes @(0,21)

    .EXAMPLE
    >
    # Run PowerShell statements
    $psFile = Join-Path "$(Split-Path -parent $MyInvocation.MyCommand.Definition)" 'someInstall.ps1'
    Start-ProcessAsAdmin "& `'$psFile`'"

    .EXAMPLE
    # This also works for cmd and is required if you have any spaces in the paths within your command
    $appPath = "$env:ProgramFiles\myapp"
    $cmdBatch = "/c `"$appPath\bin\installmyappservice.bat`""
    Start-ProcessAsAdmin $cmdBatch cmd
    # or more explicitly
    Start-ProcessAsAdmin -Statements $cmdBatch -ExeToRun "cmd.exe"

    .LINK
    Install-DotfilePackage

    .LINK
    Install-DotfilePackage
    #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [parameter(Mandatory = $false, Position = 0)][string[]] $statements,
    [parameter(Mandatory = $false, Position = 1)][string] $exeToRun = 'powershell',
    [parameter(Mandatory = $false)][switch] $elevated,
    [parameter(Mandatory = $false)][switch] $minimized,
    [parameter(Mandatory = $false)][switch] $noSleep,
    [parameter(Mandatory = $false)] $validExitCodes = @(0),
    [parameter(Mandatory = $false)][string] $workingDirectory = $null,
    [parameter(Mandatory = $false)][string] $sensitiveStatements = ''
  )

  DynamicParam {
    $DynamicParams = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    #region IgnoredArguments
    $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
    $attributes = [System.Management.Automation.ParameterAttribute]::new(); $attHash = @{
      Position                        = 8
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
    #endregion IgnoredArguments
    return $DynamicParams
  }

  Process {
    $PsCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
    [string]$statements = $statements -join ' '
    # Log Invocation  and Parameters used. $MyInvocation, $PSBoundParameters

    if ($null -eq $workingDirectory) {
      # $pwd = $(Get-Location -PSProvider 'FileSystem')
      if ($pwd -eq $null -or $null -eq $pwd.ProviderPath) {
        Write-Debug "Unable to use current location for Working Directory. Using Cache Location instead."
        $workingDirectory = $env:TEMP
      }
      $workingDirectory = $pwd.ProviderPath
    }
    $alreadyElevated = $false
    [bool]$IsAdmin = $((New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator));
    if ($IsAdmin) {
      $alreadyElevated = $true
    } else {
      Write-Warning "$fxn : [!]  It seems You're not Admin [!] "
      break
    }


    $dbMessagePrepend = "Elevating permissions and running"
    if (!$elevated) {
      $dbMessagePrepend = "Running"
    }

    try {
      if ($null -ne $exeToRun) { $exeToRun = $exeToRun -replace "`0", "" }
      if ($null -ne $statements) { $statements = $statements -replace "`0", "" }
    } catch {
      Write-Debug "Removing null characters resulted in an error - $($_.Exception.Message)"
    }

    if ($null -ne $exeToRun) {
      $exeToRun = $exeToRun.Trim().Trim("'").Trim('"')
    }

    $wrappedStatements = $statements
    if ($null -eq $wrappedStatements) { $wrappedStatements = '' }

    if ($exeToRun -eq 'powershell') {
      $exeToRun = "$($env:SystemRoot)\System32\WindowsPowerShell\v1.0\powershell.exe"
      $importChocolateyHelpers = "& import-module -name '$helpersPath\chocolateyInstaller.psm1' -Verbose:`$false | Out-Null;"
      $block = @"
        `$noSleep = `$$noSleep
        #`$env:dotfilesEnvironmentDebug='false'
        #`$env:dotfilesEnvironmentVerbose='false'
        $importChocolateyHelpers
        try{
            `$progressPreference="SilentlyContinue"
            $statements
            if(!`$noSleep){start-sleep 6}
        }
        catch{
            if(!`$noSleep){start-sleep 8}
            throw
        }
"@
      $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($block))
      $wrappedStatements = "-NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -InputFormat Text -OutputFormat Text -EncodedCommand $encoded"
      $dbgMessage = @"
$dbMessagePrepend powershell block:
$block
This may take a while, depending on the statements.
"@
    } else {
      $dbgMessage = @"
$dbMessagePrepend [`"$exeToRun`" $wrappedStatements]. This may take a while, depending on the statements.
"@
    }

    Write-Debug $dbgMessage

    $exeIsTextFile = [System.IO.Path]::GetFullPath($exeToRun) + ".istext"
    if ([System.IO.File]::Exists($exeIsTextFile)) {
      Set-PowerShellExitCode 4
      throw "The file was a text file but is attempting to be run as an executable - '$exeToRun'"
    }

    if ($exeToRun -eq 'msiexec' -or $exeToRun -eq 'msiexec.exe') {
      $exeToRun = "$($env:SystemRoot)\System32\msiexec.exe"
    }

    if (!([System.IO.File]::Exists($exeToRun)) -and $exeToRun -notmatch 'msiexec') {
      Write-Warning "May not be able to find '$exeToRun'. Please use full path for executables."
      # until we have search paths enabled, let's just pass a warning
      #Set-PowerShellExitCode 2
      #throw "Could not find '$exeToRun'"
    }

    # Redirecting output slows things down a bit.
    $writeOutput = {
      if ($null -ne $EventArgs.Data) {
        Write-Verbose "$($EventArgs.Data)"
      }
    }

    $writeError = {
      if ($null -ne $EventArgs.Data) {
        Write-Error "$($EventArgs.Data)"
      }
    }

    $process = New-Object System.Diagnostics.Process
    $process.EnableRaisingEvents = $true
    Register-ObjectEvent -InputObject $process -SourceIdentifier "LogOutput_ChocolateyProc" -EventName OutputDataReceived -Action $writeOutput | Out-Null
    Register-ObjectEvent -InputObject $process -SourceIdentifier "LogErrors_ChocolateyProc" -EventName ErrorDataReceived -Action $writeError | Out-Null

    #$process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($exeToRun, $wrappedStatements)
    # in case empty args makes a difference, try to be compatible with the older
    # version
    $psi = New-Object System.Diagnostics.ProcessStartInfo

    $psi.FileName = $exeToRun
    if ($wrappedStatements -ne '') {
      $psi.Arguments = "$wrappedStatements"
    }
    if ($null -ne $sensitiveStatements -and $sensitiveStatements -ne '') {
      Write-Info "Sensitive arguments have been passed. Adding to arguments."
      $psi.Arguments += " $sensitiveStatements"
    }
    $process.StartInfo = $psi

    # process start info
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.WorkingDirectory = $workingDirectory

    if ($elevated -and -not $alreadyElevated -and [Environment]::OSVersion.Version -ge (New-Object 'Version' 6, 0)) {
      # this doesn't actually currently work - because we are not running under shell execute
      Write-Debug "Setting RunAs for elevation"
      $process.StartInfo.Verb = "RunAs"
    }
    if ($minimized) {
      $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
    }
    if ($PSCmdlet.ShouldProcess("`$process", "Start Process")) {
      $process.Start() | Out-Null
      if ($process.StartInfo.RedirectStandardOutput) { $process.BeginOutputReadLine() }
      if ($process.StartInfo.RedirectStandardError) { $process.BeginErrorReadLine() }
      $process.WaitForExit()

      # For some reason this forces the jobs to finish and waits for
      # them to do so. Without this it never finishes.
      Unregister-Event -SourceIdentifier "LogOutput_ChocolateyProc"
      Unregister-Event -SourceIdentifier "LogErrors_ChocolateyProc"

      # sometimes the process hasn't fully exited yet.
      for ($loopCount = 1; $loopCount -le 15; $loopCount++) {
        if ($process.HasExited) { break; }
        Write-Debug "Waiting for process to exit - $loopCount/15 seconds";
        Start-Sleep 1;
      }

      $exitCode = $process.ExitCode
      $process.Dispose()

      Write-Debug "Command [`"$exeToRun`" $wrappedStatements] exited with `'$exitCode`'."
    }
    $exitErrorMessage = ''
    $errorMessageAddendum = " This is most likely an issue with the '$env:dotfilesPackageName' package and not with Chocolatey itself. Please follow up with the package maintainer(s) directly."

    switch ($exitCode) {
      0 { break }
      1 { break }
      3010 { break }
      # NSIS - http://nsis.sourceforge.net/Docs/AppendixD.html
      # InnoSetup - http://www.jrsoftware.org/ishelp/index.php?topic=setupexitcodes
      2 { $exitErrorMessage = 'Setup was cancelled.'; break }
      3 { $exitErrorMessage = 'A fatal error occurred when preparing or moving to next install phase. Check to be sure you have enough memory to perform an installation and try again.'; break }
      4 { $exitErrorMessage = 'A fatal error occurred during installation process.' + $errorMessageAddendum; break }
      5 { $exitErrorMessage = 'User (you) cancelled the installation.'; break }
      6 { $exitErrorMessage = 'Setup process was forcefully terminated by the debugger.'; break }
      7 { $exitErrorMessage = 'While preparing to install, it was determined setup cannot proceed with the installation. Please be sure the software can be installed on your system.'; break }
      8 { $exitErrorMessage = 'While preparing to install, it was determined setup cannot proceed with the installation until you restart the system. Please reboot and try again.'; break }
      # MSI - https://msdn.microsoft.com/en-us/library/windows/desktop/aa376931.aspx
      1602 { $exitErrorMessage = 'User (you) cancelled the installation.'; break }
      1603 { $exitErrorMessage = "Generic MSI Error. This is a local environment error, not an issue with a package or the MSI itself - it could mean a pending reboot is necessary prior to install or something else (like the same version is already installed). Please see MSI log if available. If not, try again adding `'--install-arguments=`"`'/l*v c:\$($env:dotfilesPackageName)_msi_install.log`'`"`'. Then search the MSI Log for `"Return Value 3`" and look above that for the error."; break }
      1618 { $exitErrorMessage = 'Another installation currently in progress. Try again later.'; break }
      1619 { $exitErrorMessage = 'MSI could not be found - it is possibly corrupt or not an MSI at all. If it was downloaded and the MSI is less than 30K, try opening it in an editor like Notepad++ as it is likely HTML.' + $errorMessageAddendum; break }
      1620 { $exitErrorMessage = 'MSI could not be opened - it is possibly corrupt or not an MSI at all. If it was downloaded and the MSI is less than 30K, try opening it in an editor like Notepad++ as it is likely HTML.' + $errorMessageAddendum; break }
      1622 { $exitErrorMessage = 'Something is wrong with the install log location specified. Please fix this in the package silent arguments (or in install arguments you specified). The directory specified as part of the log file path must exist for an MSI to be able to log to that directory.' + $errorMessageAddendum; break }
      1623 { $exitErrorMessage = 'This MSI has a language that is not supported by your system. Contact package maintainer(s) if there is an install available in your language and you would like it added to the packaging.'; break }
      1625 { $exitErrorMessage = 'Installation of this MSI is forbidden by system policy. Please contact your system administrators.'; break }
      1632 { $exitErrorMessage = 'Installation of this MSI is not supported on this platform. Contact package maintainer(s) if you feel this is in error or if you need an architecture that is not available with the current packaging.'; break }
      1633 { $exitErrorMessage = 'Installation of this MSI is not supported on this platform. Contact package maintainer(s) if you feel this is in error or if you need an architecture that is not available with the current packaging.'; break }
      1638 { $exitErrorMessage = 'This MSI requires uninstall prior to installing a different version. Please ask the package maintainer(s) to add a check in the chocolateyInstall.ps1 script and uninstall if the software is installed.' + $errorMessageAddendum; break }
      1639 { $exitErrorMessage = 'The command line arguments passed to the MSI are incorrect. If you passed in additional arguments, please adjust. Otherwise followup with the package maintainer(s) to get this fixed.' + $errorMessageAddendum; break }
      1640 { $exitErrorMessage = 'Cannot install MSI when running from remote desktop (terminal services). This should automatically be handled in licensed editions. For open source editions, you may need to run change.exe prior to running Chocolatey or not use terminal services.'; break }
      1645 { $exitErrorMessage = 'Cannot install MSI when running from remote desktop (terminal services). This should automatically be handled in licensed editions. For open source editions, you may need to run change.exe prior to running Chocolatey or not use terminal services.'; break }
    }

    if ($exitErrorMessage) {
      $errorMessageSpecific = "Exit code indicates the following: $exitErrorMessage."
      Write-Warning $exitErrorMessage
    } else {
      $errorMessageSpecific = 'See log for possible error messages.'
    }

    if ($validExitCodes -notcontains $exitCode) {
      Set-PowerShellExitCode $exitCode
      throw "Running [`"$exeToRun`" $wrappedStatements] was not successful. Exit code was '$exitCode'. $($errorMessageSpecific)"
    } else {
      $chocoSuccessCodes = @(0, 1605, 1614, 1641, 3010)
      if ($chocoSuccessCodes -notcontains $exitCode) {
        Write-Warning "Exit code '$exitCode' was considered valid by script, but not as a Chocolatey success code. Returning '0'."
        $exitCode = 0
      }
    }

    Write-Debug "Finishing '$($MyInvocation.InvocationName)'"

    return $exitCode
  }
}
<#
    $ShimGen = [System.IO.Path]::GetFullPath($ShimGen)
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = new-object System.Diagnostics.ProcessStartInfo($ShimGen, $ShimGenArgs)
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $process.Start() | Out-Null
    $process.WaitForExit()
#>

<# Start PROCESS UTF8
# $standardOut = @(Start-Utf8Process $script:OMPExecutable @("print", "tooltip", "--pwd=$cleanPWD", "--shell=powershell", "--pswd=$cleanPSWD", "--config=$env:POSH_THEME", "--command=$command", "--shell-version=$script:PSVersion"))
    function Start-Utf8Process {
        param(
            [string]$FileName,
            [string[]]$Arguments = @()
        )

        $Process = New-Object System.Diagnostics.Process
        $StartInfo = $Process.StartInfo
        $StartInfo.FileName = $FileName
        if ($StartInfo.ArgumentList.Add) {
            # ArgumentList is supported in PowerShell 6.1 and later (built on .NET Core 2.1+)
            # ref-1: https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.argumentlist?view=net-6.0
            # ref-2: https://docs.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell?view=powershell-7.2#net-framework-vs-net-core
            $Arguments | ForEach-Object -Process { $StartInfo.ArgumentList.Add($_) }
        } else {
            # escape arguments manually in lower versions, refer to https://docs.microsoft.com/en-us/previous-versions/17w5ykft(v=vs.85)
            $escapedArgs = $Arguments | ForEach-Object {
                # escape N consecutive backslash(es), which are followed by a double quote, to 2N consecutive ones
                $s = $_ -replace '(\\+)"', '$1$1"'
                # escape N consecutive backslash(es), which are at the end of the string, to 2N consecutive ones
                $s = $s -replace '(\\+)$', '$1$1'
                # escape double quotes
                $s = $s -replace '"', '\"'
                # quote the argument
                "`"$s`""
            }
            $StartInfo.Arguments = $escapedArgs -join ' '
        }
        $StartInfo.StandardErrorEncoding = $StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $StartInfo.RedirectStandardError = $StartInfo.RedirectStandardInput = $StartInfo.RedirectStandardOutput = $true
        $StartInfo.UseShellExecute = $false
        if ($PWD.Provider.Name -eq 'FileSystem') {
            $StartInfo.WorkingDirectory = $PWD.ProviderPath
        }
        $StartInfo.CreateNoWindow = $true
        [void]$Process.Start()

        # we do this to remove a deadlock potential on Windows
        $stdoutTask = $Process.StandardOutput.ReadToEndAsync()
        $stderrTask = $Process.StandardError.ReadToEndAsync()
        [void]$Process.WaitForExit()
        $stderr = $stderrTask.Result.Trim()
        if ($stderr -ne '') {
          $Host.UI.WriteErrorLine($stderr)
        }
        $stdoutTask.Result
#>
# elevated

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
      WriteLog $LogMsg -s:$_Success
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

function Invoke-Program {
  <#
		.SYNOPSIS
			This is a helper function that will invoke the SQL installers via command-line.

		.EXAMPLE
			PS> Invoke-Program -FilePath C:\file.exe -ComputerName SRV1

	#>
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
        if (-not $ps) {
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

function Monitor-Process {
  # .SYNOPSIS
  # Monitor process start/stop events
  # .DESCRIPTION
  # Monitors specified processes and reports when they start or stop running
  # .EXAMPLE
  # Get-Process | Monitor-Process
  # .PARAMETER process
  # Process object to monitor
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [System.Diagnostics.Process]$process
  )

  begin {
    # Initialize hash table to store process information
    $script:processTable = @{}

    # Create a timer for periodic checking
    $script:timer = New-Object System.Timers.Timer
    $script:timer.Interval = 1000 # Check every second

    # Register timer event
    Register-ObjectEvent -InputObject $script:timer -EventName Elapsed -Action {
      foreach ($proc in $script:processTable.Keys) {
        try {
          $process = Get-Process -Id $proc -ErrorAction SilentlyContinue
          if (-not $process -and $script:processTable[$proc]) {
            Write-Host "Process stopped: $($script:processTable[$proc].ProcessName) (ID: $proc)" -ForegroundColor Red
            $script:processTable.Remove($proc)
          }
        } catch {
          # Process already terminated
          Write-Host "Process stopped: $($script:processTable[$proc].ProcessName) (ID: $proc)" -ForegroundColor Red
          $script:processTable.Remove($proc)
        }
      }
    }

    # Start the timer
    $script:timer.Start()
  }

  process {
    # Add or update process in the tracking table
    if (-not $script:processTable.ContainsKey($process.Id)) {
      Write-Host "Now monitoring process: $($process.ProcessName) (ID: $($process.Id))" -ForegroundColor Green
      $script:processTable[$process.Id] = @{
        ProcessName = $process.ProcessName
        StartTime   = $process.StartTime
      }
    }
  }

  end {
    # Register cleanup for when the script ends
    $MyInvocation.MyCommand.Module.OnRemove = {
      if ($script:timer) {
        $script:timer.Stop()
        $script:timer.Dispose()
      }
      Write-Host "Stopped monitoring processes" -ForegroundColor Yellow
    }

    Write-Host "Monitoring started. Press Ctrl+C to stop." -ForegroundColor Cyan

    try {
      while ($true) {
        Start-Sleep -Seconds 1
      }
    } finally {
      # Cleanup if the script is interrupted
      if ($script:timer) {
        $script:timer.Stop()
        $script:timer.Dispose()
      }
      Write-Host "Stopped monitoring processes" -ForegroundColor Yellow
    }
  }
}
