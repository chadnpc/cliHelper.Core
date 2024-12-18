function Write-ProgressBar {
  # .SYNOPSIS
  #     Writes the status progress of activities.
  # .DESCRIPTION
  #     A custom / inline write-progress
  #     With a couple of benefits:
  #     + The progress bar will not disappear after it's done
  #     + You will keep track of the how far the bar had progressed when an error occurs
  #     + It supports transcripts
  # .EXAMPLE
  #     # When used with large number of objects
  #     For ([int]$i=0; $i -le 8192; $i++) { Write-ProgressBar -Completed $i -OutOf 8192 -Activity "Running TaskName:" -CurrentOperation "Working on object $i" }
  # .EXAMPLE
  #     # Using Percentage
  #     For ([int]$i=0; $i -le 150; $i++) {Write-ProgressBar -CurrentOperation "Working on Position $i" -percent $i}
  # .INPUTS
  #     [string]
  # .OUTPUTS
  #     [string]
  # .LINK
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [Alias('p')]
    [int]$percent,

    [Parameter(Mandatory = $true, Position = 1)]
    [Alias('l')]
    [int]$PBLength,

    [Parameter(Mandatory = $false)]
    [string]$CurrentOperation,

    [Parameter(Mandatory = $false)]
    [switch]$update
  )

  end {
    [ProgressUtil]::WriteProgressBar($percent, $update.IsPresent, $PBLength, $CurrentOperation);
  }
}