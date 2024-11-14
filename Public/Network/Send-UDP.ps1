function Send-UDP {
  # .SYNOPSIS
  # 	Sends a UDP datagram message to an IP address and port
  # .DESCRIPTION
  # 	This PowerShell script sends a UDP datagram message to an IP address and port.
  # .PARAMETER TargetIP
  # 	Specifies the target IP address
  # .PARAMETER TargetPort
  # 	Specifies the target port number
  # .PARAMETER Message
  # 	Specifies the message text to send
  # .EXAMPLE
  # 	PS> send-udp 192.168.100.100 8080 "TEST"
  [CmdletBinding()]
  param(
    [string]$TargetIP = "",
    [int]$TargetPort = 0,
    [string]$Message = ""
  )

  try {
    if ($TargetIP -eq "" ) { $TargetIP = Read-Host "Enter target IP address" }
    if ($TargetPort -eq 0 ) { $TargetPort = Read-Host "Enter target port" }
    if ($Message -eq "" ) { $Message = Read-Host "Enter message to send" }

    $IP = [System.Net.Dns]::GetHostAddresses($TargetIP)
    $Address = [System.Net.IPAddress]::Parse($IP)
    $EndPoints = New-Object System.Net.IPEndPoint($Address, $TargetPort)
    $Socket = New-Object System.Net.Sockets.UDPClient
    $EncodedText = [Text.Encoding]::ASCII.GetBytes($Message)
    $SendMessage = $Socket.Send($EncodedText, $EncodedText.Length, $EndPoints)
    $SendMessage | Out-Null
    $Socket.Close()

    Write-Info "✅  Done."
    # success
  } catch {
    # Write-Log $_.Exception.ErrorRecord
    Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
    break
  }
}
