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
        * fixed logic around processing pipeline
        * removed $Buffer parameter
        * added $BufferSize parameter and dynamically create $Buffer from $BufferSize
        * added $IncludeSource so that source computer would be included in output
        * added $Full so that default output is brief
        * changed datatype of .IPAddress to [version] so that it can be sorted properly
    .OUTPUTS
        [pscustomobject] with output from Net.AsyncPingResult and optionally the source address
    .EXAMPLE
        Test-ConnectionAsync google.com, youtube.com, bing.com, github.com, alainQtec.com

        ComputerName  IPAddress        Result
        ------------  ---------        ------
        google.com    172.217.170.206 Success
        youtube.com   172.217.170.174 Success
        bing.com      204.79.197.200  Success
        github.com    140.82.121.4    Success
        alainQtec.com 185.199.110.153 Success


        Description
        -----------
        Performs asynchronous ping test against listed systems and lists brief output.
    .EXAMPLE
        Test-ConnectionAsync google.com, youtube.com, bing.com, github.com, alainQtec.com -Full | ft

        ComputerName  IPAddress        Result BufferSize ResponseTime DontFragment Timeout TimeToLive
        ------------  ---------        ------ ---------- ------------ ------------ ------- ----------
        google.com    172.217.170.206 Success         32           79         True    2000        128
        youtube.com   172.217.170.174 Success         32           79         True    2000        128
        bing.com      204.79.197.200  Success         32          137         True    2000        128
        github.com    140.82.121.3    Success         32          252         True    2000        128
        alainQtec.com 185.199.110.153 Success         32          136         True    2000        128

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
    #>
  #Requires -Version 3.0
  [OutputType('Net.AsyncPingResult')]
  [CmdletBinding(ConfirmImpact = 'None')]
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
    Out-Verbose "Starting      [$($MyInvocation.Mycommand)]"
    if ($IncludeSource) { $Source = $env:COMPUTERNAME }
    $Buffer = New-Object -TypeName System.Collections.ArrayList
    1..$BufferSize | ForEach-Object { $null = $Buffer.Add(([byte] [char] 'A')) }
    $PingOptions = New-Object -TypeName System.Net.NetworkInformation.PingOptions
    $PingOptions.Ttl = $TimeToLive
    If ($BufferSize -gt 1500) {
      $DontFragment = $false
    } else {
      $DontFragment = $true
    }
    Out-Verbose "ComputerName  [$($ComputerName -join ', ')]"
    Out-Verbose "BufferSize    [$BufferSize]"
    Out-Verbose "Timeout       [$Timeout]"
    Out-Verbose "TimeToLive    [$TimeToLive]"
    Out-Verbose "IncludeSource [$IncludeSource]"
    Out-Verbose "Full          [$Full]"
    Out-Verbose "DontFragment  [$DontFragment]"
    $PingOptions.DontFragment = $DontFragment
    $Computerlist = New-Object -TypeName System.Collections.ArrayList
  }

  process {
    foreach ($Computer in $ComputerName) {
      [void] $Computerlist.Add($Computer)
    }
  }

  end {
    $Task = foreach ($Computer in $ComputerList) {
      [pscustomobject] @{
        ComputerName = $Computer
        Task         = (New-Object -TypeName System.Net.NetworkInformation.Ping).SendPingAsync($Computer, $Timeout, $Buffer, $PingOptions)
      }
    }
    try {
      [void] [Threading.Tasks.Task]::WaitAll($Task.Task)
    } catch {
      Write-Error -Message "⛔ Error checking [$Computer]"
    }
    $Task | ForEach-Object {
      if ($_.Task.IsFaulted) {
        $Result = $_.Task.Exception.InnerException.InnerException.Message
        $IPAddress = $Null
        $ResponseTime = $Null
      } else {
        $Result = $_.Task.Result.Status
        $IPAddress = $_.task.Result.Address.ToString()
        $ResponseTime = $_.task.Result.RoundtripTime
      }
      $Layout = [ordered] @{
        ComputerName = $_.ComputerName
        IPAddress    = if ($IPAddress) { [version] $IPAddress } else { $Null }
        Result       = $Result
        BufferSize   = $BufferSize
        ResponseTime = $ResponseTime
        DontFragment = $DontFragment
        Timeout      = $Timeout
        TimeToLive   = $TimeToLive
      }
      if ($IncludeSource) {
        $Layout.Insert(0, 'Source', $Source)
      }
      $Object = New-Object -TypeName psobject -Property $Layout
      $Object.pstypenames.insert(0, 'Net.AsyncPingResult')
      if ($Full) {
        $Object
      } else {
        if ($IncludeSource) {
          $Object | Select-Object -Property Source, ComputerName, IPAddress, Result
        } else {
          $Object | Select-Object -Property ComputerName, IPAddress, Result
        }
      }
    }
    Out-Verbose $fxn "Complete."
  }
}
function Test-Connections {
  <#
        .Synopsis
            Test-Connection to multiple devices in parallel.
        .Description
            Test-Connection to multiple devcies in parallel with a color and "watch" feature.
        .Example
            Test-Connections -TargetName 1.1.1.1 -Watch
        .Example
            Test-Connections -TargetName 1.1.1.1, 1.0.0.1, 8.8.4.4, 8.8.8.8, 9.9.9.9 -Watch
        .Example
            Test-Connections 1.1.1.1, 1.0.0.1, 8.8.4.4, 8.8.8.8, 9.9.9.9 -Watch -Repeat
        .Example
            Test-Connections 1.1.1.1, 1.0.0.1, 8.8.4.4, 8.8.8.8, 9.9.9.9 -Count 10 -Watch
        .Example
            Test-Connections $(Get-Content servers.txt) -Watch
        .Example
            @("1.1.1.1", "1.0.0.1", "8.8.4.4", "8.8.8.8", "9.9.9.9") | Test-Connections -Watch
        .Example
            Connect-VIServer esxi.local
            Get-VM | Test-Connections -Watch
        .Example
            (1..10) | ForEach-Object { "192.168.0.$_" } | Test-Connections -Watch
        .Notes
            Name: Test-Connections
            Author: David Isaacson
            Last Edit: 2022-04-24
            Keywords: Test-Connection, ping, icmp
        .Link
            https://github.com/daisaacson/test-connections
        .Inputs
            TargetName[]
        .Outputs
            none
        #Requires -Version 2.0
    #>
  [CmdletBinding(SupportsShouldProcess = $True)]
  Param (
    [Parameter(Mandatory = $True, ValueFromPipeline = $True, HelpMessage = "Stop after sending Count pings")]
    [string[]]$TargetName,

    [Parameter(Mandatory = $False)]
    [Alias("c")]
    [int]$Count = 4,

    [Parameter(Mandatory = $False, HelpMessage = "Continjously send pings")]
    [Alias("Continuous", "t")]
    [switch]$Repeat,

    [Parameter(Mandatory = $False, HelpMessage = "Delay between pings")]
    [int]$Delay = 1,

    [Parameter(Mandatory = $False, HelpMessage = "Interval between pings")]
    [Alias("u")]
    [int]$Update = 1000,

    [Parameter(Mandatory = $False, HelpMessage = "Watch")]
    [Alias("w")]
    [Switch]$Watch
  )
  Begin {
    Write-Verbose -Message "Begin $($MyInvocation.MyCommand)"
    $Targets = @()
    # Destingwish between Windows PowerShell and PowerShell Core
    $WindowsPowerShell = $PSVersionTable.PSEdition -and $PSVersionTable.PSEdition -eq 'Desktop'
    $PowerShellCore = ! $WindowsPowerShell

    #region    Target_Class
    class Target {
      [String]$TargetName
      [String]$DNS
      hidden [PSObject]$Job
      [Int]$PingCount
      [boolean]$Status
      [Int]$Latency
      [Int]$LatencySum
      [Int]$SuccessSum
      [DateTime]$LastSuccessTime

      Target() {}
      Target([String]$TargetName, [PSObject]$Job) {
        $this.TargetName = $TargetName
        $this.Job = $Job
        $this.PingCount = 0
        $this.Status = $null
        $this.Latency = 0
        $this.LatencySum = 0
        $this.SuccessSum = 0
      }

      [String]ToString() {
        Return ("[{0}] {1} {2}ms {3:0.0}ms (avg) {4} {5:0.0}%" -f $this.Status, $this.TargetName, $this.Latency, $this.AverageLatency(), $this.PingCount, $this.PercentSuccess() )
      }

      [PSCustomObject]ToTable() {
        If ($Global:PSVersionTable.PSEdition -and $Global:PSVersionTable.PSEdition -eq 'Core') {
          if ($this.PingCount -eq 0) {
            $s = "`e[1;38;5;0;48;5;226m PEND `e[0m" # Yellow
          } elseif ($this.status) {
            $s = "`e[1;38;5;0;48;5;46m OKAY `e[0m"  # Green
          } else {
            $s = "`e[1;38;5;0;48;5;196m FAIL `e[0m" # Red
          }
        } else {
          if ($this.PingCount -eq 0) {
            $s = " PEND "
          } elseif ($this.status) {
            $s = "  OK  "
          } else {
            $s = " FAIL "
          }
        }
        Return [PSCustomObject]@{
          Status      = $s
          TargetName  = $this.TargetName
          ms          = $this.Latency
          Avg         = [math]::Round($this.AverageLatency(), 1)
          Count       = $this.PingCount
          Loss        = $this.PingCount - $this.SuccessSum
          Success     = [math]::Round($this.PercentSuccess(), 1)
          LastSuccess = $this.LastSuccessTime
        }
      }

      [void]Update() {
        $Data = Receive-Job -Id $this.Job.Id

        # If data is newer than update attributes
        If ($Data.ping -gt $this.PingCount) {
          $last = $Data | Select-Object -Last 1
          $this.PingCount = $last.Ping
          $this.Status = $last.Status -eq "Success"
          $this.SuccessSum += ($Data.Status | Where-Object { $_ -eq "Success" } | Measure-Object).Count
          if ($this.Status) {
            $this.Latency = $last.Latency
            $this.LatencySum += ($Data.Latency | Measure-Object -Sum).Sum
            $this.LastSuccessTime = Get-Date
          }
        }
      }

      [int]Count() {
        Return $this.PingCount
      }

      [float]PercentSuccess() {
        If (! $this.PingCount -eq 0) {
          Return $this.SuccessSum / $this.PingCount * 100
        }
        Return 0
      }

      [float]AverageLatency() {
        If (! $this.SuccessSum -eq 0) {
          Return $this.LatencySum / $this.SuccessSum
        }
        Return 0
      }
    }
    #endregion Target_Class
  }

  Process {
    Write-Verbose -Message "Process $($MyInvocation.MyCommand)"
    If ($pscmdlet.ShouldProcess("$TargetName")) {
      ForEach ($Target in $TargetName) {
        Write-Verbose -Message "$Target, $Count, $Delay, $Repeat"
        Try {
          If ($WindowsPowerShell) {
            # Create new Target and Start-Job
            # Windows PowerShell 5.1 Test-Connection sucks, wrapper for Test-Connection to behave more like Test-Connection in PowerShell Core
            $Targets += [Target]::new($Target, $(Start-Job -ScriptBlock $([ScriptBlock]::Create({
                      Param ([String]$TargetName, [int]$Count = 4, [int]$Delay = 1, [bool]$Repeat)
                      $Ping = 0
                      While ($Repeat -or $Count -gt $Ping) {
                        Write-Verbose "$($Repeat) $($Count) $($Ping)"
                        $Ping++
                        $icmp = Test-Connection -ComputerName $TargetName -Count 1 -ErrorAction SilentlyContinue
                        If ($icmp) {
                          [PSCustomObject]@{
                            Ping    = $Ping;
                            Status  = "Success"
                            Latency = $icmp.ResponseTime
                          }
                        } else {
                          [PSCustomObject]@{
                            Ping    = $Ping
                            Status  = "Failed"
                            Latency = 9999
                          }
                        }
                        Start-Sleep -Seconds $Delay
                      }
                    }
                  )
                ) -ArgumentList $Target, $Count, $Delay, $Repeat
              )
            )
          } else {
            If ($Repeat) {
              $Targets += [Target]::new($Target, $(Start-Job -ScriptBlock $([ScriptBlock]::Create({ Param ($Target) Test-Connection -TargetName $Target -Ping -Repeat })) -ArgumentList $Target))
            } else {
              $Targets += [Target]::new($Target, $(Start-Job -ScriptBlock $([ScriptBlock]::Create({ Param ($Target, $Count) Test-Connection -TargetName $Target -Ping -Count $Count })) -ArgumentList $Target, $Count))
            }
          }
        } Catch { $_ }
      }
    }
  }

  End {
    Write-Verbose -Message "End $($MyInvocation.MyCommand)"
    If ($pscmdlet.ShouldProcess("$TargetName")) {
      # https://blog.sheehans.org/2018/10/27/powershell-taking-control-over-ctrl-c/
      # Change the default behavior of CTRL-C so that the script can intercept and use it versus just terminating the script.
      [Console]::TreatControlCAsInput = $True
      # Sleep for 1 second and then flush the key buffer so any previously pressed keys are discarded and the loop can monitor for the use of
      #   CTRL-C. The sleep command ensures the buffer flushes correctly.
      Start-Sleep -Seconds 1
      $Host.UI.RawUI.FlushInputBuffer()
      # Continue to loop while there are pending or currently executing jobs.
      While ($Targets.Job.HasMoreData -contains "True") {
        # If a key was pressed during the loop execution, check to see if it was CTRL-C (aka "3"), and if so exit the script after clearing
        #   out any running jobs and setting CTRL-C back to normal.
        If ($Host.UI.RawUI.KeyAvailable -and ($Key = $Host.UI.RawUI.ReadKey("AllowCtrlC,NoEcho,IncludeKeyUp"))) {
          If ([Int]$Key.Character -eq 3) {
            Write-Warning -Message "Removing Test-Connection Jobs"
            If ($PowerShellCore) { Write-Host "`e[2A" }
            $Targets.Job | Remove-Job -Force
            $killed = $True
            [Console]::TreatControlCAsInput = $False

            break
          }
          # Flush the key buffer again for the next loop.
          $Host.UI.RawUI.FlushInputBuffer()
        }
        # Perform other work here such as process pending jobs or process out current jobs.

        # Get Test-Connection updates
        $Targets.Update()

        # Print Output
        $Targets.ToTable() | Format-Table

        # Move cursor up to overwrite old output
        If ($Watch -and $PowerShellCore) {
          Write-Host "`e[$($Targets.length+5)A"
        }

        # Output update delay
        Start-Sleep -Milliseconds $Update
      }

      # Clean up jobs
      If (!$killed) {
        $Targets.Job | Remove-Job -Force
      }

      # If in "Watch" mode, print output one last time
      If ($Watch) {
        $Targets.ToTable() | Format-Table
      }
    }
  }
}