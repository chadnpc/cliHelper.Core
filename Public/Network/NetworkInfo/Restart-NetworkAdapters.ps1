function Restart-NetworkAdapters {
  # .SYNOPSIS
  # 	Restarts the network adapters (needs admin rights)
  # .DESCRIPTION
  # 	This PowerShell script restarts all local network adapters (needs admin rights).
  # .EXAMPLE
  # 	PS> Restart-NetworkAdapters
  # .INPUTS
  # 	Inputs (if any)
  # .OUTPUTS
  # 	Output (if any)
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [string[]]$NetAdapters
  )

  begin {
    #Requires -RunAsAdministrator
  }

  process {
    $StopWatch = [system.diagnostics.stopwatch]::startNew()
    try {
      Get-NetAdapter | Restart-NetAdapter
      [int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
      $msg = "✅ Successfuly restarted all local network adapters"
      Out-Verbose $fxn "restarted all local network adapters in $Elapsed sec"
      # success
    } catch {
      $msg = "Failed to restart network adapters."
      # Write-Log $_.Exception.ErrorRecord
      Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
    } finally {
      Out-Verbose $fxn "$msg in $Elapsed sec"
    }
  }
}