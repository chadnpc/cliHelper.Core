function Test-ConnectionAsync {
  <#
  .SYNOPSIS
    Performs a ping test asynchronously
  .DESCRIPTION
    Performs a ping test asynchronously
  .PARAMETER ComputerName
    List of computers to test connection. Aliased to 'CN', 'Server'
  .PARAMETER Timeout
    Timeout in milliseconds. Default 2000 ms.
  .PARAMETER TimeToLive
    Sets a time to live on ping request. Default 128.
  .PARAMETER BufferSize
    How large you want the buffer to be. Valid range 32-65500, default of 32. If the buffer is 1501 bytes or greater then the ping can fragment.
  .PARAMETER IncludeSource
    A switch determining if you want the source computer name to appear in the output
  .PARAMETER Full
    A switch determining if full output appears
  .NOTES
    Inspired by Test-ConnectionAsync by 'Boe Prox'
    https://gallery.technet.microsoft.com/scriptcenter/Asynchronous-Network-Ping-abdf01aa
  .OUTPUTS
      [pscustomobject] with output from Net.AsyncPingResult and optionally the source address
  .EXAMPLE
      Test-ConnectionAsync google.com, youtube.com, bing.com, github.com, alainQtec.dev

      ComputerName  IPAddress        Result
      ------------  ---------        ------
      google.com    172.217.170.206 Success
      youtube.com   172.217.170.174 Success
      bing.com      204.79.197.200  Success
      github.com    140.82.121.4    Success
      alainQtec.dev 185.199.110.153 Success


    Description
    -----------
    Performs asynchronous ping test against listed systems and lists brief output.
  .EXAMPLE
    Test-ConnectionAsync google.com, youtube.com, bing.com, github.com, alainQtec.dev -Full | ft

    ComputerName  IPAddress        Result BufferSize ResponseTime DontFragment Timeout TimeToLive
    ------------  ---------        ------ ---------- ------------ ------------ ------- ----------
    google.com    172.217.170.206 Success         32           79         True    2000        128
    youtube.com   172.217.170.174 Success         32           79         True    2000        128
    bing.com      204.79.197.200  Success         32          137         True    2000        128
    github.com    140.82.121.3    Success         32          252         True    2000        128
    alainQtec.dev 185.199.110.153 Success         32          136         True    2000        128

    Description
    -----------
    Performs asynchronous ping test against listed systems and lists full output.
  .EXAMPLE
    Test-ConnectionAsync -ComputerName server1,server2 -Full -BufferSize 1500

    ComputerName IPAddress    BufferSize  Result ResponseTime
      ------------ ---------    ----------  ------ ------------
    server1      192.168.1.31       1500 Success          140
    server2      192.168.1.41       1500 Success          137

    Description
    -----------
    Performs asynchronous ping test against listed systems and lists full output with a buffersize of 1500 bytes.
  .NOTES
    On linux ---> System.PlatformNotSupportedException: Unable to send custom ping payload. Run program under privileged user account or grant cap_net_raw capability using setcap(8).
  #>
  [CmdletBinding(ConfirmImpact = 'None')]
  [OutputType([AsyncPingResult[]])]
  Param (
    [parameter(ValueFromPipeline, Position = 0)]
    [string[]] $ComputerName,

    [parameter()]
    [int] $Timeout = 2000,

    [parameter()]
    [Alias('Ttl')]
    [int] $TimeToLive = 128,

    [parameter()]
    [validaterange(32, 65500)]
    [int] $BufferSize = 32,

    [parameter()]
    [switch] $IncludeSource,

    [parameter()]
    [switch] $Full
  )

  begin {
    #Requires -Version 3.0
    $result = @(); if ($IncludeSource) { $Source = $env:COMPUTERNAME }
    $Buffer = [System.Collections.ArrayList]::new()
    1..$BufferSize | ForEach-Object { $null = $Buffer.Add(([byte] [char] 'A')) }
    $PingOptions = [System.Net.NetworkInformation.PingOptions]::new()
    $PingOptions.Ttl = $TimeToLive
    $DontFragment = $BufferSize -le 1500 ? $true : $false
    @{
      ComputerName  = "[$($ComputerName -join ', ')]"
      BufferSize    = "[$BufferSize]"
      Timeout       = "[$Timeout]"
      TimeToLive    = "[$TimeToLive]"
      IncludeSource = "[$IncludeSource]"
      Full          = "[$Full]"
      DontFragment  = "[$DontFragment]"
    } | Write-Host -f Green
    $PingOptions.DontFragment = $DontFragment
    $Computerlist = [System.Collections.ArrayList]::new()
    class AsyncPingResult {
      [string]$Result
      [string]$IPAddress
      [int]$ResponseTime
      [int]$BufferSize
      hidden [string]$ComputerName
      hidden [bool]$DontFragment
      hidden [string]$Source
      hidden $TimeToLive
      hidden $Timeout
    }
  }

  process {
    foreach ($Computer in $ComputerName) {
      [void]$Computerlist.Add($Computer)
    }
    $Task = foreach ($Computer in $ComputerList) {
      [pscustomobject] @{
        ComputerName = $Computer
        Task         = [System.Net.NetworkInformation.Ping]::new().SendPingAsync($Computer, $Timeout, $Buffer, $PingOptions)
      }
    }
    try {
      [void] [Threading.Tasks.Task]::WaitAll($Task.Task)
    } catch {
      $_ | Format-List * -Force | Out-String | Write-Host -f Red
      Write-Error -Message "⛔ Error checking [$Computer]"
    }
    $result = @();
    $Task | ForEach-Object {
      $r = [AsyncPingResult]::new()
      if ($_.Task.IsFaulted) {
        $r.Result = $_.Task.Exception.InnerException.InnerException.Message
        $r.IPAddress = $Null
        $r.ResponseTime = $Null
      } else {
        $r.Result = $_.Task.Result.Status
        $r.IPAddress = $_.task.Result.Address.ToString()
        $r.ResponseTime = $_.task.Result.RoundtripTime
      }
      $r.ComputerName = $_.ComputerName
      $r.BufferSize = $BufferSize
      $r.Timeout = $Timeout
      $r.TimeToLive = $TimeToLive
      $r.DontFragment = $DontFragment
      if ($IncludeSource) { $r.Source = $Source }
      $result += $r
    }
  }

  end {
    return $result
  }
}