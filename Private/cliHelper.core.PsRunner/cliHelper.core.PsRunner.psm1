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

<#
.SYNOPSIS
  A simple progress utility class
.EXAMPLE
  for ($i = 0; $i -le 100; $i++) {
    [ProgressUtil]::WriteProgressBar($i, "doing stuff")
  }
.EXAMPLE
  [progressUtil]::WaitJob("waiting", { Start-Sleep -Seconds 3 })
#>
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
  static hidden [int] $_twirlIndex = 0
  static hidden [string]$frames
  static [void] WriteProgressBar([int]$percent) {
    [ProgressUtil]::WriteProgressBar($percent, $true, "")
  }
  static [void] WriteProgressBar([int]$percent, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $true, $message)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $update, [int]([Console]::WindowWidth * 0.7), $message)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [string]$message, [bool]$Completed) {
    [ProgressUtil]::WriteProgressBar($percent, $update, [int]([Console]::WindowWidth * 0.7), $message, $Completed)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $update, $PBLength, $message, $false)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength, [string]$message, [bool]$Completed) {
    [ValidateNotNull()][int]$PBLength = $PBLength
    [ValidateNotNull()][int]$percent = $percent
    [ValidateNotNull()][bool]$update = $update
    [ValidateNotNull()][string]$message = $message
    [ProgressUtil]::_back = "`b" * [Console]::WindowWidth
    if ($update) { [Console]::Write([ProgressUtil]::_back) }
    Write-Console ("{0} [" -f $message) -f SlateBlue -NoNewLine
    $p = [int](($percent / 100.0) * $PBLength + 0.5)
    for ($i = 0; $i -lt $PBLength; $i++) {
      if ($i -ge $p) {
        Write-Console ' ' -NoNewLine
      } else {
        Write-Console ([ProgressUtil]::_block) -f SlateBlue -NoNewLine
      }
    }
    Write-Console ("] {0,3:##0}%" -f $percent) -f SlateBlue -NoNewLine:(!$Completed)
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
      $_src_txt = '@(${Function:' + $obj.Name + '}.Ast.Extent.Text)'
      $FunctionText = [scriptblock]::Create($_src_txt).InvokeReturnAsIs()
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
              Invoke-Expression -Command $obj
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

# function Write-ProgressBar() {}
# function Write-Spinner() {}
# function Write-LoadingBar() {}
