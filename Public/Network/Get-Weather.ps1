function Get-Weather {
  [CmdletBinding()]
  param ()

  begin {
  }

  process {
    [WeatherClient]::DisplayWeather()
  }
}

