function Get-GeoLocIp {
  <#
    .SYNOPSIS
        Get Geo location for an IP or a CIDR network from the RIPE database
    .PARAMETER IPAddress
        IP address to retrieve geo location information for.
    .EXAMPLE
        !geolocip 83.23.45.3
        !geolocip 83.23.45.0/21
    #>
  [cmdletbinding()]
  param(
    [parameter(Mandatory)]
    [Alias('IP')]
    [string]$IPAddress
  )

  try {
    $httpResponse = Invoke-WebRequest -UseBasicParsing -Uri "https://stat.ripe.net/data/geoloc/data.json?resource=$($IPAddress)"
    if ($httpResponse) {
      $jsonResponse = $httpResponse | ConvertFrom-Json
      if ($jsonResponse.data.locations.count -gt 0) {
        $response = ''
        foreach ($location in $jsonResponse.data.locations) {
          $response += "$($location.City) $($location.country) `n"
        }
      } else {
        $errorMessage = 'Not Found'
      }
    }
  } catch [System.Net.WebException] {
    switch ($_.Exception.Response.StatusCode) {
      'BadRequest' {
        $errorMessage = 'Server Error'
      }
      'InternalServerError' {
        $errorMessage = 'Server Error 500'
      }
      default {
        $errorMessage = "Server Error: $($_.Exception)"
      }
    }
  } catch {
    Write-Debug $_.Exception
    $errorMessage = "Receive a general error: $($_.Exception)"
  } finally {
    if ($errorMessage) {
      Write-Error "$errorMessage`n:("
    }
    if ($response) {
      $response
    }
  }
}