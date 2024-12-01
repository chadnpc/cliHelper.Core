function Start-PacketTrace {
  # .SYNOPSIS
  # 	This function starts a packet trace using netsh. Upon completion, it will begin capture all
  # 	packets coming into and leaving the local computer and will continue to do do until
  # 	Stop-PacketCapture is executed.
  # .EXAMPLE
  # 	PS> Start-PacketTrace -TraceFilePath C:\Tracefile.etl

  # 		This example will begin a packet capture on the local computer and place all activity
  # 		in the ETL file C:\Tracefile.etl.

  # .PARAMETER TraceFilePath
  # 	The file path where the trace file will be placed and recorded to. This file must be an ETL file.

  # .PARAMETER Force
  # 	Use the Force parameter to overwrite the trace file if one exists already

  # .INPUTS
  # 	None. You cannot pipe objects to Start-PacketTrace.

  # .OUTPUTS
  # 	None. Start-PacketTrace returns no output upon success.
  [CmdletBinding()]
  param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -Path ($_ | Split-Path -Parent) -PathType Container })]
    [ValidatePattern('.*\.etl$')]
    [string[]]$TraceFilePath,
    [Parameter()]
    [switch]$Force
  )

  begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
  }
  process {
    try {
      if (Test-Path -Path $TraceFilePath -PathType Leaf) {
        if (!($Force.IsPresent)) {
          throw "An existing trace file was found at [$($TraceFilePath)] and -Force was not used. Exiting.."
        } else {
          Remove-Item -Path $TraceFilePath
        }
      }
      $OutFile = "$PSScriptRoot\temp.txt"
      $Process = Start-Process "$($env:windir)\System32\netsh.exe" -ArgumentList "trace start persistent=yes capture=yes tracefile=$TraceFilePath" -RedirectStandardOutput $OutFile -Wait -NoNewWindow -PassThru
      if ($Process.ExitCode -notin @(0, 3010)) {
        throw "Failed to start the packet trace. Netsh exited with an exit code [$($Process.ExitCode)]"
      } else {
        Write-Verbose -Message "Successfully started netsh packet capture. Capturing all activity to [$($TraceFilePath)]"
      }
    } catch {
      Write-Error -Message "$($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
    } finally {
      if (Test-Path -Path $OutFile -PathType Leaf) {
        Remove-Item -Path $OutFile
      }
    }
  }
}