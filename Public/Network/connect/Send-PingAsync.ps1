function Send-PingAsync {
  # .EXAMPLE
  #   '192.168.1.5', '192.1..4444' | Send-PingAsync
  [CmdletBinding()]
  param (
    # Parameter help description
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$ips
  )

  process {
    $t = $ips | ForEach-Object {
      $(New-Object Net.NetworkInformation.Ping).SendPingAsync($_, 250)
    }
    [Threading.Tasks.Task]::WaitAll($t)
    $t.Result
  }
}