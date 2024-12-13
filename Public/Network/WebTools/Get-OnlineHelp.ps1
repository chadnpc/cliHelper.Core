function Get-OnlineHelp {
  [CmdletBinding()]
  param(
    [System.Uri]$Url
  )

  $OnlineHelp = New-Object PSObject -Property @{
    Summary = $null
  }

  if ($Url.Host -eq 'msdn.microsoft.com') {
    $Content = Invoke-WebRequest $Url
    # $main = $Content.ParsedHtml.getElementsByTagName('main')
    # $content.ParsedHtml.head.getElementsByTagName('meta') | ForEach-Object {
    #     if ($_.Name -eq 'Description') {$OnlineHelp.Summary = $_.Content; return}
    # }
    $OnlineHelp.Summary = $Content.ParsedHtml.getElementsByClassName('summary')[0].innerText
    $OnlineHelp
  } else {
    Write-Warning 'Only MSDN recognized for online help.'
  }
}