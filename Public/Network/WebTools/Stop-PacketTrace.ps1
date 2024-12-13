function Stop-PacketTrace {
  # .SYNOPSIS
  # 	This function stops a packet trace that is currently running using netsh.
  # .EXAMPLE
  # 	Stop-PacketTrace
  #  This example stops any running netsh packet capture.
  # .INPUTS
  # 	None. You cannot pipe objects to Stop-PacketTrace.
  # .OUTPUTS
  # 	None. Stop-PacketTrace returns no output upon success.
  [CmdletBinding()]
  param()

  process {
    try {
      $OutFile = "$PSScriptRoot\temp.txt"
      $Process = Start-Process "$($env:windir)\System32\netsh.exe" -ArgumentList 'trace stop' -Wait -NoNewWindow -PassThru -RedirectStandardOutput $OutFile -ea Stop
      if ((Get-Content $OutFile) -eq 'There is no trace session currently in progress.') {
        Write-Verbose -Message 'There are no trace sessions currently in progress'
      } elseif ($Process.ExitCode -notin @(0, 3010)) {
        throw "Failed to stop the packet trace. Netsh exited with an exit code [$($Process.ExitCode)]"
      } else {
        Write-Verbose -Message 'Successfully stopped netsh packet capture'
      }
    } catch {
      Write-Error -Message "Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
    } finally {
      if (Test-Path -Path $OutFile -PathType Leaf) {
        Remove-Item -Path $OutFile
      }
    }
  }
}