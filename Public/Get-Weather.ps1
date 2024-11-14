# function Get-Weather {
#   [CmdletBinding()]
#   param ()

#   begin {
#   }

#   process {
#     [WeatherClient]::DisplayWeather()
#   }
# }
#

class GeoCoordinate {
  [decimal]$Latitude = 0
  [decimal]$Longitude = 0

  GeoCoordinate() {}
  GeoCoordinate([decimal]$lat, [decimal]$lon) {
    [void][GeoCoordinate]::_init_($lat, $lon, $this)
  }
  GeoCoordinate([tuple[decimal, decimal]]$coord) {
    [void][GeoCoordinate]::_init_($coord.Item1, $coord.Item2, $this)
  }
  static [GeoCoordinate] Create([decimal]$lat, [decimal]$lon) {
    return [GeoCoordinate]::_init_($lat, $lon, [GeoCoordinate]::new())
  }
  static [GeoCoordinate] Create([tuple[decimal, decimal]]$coord) {
    return [GeoCoordinate]::Create($coord.Item1, $coord.Item2)
  }
  static hidden [GeoCoordinate] _init_([decimal]$lat, [decimal]$lon, [ref]$o) {
    if (-90 -le $lat -and $lat -le 90) {
      $o.Value.Latitude = $lat
    } else {
      throw [ArgumentException]::new("Latitude must be between -90 and 90 degrees")
    }
    if (-180 -le $lon -and $lon -le 180) {
      $o.Value.Longitude = $lon
    } else {
      throw [ArgumentException]::new("Longitude must be between -180 and 180 degrees")
    }
    return $o.Value
  }
  [double] DistanceTo([GeoCoordinate]$dest) {
    return [GeoCoordinate]::DistanceTo($this, $dest)
  }
  static [double] DistanceTo([GeoCoordinate]$start, [GeoCoordinate]$dest) {
    # Method to calculate distance between two points using the Haversine formula
    $R = 6371 # Earth's radius in kilometers

    $lat1 = $start.Latitude * [Math]::PI / 180
    $lat2 = $dest.Latitude * [Math]::PI / 180
    $lon1 = $start.Longitude * [Math]::PI / 180
    $lon2 = $dest.Longitude * [Math]::PI / 180

    $dlat = $lat2 - $lat1
    $dlon = $lon2 - $lon1

    $a = [Math]::Sin($dlat / 2) * [Math]::Sin($dlat / 2) +
    [Math]::Cos($lat1) * [Math]::Cos($lat2) *
    [Math]::Sin($dlon / 2) * [Math]::Sin($dlon / 2)

    $c = 2 * [Math]::Atan2([Math]::Sqrt($a), [Math]::Sqrt(1 - $a))
    return $R * $c
  }
  [string] ToString() {
    $latDir = if ($this.Latitude -ge 0) { "N" } else { "S" }
    $lonDir = if ($this.Longitude -ge 0) { "E" } else { "W" }
    return "{0:F6}°{1} {2:F6}°{3}" -f [Math]::Abs($this.Latitude), $latDir, [Math]::Abs($this.Longitude), $lonDir
  }
  static [GeoCoordinate] Parse([string]$coordString) {
    # Method to parse coordinates from a string
    # .EXAMPLE
    # $paris = [GeoCoordinate]::Parse("48.8566°N 2.3522°E")
    # Write-Host "Paris coordinates: $paris"
    $pattern = "^([\d.]+)°([NS])\s+([\d.]+)°([EW])$"
    if ($coordString -match $pattern) {
      $lat = [decimal]$matches[1]
      $lon = [decimal]$matches[3]

      if ($matches[2] -eq "S") { $lat = - $lat }
      if ($matches[4] -eq "W") { $lon = - $lon }

      return [GeoCoordinate]::new($lat, $lon)
    }
    throw "Invalid coordinate format. Use format like '40.7128°N 74.0060°W'"
  }
}

# .SYNOPSIS
# Displays the current weather
# .EXAMPLE
# Using httpClient
# HttpUriRequest=new HttpGet(http://api.accuweather.com/locations/v1/search?q=san&apikey={your key});
# request.addHeader("Accept-Encoding", "gzip");
# // ... httpClient.execute(request);
class WeatherClient {
  static [string] $PADDING = ' ' * 2
  static [string] $HIGH_WIND_SPEEDS = 15
  static [hashtable] $weathericons = @{
    1 = "☀️"; 2 = "☀️"
    3 = "🌤"; 4 = "🌤"
    5 = "🌤"; 6 = "🌥"
    7 = "☁️"; 8 = "☁️"
    11 = "🌫"; 12 = "🌧"
    13 = "🌦"; 14 = "🌦"
    15 = "⛈"; 16 = "⛈"
    17 = "🌦"; 18 = "🌧"
    19 = "🌨"; 20 = "🌨"
    21 = "🌨"; 22 = "❄️"
    23 = "❄️"; 24 = "🌧"
    25 = "🌧"; 26 = "🌧"
    29 = "🌧"; 30 = "🌫"
    31 = "🥵"; 32 = "🥶"
  }
  static [hashtable] $weatherascii = @{
    sunny          = (
      "  \\ | /   ",
      "  - O -   ",
      "  / | \\   "
    )

    partial_clouds = (
      "  \\ /(  ) ",
      " - O(    )",
      "  / (  )  "
    )

    clouds         = (
      "  ( )()_  ",
      " (      ) ",
      "  (  )()  "
    )

    night          = (
      "   .   *  ",
      " *    . O ",
      " . . *  . "
    )

    drizzle        = (
      " '  '    '",
      "  '   ' ' ",
      "'    '   '"
    )

    rain           = (
      " ' '' ' ' ",
      " '' ' ' ' ",
      " ' ' '' ' "
    )

    thunderstorm   = (
      " ''_/ _/' ",
      " ' / _/' '",
      " /_/'' '' "
    )

    chaos          = (
      " c__ ''' '",
      " ' '' c___",
      " c__ ' 'c_"
    )

    snow           = (
      " * '* ' * ",
      " '* ' * ' ",
      " *' * ' * "
    )

    fog            = (
      " -- _ --  ",
      " -__-- -  ",
      " - _--__  "
    )

    wind           = (
      " c__ -- _ ",
      " -- _-c__ ",
      " c --___c "
    )
    unknown        = (
      "  ???  ",
      " ??⛈?? ",
      "  ???  "
    )
  }
  static [GeoCoordinate] GetCurrentLocation() {
    # Gets user's current location from ipinfio.io
    $locApi = "https://ipinfo.io/loc"; $location = Invoke-RestMethod -Uri $locApi -SkipHttpErrorCheck -Verbose:$false
    $lat, $lon = $location.Split(',') | ForEach-Object { [decimal]$_ }
    return [GeoCoordinate]::new($lat, $lon)
  }
  static [PSCustomObject] CallWeatherApi() {
    # Returns json from calling openweathermap.org using user's latitude and longitude
    $location = [WeatherClient]::GetCurrentLocation()
    if ($null -eq $env:OPENWEATHER_API_KEY) {
      $r = Read-Env .env -ErrorAction SilentlyContinue; if ($null -eq $r) { throw [System.IO.FileNotFoundException]::new("No .env file was found") }
      if (!$r.Name.Contains("OPENWEATHER_API_KEY")) {
        throw "No OPENWEATHER_API_KEY found in .env file"
      }; $r | Set-Env
    }
    Write-Host "Calling API for location $($location.ToString())"
    return Invoke-RestMethod -Uri "https://api.openweathermap.org/data/2.5/weather?lat=$($location.Latitude)&units=imperial&lon=$($location.Longitude)&appid=$($env:OPENWEATHER_API_KEY)" -SkipHttpErrorCheck -Verbose:$false
  }
  static [PSCustomObject] ParseWeatherData() {
    # Parses weather data from the API call
    $data = [WeatherClient]::CallWeatherApi()
    return [PSCustomObject]@{
      Name        = $data.name
      Condition   = $data.weather[0].main
      WindSpeed   = $data.wind.speed
      FeelsLike   = $data.main.feels_like
      Temperature = $data.main.temp
      ConditionId = $data.weather[0].id
    }
  }
  static [bool] IsNighttime() {
    return [weatherClient]::IsNighttime([datetime]::Now)
  }
  static [bool] IsNighttime([datetime]$date) {
    $hour = ($date).Hour; # naive approach - day-time defined as 6:00 AM -> 8:00 PM
    return !(6 -le $hour -and $hour -le 20)
  }
  static [tuple[array, string]] SelectAsciiArt([int]$conditionId, [double]$windSpeed) {
    # Split condition ID into category and subcategory
    $category = [math]::Floor($conditionId / 100)
    $subcategory = $conditionId % 100

    # Check conditions
    $windy = $windSpeed -ge [WeatherClient]::HIGH_WIND_SPEED
    $nighttime = [WeatherClient]::IsNighttime()

    # Determine appropriate ASCII art and color based on conditions
    $asciiArt, $color = switch ($true) {
      # Thunderstorm or Rain with high winds
      $(($category -in @(2, 5)) -and $windy) {
        [WeatherClient]::weatherascii['chaos'], 'DarkGray'
        break
      }
      # Clear night
      $(($category -eq 8) -and ($subcategory -eq 0) -and $nighttime) {
        [WeatherClient]::weatherascii['night'], 'Magenta'
        break
      }
      # Snow at night
      $(($category -eq 6) -and $nighttime) {
        [WeatherClient]::weatherascii['snow'], 'Blue'
        break
      }
      # Generally windy conditions
      $windy {
        [WeatherClient]::weatherascii['wind'], 'Blue'
        break
      }
      # Clear day
      $(($category -eq 8) -and ($subcategory -eq 0)) {
        [WeatherClient]::weatherascii['sunny'], 'Yellow'
        break
      }
      # Thunderstorm
      $($category -eq 2) {
        [WeatherClient]::weatherascii['thunderstorm'], 'Yellow'
        break
      }
      # Drizzle
      $($category -eq 3) {
        [WeatherClient]::weatherascii['rain'], 'Cyan'
        break
      }
      # Rain
      $($category -eq 5) {
        $asciiArt = [WeatherClient]::weatherascii['rain']
        $color = 'Blue'
        break
      }
      # Snow
      $($category -eq 6) {
        $asciiArt = [WeatherClient]::weatherascii['snow']
        $color = 'White'
        break
      }
      # Partially cloudy
      $(($category -eq 8) -and ($subcategory -in @(2, 3))) {
        $asciiArt = [WeatherClient]::weatherascii['partial_clouds']
        $color = 'Blue'
        break
      }
      # Cloudy
      $(($category -eq 8) -and ($subcategory -eq 4)) {
        $asciiArt = [WeatherClient]::weatherascii['clouds']
        $color = 'Blue'
        break
      }
      # Fog/Atmosphere
      $($category -eq 7) {
        $asciiArt = [WeatherClient]::weatherascii['fog']
        $color = 'DarkGray'
        break
      }
      default {
        [WeatherClient]::weatherascii['unknown'], 'White'
      }
    }

    return [tuple]::Create($asciiArt, $color)
  }
  static [PSCustomObject] FormatWeatherDisplay() {
    # Get weather data
    $weatherData = [WeatherClient]::ParseWeatherData()

    # Get ASCII art based on conditions
    $asciiResult = [WeatherClient]::SelectAsciiArt($weatherData.ConditionId, $weatherData.WindSpeed)
    $asciiArt = $asciiResult.Item1
    $color = $asciiResult.Item2

    # Format temperature, feels like, and wind speed
    $temperature = "{0}°F" -f [math]::Round($weatherData.Temperature)
    $feelsLike = "{0}°F" -f [math]::Round($weatherData.FeelsLike)
    $windSpeed = "{0} mph" -f [math]::Round($weatherData.WindSpeed)
    # $icon = [WeatherClient]::emojis[[int]$target.Day.Icon]

    # Get current time
    $time = (Get-Date).ToString("hh:mm tt")

    # Create weather text lines with proper padding
    $weatherText = @(
      "{0,-13} feels like {1}" -f $temperature, $feelsLike
      "{0,-13} wind {1}" -f $weatherData.Condition, $windSpeed
      "{0,-13} thanks to OpenWeatherMap.org" -f $time
    )

    # Return formatted data
    return [PSCustomObject]@{
      WeatherText = $weatherText
      AsciiArt    = $asciiArt
      Color       = $color
      Location    = $weatherData.Name
    }
  }

  # Helper method to display the weather
  static [void] DisplayWeather() {
    $weatherDisplay = [WeatherClient]::FormatWeatherDisplay()

    Write-Host "`nWeather for $($weatherDisplay.Location)" -ForegroundColor $weatherDisplay.Color
    Write-Host "------------------------" -ForegroundColor $weatherDisplay.Color

    # Display ASCII art
    $weatherDisplay.AsciiArt | ForEach-Object {
      Write-Host $_ -ForegroundColor $weatherDisplay.Color
    }

    Write-Host ""  # Empty line for spacing

    # Display weather information
    $weatherDisplay.WeatherText | ForEach-Object {
      Write-Host $_ -ForegroundColor $weatherDisplay.Color
    }
    Write-Host ""  # Empty line for spacing
  }
}