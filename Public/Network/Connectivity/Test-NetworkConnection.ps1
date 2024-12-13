function Test-NetworkConnection {
  <#
  .SYNOPSIS
    Testing the internet connectivity functionality from both Test-Connection and Test-NetConnection
  .NOTES
    This is the Modified Version Of the default TNC function.
    Still Needs more Fixing and testings at the time
  #>
  [CmdletBinding( )]
  Param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
    [Alias('RemoteAddress', 'cn')]
    [String] $ComputerName = "internetbeacon.msedge.net",

    [Parameter(ParameterSetName = "ICMP", Mandatory = $False)]
    [Switch] $TraceRoute,

    [Parameter(ParameterSetName = "ICMP", Mandatory = $False)]
    [ValidateRange(1, 120)]
    [Int] $Hops = 30,

    [Parameter(ParameterSetName = "CommonTCPPort", Mandatory = $True, Position = 1)]
    [ValidateSet("HTTP", "RDP", "SMB", "WINRM")]
    [String] $CommonTCPPort = "",

    [Parameter(ParameterSetName = "RemotePort", Mandatory = $True, ValueFromPipelineByPropertyName = $true)]
    [Alias('RemotePort')] [ValidateRange(1, 65535)]
    [Int] $Port = 0,

    [Parameter(ParameterSetName = "NetRouteDiagnostics", Mandatory = $True)]
    [Switch] $DiagnoseRouting,

    [Parameter(ParameterSetName = "NetRouteDiagnostics", Mandatory = $False)]
    [String] $ConstrainSourceAddress = "",

    [Parameter(ParameterSetName = "NetRouteDiagnostics", Mandatory = $False)]
    [UInt32] $ConstrainInterface = 0,
    [ValidateSet("Quiet", "Detailed", "Standard")]
    [String]$InformationLevel = "Standard",
    # Provide more description about the connectivity and issues that were found.
    [Parameter(Mandatory = $false)]
    [switch]$Describe
  )
  Begin {
    # ActionPreferences
    # $ogeap = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    #region Functions
    ##Description: Checks if the local execution context is elevated
    ##Input: None
    ##Output: Boolean. True if the local execution context is elevated.
    function CheckIfAdmin {
      $CurrentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
      $CurrentSecurityPrincipal = [System.Security.Principal.WindowsPrincipal]::new($CurrentIdentity)
      $AdminPrincipal = [System.Security.Principal.WindowsBuiltInRole]::Administrator
      return $CurrentSecurityPrincipal.IsInRole($AdminPrincipal)
    }

    ##Description: Resolves a hostname.
    ##Input: The user-provided computername that will be pinged/tested
    ##Output: The resolved IP addresses for computername
    function ResolveTargetName {
      param ($TargetName)

      $Addresses = $null
      try {
        $Addresses = [System.Net.Dns]::GetHostAddressesAsync($TargetName).GetAwaiter().GetResult()
      } catch {
        Write-Debug "Name resolution of $TargetName threw exception: $($_.Exception.Message)"
      }

      if ($null -eq $Addresses) {
        Write-Warning "Name resolution of $TargetName failed"
      }

      return $Addresses
    }

    ##Description: Pings a specified host
    ##Input: IP address to ping
    ##Output: PingReplyDetails for the ping attempt to host
    function PingTest {
      param ($TargetIPAddress)

      $Ping = [System.Net.NetworkInformation.Ping]::new()
      $PingReplyDetails = $null

      ##Indeterminate progress indication
      Write-Progress -Activity "Test-NetConnection :: $TargetIPAddress" -Status "Ping/ICMP Test" -CurrentOperation "Waiting for echo reply" -SecondsRemaining -1 -PercentComplete -1

      try {
        $PingReplyDetails = $Ping.SendPingAsync($TargetIPAddress).GetAwaiter().Getresult()
      } catch {
        Write-Debug "Ping to $TargetIPAddress threw exception: $($_.Exception.Message)"
      } finally {
        $Ping.Dispose()
      }

      return $PingReplyDetails
    }

    ##Description: Traces a route to a specified IP address using repetitive echo requests
    ##Input: IP address to trace against
    ##Output: Array of IP addresses representing the traced route. The message from the ping reply status is emmited, if there is no response.
    function TraceRoute {
      param ($TargetIPAddress, $Hops)

      $Ping = [System.Net.NetworkInformation.Ping]::new()
      $PingOptions = [System.Net.NetworkInformation.PingOptions]::new()
      $PingOptions.Ttl = 1
      [Byte[]]$DataBuffer = @()
      1..10 | ForEach-Object { $DataBuffer += [Byte]0 }
      $ReturnTrace = @()

      do {
        try {
          $CurrentHop = [int] $PingOptions.Ttl
          Write-Progress -CurrentOperation "TTL = $CurrentHop" -Status "ICMP Echo Request (Max TTL = $Hops)" -Activity "TraceRoute" -PercentComplete -1 -SecondsRemaining -1
          $PingReplyDetails = $Ping.SendPingAsync($TargetIPAddress, 4000, $DataBuffer, $PingOptions).GetAwaiter().Getresult()

          if ($null -eq $PingReplyDetails.Address) {
            $ReturnTrace += $PingReplyDetails.Status.ToString()
          } else {
            $ReturnTrace += $PingReplyDetails.Address.IPAddressToString
          }
        } catch {
          Write-Debug "Ping to $TargetIPAddress threw exception: $($_.Exception.Message)"
          $ReturnTrace += "..."
        }
        $PingOptions.Ttl++
      }
      while (($PingReplyDetails.Status -ne 'Success') -and ($PingOptions.Ttl -le $Hops))

      ##If the last entry in the trace does not equal the target, then the trace did not successfully complete
      if ($ReturnTrace[-1] -ne $TargetIPAddress) {
        $OutputString = "Trace route to destination " + $TargetIPAddress + " did not complete. Trace terminated :: " + $ReturnTrace[-1]
        Write-Warning $OutputString
      }

      $Ping.Dispose()
      return $ReturnTrace
    }

    ##Description: Attempts a TCP connection against a specified IP address
    ##Input: IP address and port to connect to
    ##Output: If the connection succeeded (as a boolean)
    function TestTCP {
      param ($TargetIPAddress, $TargetPort)

      $ProgressString = "Test-NetConnection - " + $TargetIPAddress + ":" + $TargetPort
      Write-Progress -Activity $ProgressString -Status "Attempting TCP connect" -CurrentOperation "Waiting for response" -SecondsRemaining -1 -PercentComplete -1

      $Success = $False
      $TCPClient = [System.Net.Sockets.TcpClient]::new($TargetIPAddress.AddressFamily)
      try {
        $null = $TCPClient.ConnectAsync($TargetIPAddress, $TargetPort).GetAwaiter().Getresult()
        $Success = $TCPClient.Connected;
      } catch {
        Write-Debug "TCP connect to ($TargetIPAddress : $TargetPort) threw exception: $($_.Exception.Message)"
      } finally {
        $TCPClient.Dispose()
      }

      return $Success
    }

    ##Description: Modifies the provided object with the correct local connectivty information
    ##Input: TestNetConnectionResults object that will be modified
    ##Output: Modified TestNetConnectionResult object
    function ResolveRoutingandAdapterWMIObjects {
      param ($TestNetConnectionResult)

      try {
        $TestNetConnectionResult.SourceAddress, $TestNetConnectionResult.NetRoute = Find-NetRoute -RemoteIPAddress $TestNetConnectionResult.RemoteAddress -ErrorAction SilentlyContinue
        $TestNetConnectionResult.NetAdapter = $TestNetConnectionResult.NetRoute | Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue

        $TestNetConnectionResult.InterfaceAlias = $TestNetConnectionResult.NetRoute.InterfaceAlias
        $TestNetConnectionResult.InterfaceIndex = $TestNetConnectionResult.NetRoute.InterfaceIndex
        $TestNetConnectionResult.InterfaceDescription = $TestNetConnectionResult.NetAdapter.InterfaceDescription
      } catch {
        Write-Debug "ResolveRoutingandAdapterWMIObjects threw exception: $($_.Exception.Message)"
      }
      return $TestNetConnectionResult
    }

    ##Description: Resolves the DNS details for the computername
    ##Input: The TestNetConnectionResults object that will be "filled in" with DNS information
    ##Output: The modified TestNetConnectionResults object
    function ResolveDNSDetails {
      param ($TestNetConnectionResult)

      $TestNetConnectionResult.DNSOnlyRecords = @( Resolve-DnsName $ComputerName -DnsOnly -NoHostsFile -Type A_AAAA -ErrorAction SilentlyContinue | Where-Object { ($_.QueryType -eq "A") -or ($_.QueryType -eq "AAAA") -or ($_.QueryType -eq "PTR") } )
      $TestNetConnectionResult.LLMNRNetbiosRecords = @( Resolve-DnsName $ComputerName -LlmnrNetbiosOnly -NoHostsFile -ErrorAction SilentlyContinue | Where-Object { ($_.QueryType -eq "A") -or ($_.QueryType -eq "AAAA") } )
      $TestNetConnectionResult.BasicNameResolution = @(Resolve-DnsName $ComputerName -ErrorAction SilentlyContinue | Where-Object { ($_.QueryType -eq "A") -or ($_.QueryType -eq "AAAA") -or ($_.QueryType -eq "PTR") } )

      $TestNetConnectionResult.AllNameResolutionResults = $Return.BasicNameResolution + $Return.DNSOnlyRecords + $Return.LLMNRNetbiosRecords | Sort-Object -Unique -Property Address
      return $TestNetConnectionResult
    }

    ##Description: Resolves the network security details for the computername
    ##Input: The TestNetConnectionResults object that will be "filled in" with network security information
    ##Output: Teh modified TestNetConnectionResults object
    function ResolveNetworkSecurityDetails {
      param ($TestNetConnectionResult)

      $TestNetConnectionResult.IsAdmin = CheckIfAdmin
      $NetworkIsolationInfo = Invoke-CimMethod -Namespace root\standardcimv2 -ClassName MSFT_NetAddressFilter -MethodName QueryIsolationType -Arguments @{InterfaceIndex = [uint32]$TestNetConnectionResult.InterfaceIndex; RemoteAddress = [string]$TestNetConnectionResult.RemoteAddress } -ErrorAction SilentlyContinue

      switch ($NetworkIsolationInfo.IsolationType) {
        1 { $TestNetConnectionResult.NetworkIsolationContext = "Private Network"; }
        0 { $TestNetConnectionResult.NetworkIsolationContext = "Loopback"; }
        2 { $TestNetConnectionResult.NetworkIsolationContext = "Internet"; }
      }

      ##Elevation is required to read IPsec information for the connection.
      if ($TestNetConnectionResult.IsAdmin) {
        $TestNetConnectionResult.MatchingIPsecRules = Find-NetIPsecRule -RemoteAddress $TestNetConnectionResult.RemoteAddress -RemotePort $TestNetConnectionResult.RemotePort -Protocol TCP -ErrorAction SilentlyContinue
      }

      return $TestNetConnectionResult
    }

    ##Description: Diagnose route selection for a destination
    ##Input: RouteDiagnosticsResults object that will be filled on with route diagnostics information.
    ##Output: None
    function DiagnoseRouteSelection {
      param ([NetRouteDiagnostics] $RouteDiagnostics)

      $RouteDiagnostics.RouteDiagnosticsSucceeded = $False

      if ($RouteDiagnostics.Detailed) {
        Write-Progress -Activity "Test-NetConnection :: $($RouteDiagnostics.RemoteAddress)" -Status "RouteDiagnostics" -CurrentOperation "Starting Route Event Tracing" -SecondsRemaining -1 -PercentComplete -1

        $LogFile = ""
        do {
          $LogFile = [System.IO.Path]::GetTempFileName().split(".")[0] + "Test-NetConnection.etl"
        }
        while (Test-Path -Path $LogFile -ErrorAction SilentlyContinue)

        $TraceResults = netsh trace start tracefile=$LogFile provider=Microsoft-Windows-TCPIP keywords=ut:TcpipRoute report=di perfmerge=no correlation=di session=tnc
      }

      Write-Progress -Activity "Test-NetConnection :: $($RouteDiagnostics.ComputerName)" -Status "RouteDiagnostics" -CurrentOperation "Resolving name" -SecondsRemaining -1 -PercentComplete -1

      $RouteDiagnostics.ResolvedAddresses = ResolveTargetName -TargetName $RouteDiagnostics.ComputerName
      if ($null -eq $RouteDiagnostics.ResolvedAddresses) {
        netsh trace stop sessionname=tnc | Out-Null
        return
      }

      $RouteDiagnostics.RemoteAddress = $RouteDiagnostics.ResolvedAddresses[0]

      if ($null -eq $RouteDiagnostics.ConstrainSourceAddress) {
        if ($RouteDiagnostics.RemoteAddress.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
          $RouteDiagnostics.ConstrainSourceAddress = [System.Net.IPAddress]::Any
        } else {
          $RouteDiagnostics.ConstrainSourceAddress = [System.Net.IPAddress]::IPv6Any
        }
      }

      if ($RouteDiagnostics.Detailed -and (Test-Path -Path $LogFile)) {
        ##Flush the destination cache to trigger a new route route lookup
        if ($RouteDiagnostics.RemoteAddress.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
          netsh int ipv4 delete destinationcache | Out-Null
        } else {
          netsh int ipv6 delete destinationcache | Out-Null
        }
      }

      Write-Progress -Activity "Test-NetConnection :: $($RouteDiagnostics.RemoteAddress)" -Status "RouteDiagnostics" -CurrentOperation "Finding route" -SecondsRemaining -1 -PercentComplete -1

      try {
        $RouteDiagnostics.SelectedSourceAddress, $RouteDiagnostics.SelectedNetRoute = `
          Find-NetRoute -RemoteIPAddress $RouteDiagnostics.RemoteAddress -LocalIPAddress $RouteDiagnostics.ConstrainSourceAddress -InterfaceIndex $RouteDiagnostics.ConstrainInterfaceIndex -ErrorAction SilentlyContinue

        $RouteDiagnostics.OutgoingNetAdapter = $RouteDiagnostics.SelectedNetRoute | Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue

        $RouteDiagnostics.OutgoingInterfaceAlias = $RouteDiagnostics.SelectedNetRoute.InterfaceAlias
        $RouteDiagnostics.OutgoingInterfaceIndex = $RouteDiagnostics.SelectedNetRoute.InterfaceIndex
        $RouteDiagnostics.OutgoingInterfaceDescription = $RouteDiagnostics.OutgoingNetAdapter.InterfaceDescription
      } catch {
        Write-Debug "Error occured while finding route information. Exception: $($_.Exception.Message)"
        netsh trace stop sessionname=tnc | Out-Null
        return
      }

      if ($RouteDiagnostics.Detailed) {
        Write-Progress -Activity "Test-NetConnection :: $($RouteDiagnostics.RemoteAddress)" -Status "RouteDiagnostics" -CurrentOperation "Parsing Route Events" -SecondsRemaining -1 -PercentComplete -1

        $TraceResults += netsh trace stop sessionname=tnc

        if (!(Test-Path -Path $LogFile)) {
          $Message = "Error occured while collection routing events. Error: " + $TraceResults
          Write-Warning $Message
          return
        }

        ##Search for all relevant routing events: IpSourceAddressSelection (ID 1326), IpSortedAddressPairs (ID 1327), RouteLookup (ID 1370), IpRouteSelection (ID 1383), and IpRouteBlocked (ID 1384)
        $AllRoutingEvents = Get-WinEvent -Oldest -FilterHashtable @{ Path = $LogFile; ProviderName = 'Microsoft-Windows-TCPIP'; ID = @(1326, 1327, 1370, 1383, 1384) } | Where-Object { $null -ne $_.Message
        }
        if ($AllRoutingEvents.Count -eq 0) {
          ##There may be no route or address selection events if there was only one matching route, but  there should've been at least one route lookup event.
          Write-Warning "No TCPIP routing events collected from $LogFile. The trace might have failed."
        } else {
          ##Get route selection events: [IpRouteSelection (ID 1383) and IpRouteBlocked (ID 1384)] containing the remote IP
          $RouteEvents = $AllRoutingEvents | Where-Object { (($_.Id -eq 1383) -or ($_.Id -eq 1384)) -and $_.Message.Contains("$($RouteDiagnostics.RemoteAddress) ") }
          foreach ($event in $RouteEvents) {
            if ($RouteDiagnostics.RouteSelectionEvents -notcontains $($event.Message)) {
              $RouteDiagnostics.RouteSelectionEvents += "$($event.Message)"
            }
          }

          ##Get source address selection events: [IpSourceAddressSelection (ID 1326)] containing the remote IP
          $SrcAddrEvents = $AllRoutingEvents | Where-Object { ($_.Id -eq 1326) -and $_.Message.Contains("$($RouteDiagnostics.RemoteAddress) ") }
          foreach ($event in $SrcAddrEvents) {
            if ($RouteDiagnostics.SourceAddressSelectionEvents -notcontains $($event.Message)) {
              $RouteDiagnostics.SourceAddressSelectionEvents += "$($event.Message)"
            }
          }

          ##Get destination address selection events: [IpSortedAddressPairs (ID 1327)] containing the resolved IPs
          $ResolvedAddrs = $RouteDiagnostics.ResolvedAddresses | ForEach-Object { $_.IPAddressToString }
          $DstAddrEvents = $AllRoutingEvents | Where-Object { ($_.Id -eq 1327) -and ($null -ne ($CurrMessage = $_.Message)) -and (($ResolvedAddrs | ForEach-Object { $CurrMessage.Contains("$_)") }) -contains $true) }
          foreach ($event in $DstAddrEvents) {
            if ($RouteDiagnostics.DestinationAddressSelectionEvents -notcontains $($event.Message)) {
              $RouteDiagnostics.DestinationAddressSelectionEvents += "$($event.Message)"
            }
          }
        }

        $RouteDiagnostics.LogFile = $LogFile
      }

      $RouteDiagnostics.RouteDiagnosticsSucceeded = $True

      return
    }
    #endregion
  }
  Process {
    switch ($PSCmdlet.ParameterSetName) {

      ##Route diagnostics parameterset
      "NetRouteDiagnostics" {
        $Return = [NetRouteDiagnostics]::new()
        $Return.ComputerName = $ComputerName

        if ($ConstrainSourceAddress -ne "") {
          $Return.ConstrainSourceAddress = $ConstrainSourceAddress
        }

        $Return.ConstrainInterfaceIndex = $ConstrainInterface

        $Return.Detailed = ($InformationLevel -eq "Detailed")
        if ($Return.Detailed -and (!(CheckIfAdmin))) {
          Write-Warning "'-InformationLevel Detailed' requires elevation (Run as administrator)."
          $Return.Detailed = $False
        }

        DiagnoseRouteSelection -RouteDiagnostics $Return

        return $Return
      }

      ##Test connection parametersets
      default {
        ##Construct the return object and fill basic details
        $Return = [TestNetConnectionResult]::new()
        $Return.ComputerName = $ComputerName
        $Return.Detailed = ($InformationLevel -eq "Detailed")

        #### Begin Name Resolution ####

        $Return.ResolvedAddresses = ResolveTargetName -TargetName $ComputerName
        if ($null -eq $Return.ResolvedAddresses) {
          if ($InformationLevel -eq "Quiet") {
            return $False
          }

          $Return.NameResolutionSucceeded = $False
          return $Return
        }

        $Return.RemoteAddress = $Return.ResolvedAddresses[0]
        $Return.NameResolutionSucceeded = $True
        #### End of Name Resolution ####

        #### Begin TCP test ####

        ##Attempt TCP test only if Port or CommonTCPPort is specified
        $AttemptTcpTest = ($PSCmdlet.ParameterSetName -eq "CommonTCPPort") -or ($PSCmdlet.ParameterSetName -eq "RemotePort")
        if ($AttemptTcpTest) {
          $Return.TcpTestSucceeded = $False

          switch ($CommonTCPPort) {
            "" { $Return.RemotePort = $Port }
            "HTTP" { $Return.RemotePort = 80 }
            "RDP" { $Return.RemotePort = 3389 }
            "SMB" { $Return.RemotePort = 445 }
            "WINRM" { $Return.RemotePort = 5985 }
          }

          ##Try TCP connect using all resolved addresses until it succeeds
          $Iter = 0
          while (($Iter -lt $Return.ResolvedAddresses.Count) -and (!$Return.TcpTestSucceeded)) {
            $Return.TcpTestSucceeded = TestTCP -TargetIPAddress $Return.ResolvedAddresses[$Iter] -TargetPort $Return.RemotePort
            ##Output a warning message if the TCP test didn't succeed
            if (!$Return.TcpTestSucceeded) {
              Write-Warning "TCP connect to ($($Return.ResolvedAddresses[$Iter]) : $($Return.RemotePort)) failed"
            }
            $Iter++
          }

          if ($Return.TcpTestSucceeded) {
            ##Get the remote address that was actually used for connection
            $Return.RemoteAddress = $Return.ResolvedAddresses[$Iter - 1]
          }

          ##If the user specified "quiet" then we should only return a boolean
          if ($InformationLevel -eq "Quiet") {
            return $Return.TcpTestSucceeded
          }
        }
        #### End of TCP test ####

        #### Begin Ping test ####

        ##Attempt Ping test only if TCP test is not attempted or TCP test failed
        $AttemptPingTest = (!$AttemptTcpTest) -or (!$Return.TcpTestSucceeded)
        if ($AttemptPingTest) {
          $Return.PingSucceeded = $False

          ##Try Ping using all resolved addresses until it succeeds
          $Iter = 0
          while (($Iter -lt $Return.ResolvedAddresses.Count) -and (!$Return.PingSucceeded)) {
            $Return.PingReplyDetails = PingTest -TargetIPAddress $Return.ResolvedAddresses[$Iter]
            if ($null -ne $Return.PingReplyDetails) {
              $Return.PingSucceeded = ($Return.PingReplyDetails.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
            }

            ##Output a warning message if Ping didn't succeed
            if (!$Return.PingSucceeded) {
              $WarningString = "Ping to $($Return.ResolvedAddresses[$Iter]) failed"
              if ($null -ne $Return.PingReplyDetails) {
                $WarningString += " with status: $($Return.PingReplyDetails.Status)"
              }
              Write-Warning $WarningString
            }
            $Iter++
          }

          if ($Return.PingSucceeded) {
            ##Get the remote address that was actually used for Ping
            $Return.RemoteAddress = $Return.ResolvedAddresses[$Iter - 1]
          }

          ##If the user specified "quiet" then we should only return a boolean
          if ($InformationLevel -eq "Quiet") {
            return $Return.PingSucceeded
          }
        }
        #### End of Ping test ####

        #### Begin TraceRoute ####

        ##TraceRoute, only occurs if switched by the user
        if ($TraceRoute -eq $True) {
          $Return.TraceRoute = TraceRoute -TargetIPAddress $Return.RemoteAddress -Hops $Hops
        }
        #### End of TraceRoute ####

        $Return = ResolveDNSDetails -TestNetConnectionResult $Return
        $Return = ResolveNetworkSecurityDetails -TestNetConnectionResult $Return
        $Return = ResolveRoutingandAdapterWMIObjects -TestNetConnectionResult $Return

        return $Return
      }
    }
  }
  end {
    # $ErrorActionPreference = $ogeap
  }
}