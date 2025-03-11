# Define the ANSI escape character
$e = [char]0x1B

# Function to generate normal color blocks
function Get-Pcs {
    param ([string]$style = "")
    $output = ""
    foreach ($i in 0..7) {
        $color = 30 + $i
        $output += "$e[${style}${color}m$([char]0x2588)$([char]0x2588)$e[0m"
    }
    return $output
}

# Function to generate bright color blocks
function Get-PcsBright {
    param ([string]$style = "")
    $output = ""
    foreach ($i in 0..7) {
        $color = 90 + $i
        $output += "$e[${style}${color}m$([char]0x2588)$([char]0x2588)$e[0m"
    }
    return $output
}

# Generate and display the ASCII art
$normal = Get-Pcs
$bright = Get-PcsBright -style '1;'
Write-Host "`n$normal`n$bright`n"
