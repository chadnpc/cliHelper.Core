function Start-ProcessMonitor {
  # .SYNOPSIS
  # Monitor process start/stop events
  # .DESCRIPTION
  # Monitors specified processes and reports when they start or stop running
  # .EXAMPLE
  # Get-Process | Start-ProcessMonitor
  # .PARAMETER process
  # Process object to monitor
  [CmdletBinding()]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification = "Not changing state")]
  [Alias('Monitor-Process')]
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
          if (!$process -and $script:processTable[$proc]) {
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
    if (!$script:processTable.ContainsKey($process.Id)) {
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