function Write-Bar {
  <#
    .SYNOPSIS
        A short one-line action-based description, e.g. 'Tests if a function is valid'
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        Write-Bar -Text "Sales" -Value 40.0 -Max 100 -change 2

        # A +2% increase in sales

        Write-Bar -Text "Sales" -Value 28 -Max 100 -Change -2

        # A -2% decrease in sales
    #>
  [Alias('Write-ChartBar')]
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, Position = 0)]
    [Alias('Message', 'msg')]
    [string]$Text,

    [Parameter(Mandatory = $true, Position = 1)]
    [float]$Value,

    [Parameter(Mandatory = $false, Position = 2)]
    [Alias('OutOf')]
    [float]$Max,

    [Parameter(Mandatory = $false, Position = 3)]
    [Alias('PercentChange')]
    [float]$Change
  )
  Begin {
    $IAp = $InformationPreference ; $InformationPreference = "Continue"
  }

  process {
    $Num = ($Value * 100.0) / $Max
    while ($Num -ge 1.0) {
      Write-Host -NoNewline "█"
      $Num -= 1.0
    }
    if ($Num -ge 0.875) {
      Write-Host -NoNewline "▉"
    } elseif ($Num -ge 0.75) {
      Write-Host -NoNewline "▊"
    } elseif ($Num -ge 0.625) {
      Write-Host -NoNewline "▋"
    } elseif ($Num -ge 0.5) {
      Write-Host -NoNewline "▌"
    } elseif ($Num -ge 0.375) {
      Write-Host -NoNewline "▍"
    } elseif ($Num -ge 0.25) {
      Write-Host -NoNewline "▎"
    } elseif ($Num -ge 0.125) {
      Write-Host -NoNewline "▏"
    }
    Write-Host -NoNewline " $Text ", "$Value%" -Color Yellow, Blue
    if ($Change -ge 0.0) {
      Write-Host -f green " +$($Change)%"
    } else {
      Write-Host -f red " $($Change)%"
    }
  }

  End {
    $InformationPreference = $IAp
  }
}
