function Test-Url {
  # .SYNOPSIS
  #     Returns nothing if url is valid, error otherwise
  # .DESCRIPTION
  #     Checks if a url(or a bunch/array of urls) is valid
  # .EXAMPLE
  #     PS C:\> Test-Url 'https://github.com/chadnpc/'
  #     Testing only one link

  # .EXAMPLE
  #     @(
  #     'https://github.com/chadnpc/',
  #     'https://some::_invalid_url_text',
  #     'https://github.com/invalid-link-2/'
  #     ) | Test-Url
  #     Testing an array of urls.

  # .INPUTS
  #     String[]

  # .OUTPUTS
  #     Boolean if input was not an array
  # .NOTES
  #     Not yet reliable: Still needs some fixes
  #     TODO: Make this function work!!!!
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string[]]$Url,

    [Parameter(Mandatory = $false)]
    [int]$Timeout,

    [Parameter(Mandatory = $false)]
    [string]$ExcludeType = 'text/html',

    [Parameter(Mandatory = $false)]
    [string]$Options,

    [Parameter(Mandatory = $false)]
    [switch]$Details
  )

  begin {
    function Invoke_Request {
      <#
            .SYNOPSIS
                A custom Invoke-WebRequest
            .DESCRIPTION
                A .Net.WebRequest function
            #>
      param (
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $false)]
        [int]$Timeout,
        [Parameter(Mandatory = $false)]
        $Options
      )
      if (![string]::IsNullOrWhiteSpace($url)) {
        try {
          $($request = [System.Net.WebRequest]::Create($Url)
            if ($Timeout) { $request.Timeout = $Timeout * 1000 }
            if ($Options.Headers) {
              $Options.Headers.Keys | ForEach-Object {
                if ([System.Net.WebHeaderCollection]::IsRestricted($_)) {
                  $key = $_.Replace('-', '')
                  $request.$key = $Options.Headers[$_]
                } else {
                  $request.Headers.add($_, $Options.Headers[$_])
                }
              }
            }
          ) | Out-Null
          $response = $request.GetResponse()
          [void]$response.Close()
        } catch [System.Net.WebException], [System.Management.Automation.MethodInvocationException] {
          Write-Warning "The remote name could not be resolved"
          $response = $null
        } catch {
          $response = $null
        }
      } else {
        Write-Warning 'The URL is empty'
        $response = $null
      }
      return $response
    }
  }

  process {
    $res = @()
    foreach ($l in $Url) {
      if ([Uri]::IsWellFormedUriString($l, [UriKind]::Absolute)) {
        try {
          $response = Invoke_Request -Url $l -Timeout $Timeout -Options $Options
          if ($response.ContentType -like "*${ExcludeType}*" -and ($null -ne $response)) {
            [void]$res.Add(
              [PSCustomObject]@{
                Name     = $l
                Is_valid = $false
                Details  = "Url not valid. Bad content type '$ExcludeType'"
              }
            )
          } else {
            [void]$res.Add(
              [PSCustomObject]@{
                Name     = $l
                Is_valid = $true
                Details  = 'Url is valid.'
              }
            )
          }
        } catch {
          [void]$res.Add(
            [PSCustomObject]@{
              Name     = $l
              Is_valid = $false
              Details  = "Url not valid. Error: Can't validate URL`n$_"
            }
          )
        }
      } else {
        [void]$res.Add(
          [PSCustomObject]@{
            Name     = $l
            Is_valid = $false
            Details  = "Url not valid. URL syntax is invalid"
          }
        )
      }
    }
    if ($res.Count -le 1) {
      $res = $res[0]
    }
  }

  end {
    return $res
  }
}