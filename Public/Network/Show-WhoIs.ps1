Set-Alias -Name whois -Value Show-WhoIs
function Show-WhoIs {
  <#
    .SYNOPSIS
        Performs the registration record for a domain name or an IP address.
    .DESCRIPTION
        Show-WhoIs uses API of external services and has no core library
        dependencies, so it can be easily modified for use outside of the
        module.
    .PARAMETER Domain
        Specifies a DNS name or an IP address.
    .PARAMETER UseAlternative
        Strongly required when specifying an IP address.
    .EXAMPLE
        Show-WhoIs 20.54.36.229 -UseAlternative
    .EXAMPLE
        Show-WhoIs microsoft.com
    .INPUTS
        System.String
    .OUTPUTS
        System.Array
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [String]$Domain,

    [Parameter()][Switch]$UseAlternative
  )

  process {
    $params = @{
      Uri     = "https://www.$($UseAlternative ? 'nic.ru/app/v1/get/whois' : ("virustotal.com/api/v3/domains/$Domain"))"
      Method  = $UseAlternative ? 'POST' : 'GET'
      Headers = @{'x-apikey' = '4d1ee14a3191ba1afde5261326dcd7e81793afacb6aa7e46d0b467bc6ebcd367' }
    }

    if ($UseAlternative) {
      $params.Body = "{`"searchWord`":`"$Domain`"}"
      $params.ContentType = 'application/json;charset=UTF-8'
      $params.Remove('Headers')
    }

    if (($res = Invoke-WebRequest @params).StatusCode -ne 200) {
      throw [InvalidOperationException]::new($res.StatusDescription)
    }

    $res = ConvertFrom-Json -InputObject $res.Content
    $UseAlternative ? (
      $res.body.list.ForEach{
        "Registry: $($_.registry)"
        $_.html ? ($_.html -replace '<[^>]*>') : $(
          foreach ($item in $_.formatted) {
            "$($item.name) $($item.value -replace '<[^>]*>')"
          }
        )
      }
    ) : $res.data.attributes.whois
  }
}