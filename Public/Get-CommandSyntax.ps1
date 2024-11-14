
Function Get-CommandSyntax {
  [cmdletbinding()]
  [alias("gsyn")]
  [outputtype("System.String")]
  Param(
    [Parameter(
      Position = 0,
      Mandatory,
      HelpMessage = "Enter the name of a PowerShell cmdlet or function. Ideally it has been loaded into the current PowerShell session."
    )]
    [ValidateScript({ Get-Command -Name $_ })]
    [string]$Name
  )
  foreach ($provider in (Get-PSProvider)) {
    if ($host.name -match "console") {
      "$([char]0x1b)[1;4;38;5;155m$($provider.name)$([char]0x1b)[0m"
    } else {
      $provider.name
    }
    #get first drive
    $path = "$($provider.drives[0]):\"
    Push-Location
    Set-Location $path
    $syn = Get-Command -Name $Name -Syntax | Out-String
    $get = Get-Command -Name $name

    $dynamic = ($get.parameters.GetEnumerator() | Where-Object { $_.value.IsDynamic }).key
    Pop-Location
    if ($dynamic) {
      Write-Verbose "...found $($dynamic.count) dynamic parameters"
      Write-Verbose "...$($dynamic -join ",")"
      foreach ($param in $dynamic) {
        if ($host.name -match 'console') {
          $syn = $syn -replace "\b$param\b", "$([char]0x1b)[1;38;5;213m$param$([char]0x1b)[0m"
        } else {
          #must be in the PowerShell ISE so don't use any ANSI formatting
        }
      }
    }
    $syn
  }
}
