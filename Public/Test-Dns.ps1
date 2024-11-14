function Test-Dns {
    <#
	.SYNOPSIS
		Checks the DNS resolution
	.DESCRIPTION
		This PowerShell script checks the DNS resolution with frequently used domain names.
	.EXAMPLE
		PS> ./check-dns
		✅ DNS resolution is 11.8 domains per second
	.LINK
		https://github.com/alainQtec/.files/blob/main/Functions/Diagnostic/Test-Dns.ps1

	#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String[]]$InterfaceAlias,
        [Parameter(Mandatory = $false)]
        [int]$ThrottleLimit
    )

    begin {

    }

    process {
        try {
            $StopWatch = [system.diagnostics.stopwatch]::startNew()
            Write-Progress "Reading Data/domain-names.csv..."

            $PathToRepo = "$PSScriptRoot/.."
            $Table = Import-Csv "$PathToRepo/Data/domain-names.csv"

            foreach ($Row in $Table) {
                Write-Progress "Resolving $($Row.Domain) ..."
                if ($IsLinux) {
                    $Ignore = nslookup $Row.Domain
                } else {
                    $Ignore = Resolve-DnsName $Row.Domain
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

    end {
    }
}