function Get-NetworkInfo {
  <#
    .DESCRIPTION
    Collects basic Networking Information across Windows, macOS, and Linux
    Provides a cross-platform approach to gathering network details
    #>
  [CmdletBinding()]
  [OutputType([ordered])]
  param ()

  begin {
    # Determine the current operating system
    $OSPlatform = $PSVersionTable.Platform
    if ($null -eq $OSPlatform) {
      $OSPlatform = if ($IsWindows) { 'Win32NT' }
      elseif ($IsMacOS) { 'Darwin' }
      elseif ($IsLinux) { 'Linux' }
      else { throw "Unsupported operating system" }
    }

    # Cross-platform command runner
    function Invoke-xcCommand {
      param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Commands,

        [Parameter(Mandatory = $true)]
        [string]$OutputFile,

        [string]$FileDescription = ""
      )

      # Select the appropriate command based on OS
      $CommandToRun = $Commands[$OSPlatform]

      if (-not $CommandToRun) {
        Write-Warning "No command defined for current platform: $OSPlatform"
        return
      }

      # Ensure output directory exists
      $OutputDir = Split-Path $OutputFile -Parent
      if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
      }

      # Add header to output file
      "`n--- $FileDescription ---`n" | Out-File $OutputFile -Append

      try {
        # Execute the command
        if ($OSPlatform -eq 'Win32NT') {
          # For Windows, use cmd.exe
          cmd.exe /c $CommandToRun 2>&1 | Out-File $OutputFile -Append
        } else {
          # For Unix-like systems, use bash
          bash -c "$CommandToRun" 2>&1 | Out-File $OutputFile -Append
        }
      } catch {
        "Error executing command: $CommandToRun`n$_" | Out-File $OutputFile -Append
      }
    }

    # Create output directory if it doesn't exist
    $OutputDir = Join-Path (Get-Location) "NetworkInfo"
    if (-not (Test-Path $OutputDir)) {
      New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    # Hostname for output files
    $Hostname = hostname
  }

  process {
    # Output files
    $NetworkSummaryFile = Join-Path $OutputDir "$Hostname-NetworkSummary.txt"
    $IPDetailsFile = Join-Path $OutputDir "$Hostname-IPDetails.txt"
    $NetworkConfigFile = Join-Path $OutputDir "$Hostname-NetworkConfig.txt"
    $NetworkConnectionsFile = Join-Path $OutputDir "$Hostname-NetworkConnections.txt"

    # IP and Network Interface Details
    Invoke-xcCommand -Commands @{
      'Win32NT' = 'ipconfig /all'
      'Darwin'  = 'ifconfig'
      'Linux'   = 'ip addr'
    } -OutputFile $IPDetailsFile -FileDescription "Network Interfaces"

    # Network Configuration
    Invoke-xcCommand -Commands @{
      'Win32NT' = 'netsh int ip show config'
      'Darwin'  = 'networksetup -listallnetworkservices'
      'Linux'   = 'nmcli device status'
    } -OutputFile $NetworkConfigFile -FileDescription "Network Configuration"

    # Network Connections
    Invoke-xcCommand -Commands @{
      'Win32NT' = 'netstat -ano'
      'Darwin'  = 'netstat -anp tcp'
      'Linux'   = 'ss -tunapo'
    } -OutputFile $NetworkConnectionsFile -FileDescription "Network Connections"

    # DNS Information
    Invoke-xcCommand -Commands @{
      'Win32NT' = 'ipconfig /displaydns'
      'Darwin'  = 'scutil --dns'
      'Linux'   = 'cat /etc/resolv.conf'
    } -OutputFile $NetworkSummaryFile -FileDescription "DNS Configuration"

    # Routing Table
    Invoke-xcCommand -Commands @{
      'Win32NT' = 'route print'
      'Darwin'  = 'netstat -nr'
      'Linux'   = 'ip route'
    } -OutputFile $NetworkSummaryFile -FileDescription "Routing Table"

    # ARP Cache
    Invoke-xcCommand -Commands @{
      'Win32NT' = 'arp -a'
      'Darwin'  = 'arp -a'
      'Linux'   = 'ip neigh'
    } -OutputFile $NetworkSummaryFile -FileDescription "ARP Cache"

    # Generate Summary
    "Network Information Summary for $Hostname" | Out-File $NetworkSummaryFile
    "Generated on $(Get-Date)" | Out-File $NetworkSummaryFile -Append
    "" | Out-File $NetworkSummaryFile -Append
    "Detailed information can be found in the following files:`n" | Out-File $NetworkSummaryFile -Append
    "- $IPDetailsFile`n" | Out-File $NetworkSummaryFile -Append
    "- $NetworkConfigFile`n" | Out-File $NetworkSummaryFile -Append
    "- $NetworkConnectionsFile`n" | Out-File $NetworkSummaryFile -Append

    # Return the paths of generated files
    return [ordered]@{
      Summary            = $NetworkSummaryFile
      IPDetails          = $IPDetailsFile
      NetworkConfig      = $NetworkConfigFile
      NetworkConnections = $NetworkConnectionsFile
    }
  }
}