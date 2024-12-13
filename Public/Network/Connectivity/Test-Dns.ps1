function Test-Dns {
  # .SYNOPSIS
  # 	Checks the DNS resolution
  # .DESCRIPTION
  # 	This PowerShell script checks the DNS resolution with frequently used domain names.
  # .EXAMPLE
  # 	PS> ./check-dns
  # 	✅ DNS resolution is 11.8 domains per second
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [String[]]$InterfaceAlias,
    [Parameter(Mandatory = $false)]
    [int]$ThrottleLimit
  )

  process {
    try {
      $StopWatch = [system.diagnostics.stopwatch]::startNew()
      Write-Progress "Reading Data/domain-names.csv..."

      $PathToRepo = "$PSScriptRoot/.."
      $Table = Import-Csv "$PathToRepo/Data/domain-names.csv"

      foreach ($Row in $Table) {
        Write-Progress "Resolving $($Row.Domain) ..."
        if ($IsLinux) {
          $null = nslookup $Row.Domain
        } else {
          $null = Resolve-DnsName $Row.Domain
        }
      }
      $Count = $Table.Length

      [int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
      $Average = [math]::round($Count / $Elapsed, 1)

      # & "$PSScriptRoot/give-reply.ps1" "$Average domains per second DNS resolution"
      # success
    } catch {
      # Write-Log $_.Exception.ErrorRecord
      Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
      break
    }
  }
}