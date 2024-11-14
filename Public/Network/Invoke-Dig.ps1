function Invoke-Dig {
  # .SYNOPSIS
  #   Perform DNS resolution on a host.
  # .PARAMETER Name
  #   The DNS name to resolve.
  # .PARAMETER Type
  #   THe DNS record type to resolve.
  # .PARAMETER Server
  #   The DNS server to use.
  # .EXAMPLE
  #   Invoke-Dig -name www.google.com -type A -server 8.8.8.8
  # .LINK
  #   Resolve-DnsName
  [cmdletbinding()]
  param(
    [parameter(Mandatory)]
    [string]$Name,

    [ValidateSet('A', 'A_AAAA', 'AAAA', 'NS', 'MX', 'MD', 'MF', 'CNAME', 'SOA', 'MB', 'MG', 'MR', 'NULL', 'WKS', 'PTR',
      'HINFO', 'MINFO', 'TXT', 'RP', 'AFSDB', 'X25', 'ISDN', 'RT', 'SRV', 'DNAME', 'OPT', 'DS', 'RRSIG',
      'NSEC', 'DNSKEY', 'DHCID', 'NSEC3', 'NSEC3PARAM', 'ANY', 'ALL')]
    [string]$Type = 'A_AAAA',

    [string]$Server
  )

  if ($PSBoundParameters.ContainsKey('Server')) {
    $r = Resolve-DnsName -Name $Name -Type $Type -Server $Server | Format-Table -AutoSize | Out-String
  } else {
    $r = Resolve-DnsName -Name $Name -Type $Type -ErrorAction SilentlyContinue | Format-Table -AutoSize | Out-String
  }

  if ($r) {
    return $r
  } else {
    Write-Error "Unable to resolve [$Name] :("
  }
}