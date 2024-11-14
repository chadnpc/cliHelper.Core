<#
.SYNOPSIS
	Checks the ISS position
.DESCRIPTION
	This PowerShell script queries the position of the International Space Station (ISS) and replies by text-to-speech (TTS).
.EXAMPLE
	PS> ./check-iss-position
.LINK
	https://github.com/fleschutz/PowerShell
.NOTES
	Author: Markus Fleschutz / License: CC0
#>

try {
  $ISS = (Invoke-WebRequest "http://api.open-notify.org/iss-now.json" -UserAgent "curl" -UseBasicParsing).Content | ConvertFrom-Json

  & "$PSScriptRoot/give-reply.ps1" "The International Space Station is currently at $($ISS.iss_position.longitude)° longitude and $($ISS.iss_position.latitude)° latitude."
  # success
} catch {
  # Write-Log $_.Exception.ErrorRecord
  Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
  break
}
