function Test-ports {
  #.SYNOPSIS
  # 	Scans the network for open/closed ports
  # .DESCRIPTION
  # 	This PowerShell script scans the network for open or closed ports.
  # .EXAMPLE
  # 	PS C:\> Test-ports
  # 	Explanation of what the example does
  # .INPUTS
  # 	Inputs (if any)
  # .OUTPUTS
  # 	Output (if any)
  [CmdletBinding()]
  param (
    [string]$network = "192.168.178",
    [string]$port = 8080,
    [int[]]$range = 1..254
  )

  process {
    foreach ($add in $range) {
      $ip = "{0}.{1}" -F $network, $add
      Write-Progress "Scanning IP $ip" -PercentComplete (($add / $range.Count) * 100)
      if (Test-Connection -BufferSize 32 -Count 1 -Quiet -ComputerName $ip) {
        $socket = New-Object System.Net.Sockets.TcpClient($ip, $port)
        if ($socket.Connected) {
          Write-Output "TCP port $port at $ip is open"
          $socket.Close()
        } else {
          Write-Output "TCP port $port at $ip is not open"
        }
      }
    }
  }
}
