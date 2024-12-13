function Write-MOTD {
  <#
	.SYNOPSIS
		Writes the message of the day
	.DESCRIPTION
		Writes the message of the day (MOTD)
	.NOTES
		Author: Markus Fleschutz /License: CC0
        https://github.com/fleschutz/PowerShell
	.LINK
		https://github.com/alainQtec/devHelper/blob/main/Private/devHelper.Cli/Public/Write-MOTD.ps1
	#>
  [CmdletBinding()]
  [OutputType([System.string])]
  param (
  )

  Begin {
    $IAp = $InformationPreference ; $InformationPreference = "Continue"
    function GetHostOs() {
      #TODO: refactor so that it returns one of these: [Enum]::GetNames([System.PlatformID])
      return $(switch ($true) {
          $([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) { "Windows"; break }
          $([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::FreeBSD)) { "FreeBSD"; break }
          $([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) { "Linux"; break }
          $([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) { "MacOSX"; break }
          Default {
            "UNKNOWN"
          }
        }
      )
    }
  }

  process {
    $HosOs = GetHostOs
    # Retrieve information:
    $TimeZone = (Get-TimeZone).id
    $UserName = [Environment]::USERNAME
    $ComputerName = [System.Net.Dns]::GetHostName().ToLower()
    $OsBuild = $(if ($HosOs -in 'MacOSX', 'FreeBSD', 'Linux') {
        (uname -a).Split(" ")[2]
      } elseif ($HosOs -eq 'Windows') {
        (Get-CimInstance Win32_OperatingSystem).version.ToString()
      }
    )
    $OSName = "$($HosOs) Build: $OsBuild" #
    $PowerShellVersion = $PSVersionTable.PSVersion
    $PowerShellEdition = $PSVersionTable.PSEdition
    $dt = [datetime]::Now; $day = $dt.ToLongDateString().split(',')[1].trim()
    if ($day.EndsWith('1')) { $day += 'st' }elseif ($day.EndsWith('2')) { $day += 'nd' }elseif ($day.EndsWith('3')) { $day += 'rd' }else { $day += 'th' }
    $CurrentTime = "$day, $($dt.Year) $($dt.Hour):$($dt.Minute)"
    $Uptime = $(if ($HosOs -in 'MacOSX', 'FreeBSD', 'Linux') {
        &uptime | awk '{print $3}'
      } else {
        'S' + $(net statistics workstation | find "Statistics since").Substring(12).Trim();
      }
    )
    $NumberOfProcesses = (Get-Process).Count
    $CPU_Info = $(if ($HosOs -eq 'Windows') {
        $env:PROCESSOR_IDENTIFIER + ' Rev: ' + $env:PROCESSOR_REVISION
      } else {
        &lscpu | grep 'Model name' | awk '{print $3,$4,$5,$6,$7,$8,$9,$10}'
      }
    )
    # $Logical_Disk = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object -Property DeviceID -EQ $OS.SystemDrive
    $Current_Load = $(if ($HosOs -in 'MacOSX', 'FreeBSD', 'Linux') {
        &grep 'cpu ' /proc/stat | awk '{printf "%.2f%\n", ($2+$4)*100/($2+$4+$5)}'
      } else {
        "{0}%" -f $(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average)
      }
    )
    # $Memory_Size = "{0}mb/{1}mb Used" -f (([math]::round($ReturnedValues.Operating_System.TotalVisibleMemorySize / 1KB)) - ([math]::round($ReturnedValues.Operating_System.FreePhysicalMemory / 1KB))), ([math]::round($ReturnedValues.Operating_System.TotalVisibleMemorySize / 1KB))
    $Disk_Size = $(if ($HosOs -eq 'Windows') {
        # "{0}gb/{1}gb Used" -f (([math]::round($ReturnedValues.Logical_Disk.Size / 1GB) - [math]::round($ReturnedValues.Logical_Disk.FreeSpace / 1GB))), ([math]::round($ReturnedValues.Logical_Disk.Size / 1GB))
      } else {
        # Linux:
        $(df -B1G / | awk 'NR==2 {printf "%d %d", $2, $3}')
        # [int[]]$r.Split(" ")
      }
    )
    [Console]::Write([Environment]::NewLine)
    Write-Host " ,.=:^!^!t3Z3z., " -f Red
    Write-Host " :tt:::tt333EE3 " -f Red
    Write-Host " Et:::ztt33EEE " -f Red -NoNewline
    Write-Host " @Ee., ..,     " -f green -NoNewline
    Write-Host "      Uptime: " -f Red -NoNewline
    Write-Host "$CurrentTime" -f Cyan
    Write-Host " ;tt:::tt333EE7" -f Red -NoNewline
    Write-Host " ;EEEEEEttttt33# " -f Green -NoNewline
    Write-Host "    Timezone: " -f Red -NoNewline
    Write-Host "$TimeZone" -f Cyan
    Write-Host " :Et:::zt333EEQ." -NoNewline -f Red
    Write-Host " SEEEEEttttt33QL " -NoNewline -f Green
    Write-Host "   User: " -NoNewline -f Red
    Write-Host "$UserName" -f Cyan
    Write-Host " it::::tt333EEF" -NoNewline -f Red
    Write-Host " @EEEEEEttttt33F " -NoNewline -f Green
    Write-Host "    Hostname: " -NoNewline -f Red
    Write-Host "$ComputerName" -f Cyan
    Write-Host " ;3=*^``````'*4EEV" -NoNewline -f Red
    Write-Host " :EEEEEEttttt33@. " -NoNewline -f Green
    Write-Host "   OS: " -NoNewline -f Red
    Write-Host "$OSName" -f Cyan
    Write-Host " ,.=::::it=., " -NoNewline -f Cyan
    Write-Host "``" -NoNewline -f Red
    Write-Host " @EEEEEEtttz33QF " -NoNewline -f Green
    Write-Host "    Kernel: " -NoNewline -f Red
    Write-Host "NT " -NoNewline -f Cyan
    Write-Host "$Kernel_Info" -f Cyan
    Write-Host " ;::::::::zt33) " -NoNewline -f Cyan
    Write-Host " '4EEEtttji3P* " -NoNewline -f Green
    Write-Host "     Uptime: " -NoNewline -f Red
    Write-Host "$Uptime" -f Cyan
    Write-Host " :t::::::::tt33." -NoNewline -f Cyan
    Write-Host ":Z3z.. " -NoNewline -f Yellow
    Write-Host " ````" -NoNewline -f Green
    Write-Host " ,..g. " -NoNewline -f Yellow
    Write-Host "   PowerShell: " -NoNewline -f Red
    Write-Host "$PowerShellVersion $PowerShellEdition" -f Cyan
    Write-Host " i::::::::zt33F" -NoNewline -f Cyan
    Write-Host " AEEEtttt::::ztF " -NoNewline -f Yellow
    Write-Host "    CPU: " -NoNewline -f Red
    Write-Host "$CPU_Info" -f Cyan
    Write-Host " ;:::::::::t33V" -NoNewline -f Cyan
    Write-Host " ;EEEttttt::::t3 " -NoNewline -f Yellow
    Write-Host "    Processes: " -NoNewline -f Red
    Write-Host "$NumberOfProcesses" -f Cyan
    Write-Host " E::::::::zt33L" -NoNewline -f Cyan
    Write-Host " @EEEtttt::::z3F " -NoNewline -f Yellow
    Write-Host "    Current Load: " -NoNewline -f Red
    Write-Host "$Current_Load" -f Cyan
    Write-Host " {3=*^``````'*4E3)" -NoNewline -f Cyan
    Write-Host " ;EEEtttt:::::tZ`` " -NoNewline -f Yellow
    Write-Host "   Memory: " -NoNewline -f Red
    Write-Host "$Memory_Size" -f Cyan
    Write-Host "              ``" -NoNewline -f Cyan
    Write-Host " :EEEEtttt::::z7 " -NoNewline -f Yellow
    Write-Host "    System Volume: " -NoNewline -f Red
    Write-Host "$Disk_Size" -f Cyan
    Write-Host "                 'VEzjt:;;z>*`` " -f Yellow
    [Console]::Write([Environment]::NewLine)
  }

  end {
    $InformationPreference = $IAp
  }
}
