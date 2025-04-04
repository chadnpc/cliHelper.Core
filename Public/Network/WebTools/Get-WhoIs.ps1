﻿Function Get-WhoIs {
  [cmdletbinding()]
  [OutputType("WhoIsResult")]
  Param (
    [parameter(Position = 0,
      Mandatory,
      HelpMessage = "Enter an IPV4 address to lookup with WhoIs",
      ValueFromPipeline,
      ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$")]
    [ValidateScript( {
        #verify each octet is valid to simplify the regex
        $test = ($_.split(".")).where({ [int]$_ -gt 255 })
        if ($test) {
          Throw "$_ does not appear to be a valid IPv4 address."
          $false
        } else {
          $true
        }
      })]
    [string]$IPAddress
  )

  Begin {
    Write-Verbose "Starting $($MyInvocation.Mycommand)"
    $baseURL = 'http://whois.arin.net/rest'
    #default is XML anyway
    $header = @{"Accept" = "application/xml" }
  }

  Process {
    Write-Verbose "Getting WhoIs information for $IPAddress"
    $url = "$baseUrl/ip/$ipaddress"
    Try {
      $r = Invoke-RestMethod $url -Headers $header -ErrorAction stop
      Write-Verbose ($r.net | Out-String)
    } Catch {
      $errMsg = "Sorry. There was an error retrieving WhoIs information for $IPAddress. $($_.exception.message)"
      $host.ui.WriteErrorLine($errMsg)
    }

    if ($r.net) {
      Write-Verbose "Creating result"
      [pscustomobject]@{
        PSTypeName             = "WhoIsResult"
        IP                     = $ipaddress
        Name                   = $r.net.name
        RegisteredOrganization = $r.net.orgRef.name
        City                   = (Invoke-RestMethod $r.net.orgRef.'#text').org.city
        StartAddress           = $r.net.startAddress
        EndAddress             = $r.net.endAddress
        NetBlocks              = $r.net.netBlocks.netBlock | ForEach-Object { "$($_.startaddress)/$($_.cidrLength)" }
        Updated                = $r.net.updateDate -as [datetime]
      }
    } #If $r.net
  } #Process

  End {
    Write-Verbose "Ending $($MyInvocation.Mycommand)"
  } #end
}
