function Invoke-Ping {
  <#
    .SYNOPSIS
        Tests a connection to a host.
    .PARAMETER Name
        IPAddress or DNS name to ping.
    .PARAMETER Count
        The number of pings to send.
    .PARAMETER IPv6
        Use IPv6
    .EXAMPLE
        Invoke-Ping -name www.google.com -count 2 -ipv6
    #>
  [cmdletbinding()]
  param(
    [parameter(Mandatory, Position = 0)]
    [string]$Name,

    [parameter(Position = 1)]
    [int]$Count = 5,

    [parameter(position = 2)]
    [switch]$IPv6
  )

  if ($PSBoundParameters.ContainsKey('IPv6')) {
    $r = Invoke-Command -ScriptBlock { ping.exe $Name -n $Count -6 -a }
  } else {
    $r = Invoke-Command -ScriptBlock { ping.exe $Name -n $Count -4 -a }
  }

  return ($r -Join "`n")
}