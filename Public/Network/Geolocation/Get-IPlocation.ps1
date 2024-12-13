function Get-IPlocation {
  # .SYNOPSIS
  # 	Prints the geo location of the given IP address, to the console.
  # .DESCRIPTION
  # 	This PowerShell script prints the geographic location of the given IP address.
  # .EXAMPLE
  # 	PS C:\> Get-IPlocation 177.144.67.98
  # 	Explanation of what the example does
  # .PARAMETER IPaddress
  # 	Specifies the IP address
  [CmdletBinding()]
  param (
    [string]$IPaddress = ""
  )
  process {
    try {
      if ($IPaddress -eq "" ) { $IPaddress = Read-Host "Enter IP address to locate" }
      $result = Invoke-RestMethod -Method Get -Uri "http://ip-api.com/json/$IPaddress"
      Write-Output $result
      # success
    } catch {
      # Write-Log $_.Exception.ErrorRecord
      Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
      break
    }
  }
}