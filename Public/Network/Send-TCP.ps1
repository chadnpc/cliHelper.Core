function Send-TCP {
  # .SYNOPSIS
  # 	Sends a TCP message to an IP address and port
  # .DESCRIPTION
  # 	This PowerShell script sends a TCP message to the given IP address and port.
  # .PARAMETER TargetIP
  # 	Specifies the target IP address
  # .PARAMETER TargetPort
  # 	Specifies the target port number
  # .PARAMETER Message
  # 	Specifies the message to send
  # .EXAMPLE
  # 	PS> Send-TCP 192.168.100.100 8080 "TEST"
  Param([string]$TargetIP = "", [int]$TargetPort = 0, [string]$Message = "")

  try {
    if ($TargetIP -eq "" ) { $TargetIP = Read-Host "Enter target IP address" }
    if ($TargetPort -eq 0 ) { $TargetPort = Read-Host "Enter target port" }
    if ($Message -eq "" ) { $Message = Read-Host "Enter message to send" }

    $IP = [System.Net.Dns]::GetHostAddresses($TargetIP)
    $Address = [System.Net.IPAddress]::Parse($IP)
    $Socket = New-Object System.Net.Sockets.TCPClient($Address, $TargetPort)
    $Stream = $Socket.GetStream()
    $Writer = New-Object System.IO.StreamWriter($Stream)
    $Message | ForEach-Object {
      $Writer.WriteLine($_)
      $Writer.Flush()
    }
    $Stream.Close()
    $Socket.Close()

    Write-Info "✅  Done."
    # success
  } catch {
    # Write-Log $_.Exception.ErrorRecord
    Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
    break
  }
}