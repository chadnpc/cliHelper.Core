function Test-PortConnection {
  # .EXAMPLE
  # Test-PortConnection -TargetHost www.estel.ee -TargetPort 1424
  [cmdletbinding()]
  param(

    [parameter(mandatory = $true)]
    [string]$TargetHost,

    [parameter(mandatory = $true)]
    [int32]$TargetPort,

    [int32] $Timeout = 10000

  )
  process {

    $outputobj = New-Object -TypeName PSobject

    $outputobj | Add-Member -MemberType NoteProperty -Name TargetHostName -Value $TargetHost

    if (Test-Connection -ComputerName $TargetHost -Count 2) {
      $outputobj | Add-Member -MemberType NoteProperty -Name TargetHostStatus -Value "ONLINE"
    } else {
      $outputobj | Add-Member -MemberType NoteProperty -Name TargetHostStatus -Value "OFFLINE"
    }

    $outputobj | Add-Member -MemberType NoteProperty -Name PortNumber -Value $targetport

    $Socket = New-Object System.Net.Sockets.TCPClient
    $Connection = $Socket.BeginConnect($Targethost, $TargetPort, $null, $null)
    $Connection.AsyncWaitHandle.WaitOne($timeout, $false) | Out-Null

    if ($Socket.Connected -eq $true) {
      $outputobj | Add-Member -MemberType NoteProperty -Name ConnectionStatus -Value "Success"
    } else {
      $outputobj | Add-Member -MemberType NoteProperty -Name ConnectionStatus -Value "Failed"
    }

    $Socket.Close | Out-Null
    $outputobj | Select-Object TargetHostName, TargetHostStatus, PortNumber, Connectionstatus | Format-Table -AutoSize
  }
}