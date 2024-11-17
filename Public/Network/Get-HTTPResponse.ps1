function Get-HTTPResponse {
  [CmdletBinding()]
  param (
    # Parameter help description
    [Parameter(Mandatory = $true)]
    [Uri]$Uri,

    # Parameter help description
    [Parameter(Mandatory = $false)]
    [bool]$HeaderOnly,

    # Parameter help description
    [Parameter(Mandatory = $false)]
    [bool]$DisableRedirect,

    # Parameter help description
    [Parameter(Mandatory = $false)]
    [bool]$DisableFeedCredential
  )

  begin {
    $cts = New-Object System.Threading.CancellationTokenSource
    $downloadScript = {
      $HttpClient = $null
      try {
        # HttpClient is used vs Invoke-WebRequest in order to support Nano Server which doesn't support the Invoke-WebRequest cmdlet.
        try { Add-Type -Assembly System.Net.Http | Out-Null } catch { $null }
        if (-not $ProxyAddress) {
          try {
            # Despite no proxy being explicitly specified, we may still be behind a default proxy
            $DefaultProxy = [System.Net.WebRequest]::DefaultWebProxy;
            if ($DefaultProxy -and (-not $DefaultProxy.IsBypassed($Uri))) {
              if ($null -ne $DefaultProxy.GetProxy($Uri)) {
                $ProxyAddress = $DefaultProxy.GetProxy($Uri).OriginalString
              } else {
                $ProxyAddress = $null
              }
              $ProxyUseDefaultCredentials = $true
            }
          } catch {
            # Eat the exception and move forward as the above code is an attempt
            #    at resolving the DefaultProxy that may not have been a problem.
            $ProxyAddress = $null
            Out-Verbose("Exception ignored: $_.Exception.Message - moving forward...")
          }
        }

        $HttpClientHandler = New-Object System.Net.Http.HttpClientHandler
        if ($ProxyAddress) {
          $HttpClientHandler.Proxy = New-Object System.Net.WebProxy -Property @{
            Address               = $ProxyAddress;
            UseDefaultCredentials = $ProxyUseDefaultCredentials;
            BypassList            = $ProxyBypassList;
          }
        }
        if ($DisableRedirect) {
          $HttpClientHandler.AllowAutoRedirect = $false
        }
        $HttpClient = New-Object System.Net.Http.HttpClient -ArgumentList $HttpClientHandler

        # Default timeout for HttpClient is 100s.  For a 50 MB download this assumes 500 KB/s average, any less will time out
        # Defaulting to 20 minutes allows it to work over much slower connections.
        $HttpClient.Timeout = New-TimeSpan -Seconds $DownloadTimeout

        if ($HeaderOnly) {
          $completionOption = [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
        } else {
          $completionOption = [System.Net.Http.HttpCompletionOption]::ResponseContentRead
        }

        if ($DisableFeedCredential) {
          $UriWithCredential = $Uri
        } else {
          $UriWithCredential = "${Uri}${FeedCredential}"
        }

        $Task = $HttpClient.GetAsync("$UriWithCredential", $completionOption).ConfigureAwait("false");
        $Response = $Task.GetAwaiter().GetResult();

        if (($null -eq $Response) -or ((-not $HeaderOnly) -and (-not ($Response.IsSuccessStatusCode)))) {
          # The feed credential is potentially sensitive info. Do not log FeedCredential to console output.
          $DownloadException = [System.Exception] "Unable to download $Uri."
          if ($null -ne $Response) {
            $DownloadException.Data["StatusCode"] = [int] $Response.StatusCode
            $DownloadException.Data["ErrorMessage"] = "Unable to download $Uri. Returned HTTP status code: " + $DownloadException.Data["StatusCode"]

            if (404 -eq [int] $Response.StatusCode) {
              $cts.Cancel()
            }
          }

          throw $DownloadException
        }

        $response
      } catch [System.Net.Http.HttpRequestException] {
        $DownloadException = [System.Exception] "Unable to download $Uri."
        # Pick up the exception message and inner exceptions' messages if they exist
        $CurrentException = $PSItem.Exception
        $ErrorMsg = $CurrentException.Message + "`r`n"
        while ($CurrentException.InnerException) {
          $CurrentException = $CurrentException.InnerException
          $ErrorMsg += $CurrentException.Message + "`r`n"
        }
        # Check if there is an issue concerning TLS.
        if ($ErrorMsg -like "*SSL/TLS*") {
          $ErrorMsg += "Ensure that TLS 1.2 or higher is enabled to use this script.`r`n"
        }
        $DownloadException.Data["ErrorMessage"] = $ErrorMsg
        throw $DownloadException
      } finally {
        if ($null -ne $HttpClient) {
          $HttpClient.Dispose()
        }
      }
    }
  }

  process {
    try {
      return Invoke-RetriableCommand $downloadScript $cts.Token
    } finally {
      if ($null -ne $cts) {
        $cts.Dispose()
      }
    }
  }

  end {
  }
}