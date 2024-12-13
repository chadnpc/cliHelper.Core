function Invoke-FileDownload {
  # .SYNOPSIS
  #     Downloads files
  # .DESCRIPTION
  #     Can handle file downloads from an array of @(urls), and can create different names to prevent overwritting file downloads in same dl_folder.
  # .EXAMPLE
  #     $Url = (
  #     'https://cdimage.debian.org/debian-cd/current/i386/iso-cd/debian-8.8.0-i386-CD-1.iso',
  #     'https://cdimage.debian.org/debian-cd/current/i386/iso-cd/debian-8.8.0-i386-CD-2.iso'
  #     )
  #     Invoke-FileDownload -Urls $Url -OutPath $DownloadsFolder
  # .EXAMPLE
  #     Invoke-FileDownload -Url @( 'https://community.chocolatey.org/7za.exe', 'https://community.chocolatey.org/7za.exe') -OutPath .\7za
  #     When there are duplicate urls, THe output files will be numbered (ie: 7za.exe and 7za1.exe)
  # .INPUTS
  #     [String]
  # .OUTPUTS
  #     [String]
  param (
    # Name with extention of the file
    [Parameter(Mandatory = $false)]
    [Alias('BaseName')]
    [string]$Name,
    # File download link
    [Parameter(Mandatory = $true)]
    [Alias('FileUrl', 'Urls')]
    [string[]]$Url,
    # Output directory of the downloaded file
    [Parameter(Mandatory = $false)]
    [Alias('FileDirectory')]
    [String]$OutPath,
    [Parameter(Mandatory = $false)]
    [hashtable]$ProxyConfiguration,
    #TODO: Add support for AWS_BUCKET (!Comming soon!)
    [Parameter(Mandatory = $false)]
    [string]$AwsBucketName,
    [Parameter(Mandatory = $false)]
    [int]$Retries = 20,
    # Forcefully do things. like overwriting files with sme name
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    # Don't show the progress bar (Silent)
    [Parameter(Mandatory = $false)]
    [switch]$Silent
  )
  begin {
    $InformationPreference = 'Continue'
    function Get-WebFile {
      <#
    .SYNOPSIS
    Downloads a file from an HTTP/HTTPS location. Prefer HTTPS when
    available.

    .DESCRIPTION
    This will download a file from an HTTP/HTTPS location, saving the file
    to the FileName location specified.

    .NOTES
    This is a low-level function and not recommended for use in package
    scripts. It is recommended you call `Get-ChocolateyWebFile` instead.

    Starting in 0.9.10, will automatically call Set-PowerShellExitCode to
    set the package exit code to 404 if the resource is not found.

    .INPUTS
    None

    .OUTPUTS
    None

    .PARAMETER Url
    This is the url to download the file from. Prefer HTTPS when available.

    .PARAMETER FileName
    This is the full path to the file to create. If downloading to the
    package folder next to the install script, the path will be like
    `"$(Split-Path -Parent $MyInvocation.MyCommand.Definition)\\file.exe"`

    .PARAMETER UserAgent
    The user agent to use as part of the request. Defaults to 'chocolatey
    command line'.

    .PARAMETER PassThru
    DO NOT USE - holdover from original function.

    .PARAMETER Quiet
    Silences the progress output.

    .PARAMETER Options
    OPTIONAL - Specify custom headers. Available in 0.9.10+.

    .PARAMETER IgnoredArguments
    Allows splatting with arguments that do not apply. Do not use directly.

    .LINK
    Get-ChocolateyWebFile

    .LINK
    Get-FtpFile

    .LINK
    Get-WebHeaders

    .LINK
    Get-WebFileName
    #>
      param(
        [parameter(Mandatory = $false, Position = 0)][string] $url = '', #(Read-Host "The URL to download"),
        [parameter(Mandatory = $false, Position = 1)][string] $fileName = $null,
        [parameter(Mandatory = $false, Position = 2)][string] $userAgent = 'chocolatey command line',
        [parameter(Mandatory = $false)][switch] $Passthru,
        [parameter(Mandatory = $false)][switch] $quiet,
        [parameter(Mandatory = $false)][hashtable] $options = @{Headers = @{} }
      )

      DynamicParam {
        $DynamicParams = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
        #region IgnoredArguments
        $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
        $attributes = [System.Management.Automation.ParameterAttribute]::new(); $attHash = @{
          Position                        = 6
          ParameterSetName                = '__AllParameterSets'
          Mandatory                       = $False
          ValueFromPipeline               = $true
          ValueFromPipelineByPropertyName = $true
          ValueFromRemainingArguments     = $true
          HelpMessage                     = 'Allows splatting with arguments that do not apply. Do not use directly.'
          DontShow                        = $False
        }; $attHash.Keys | ForEach-Object { $attributes.$_ = $attHash.$_ }
        $attributeCollection.Add($attributes)
        # $attributeCollection.Add([System.Management.Automation.ValidateSetAttribute]::new([System.Object[]]$ValidateSetOption))
        # $attributeCollection.Add([System.Management.Automation.ValidateRangeAttribute]::new([System.Int32[]]$ValidateRange))
        # $attributeCollection.Add([System.Management.Automation.ValidateNotNullOrEmptyAttribute]::new())
        # $attributeCollection.Add([System.Management.Automation.AliasAttribute]::new([System.String[]]$Aliases))
        $RuntimeParam = [System.Management.Automation.RuntimeDefinedParameter]::new("IgnoredArguments", [Object[]], $attributeCollection)
        $DynamicParams.Add("IgnoredArguments", $RuntimeParam)
        #endregion IgnoredArguments
        return $DynamicParams
      }

      Process {
        $PsCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
        # Log Invocation  and Parameters used. $MyInvocation, $PSBoundParameters

        try {
          $uri = [System.Uri]$url
          if ($uri.IsFile()) {
            Write-Debug "Url is local file, setting destination"
            if ($url.LocalPath -ne $fileName) {
              Copy-Item $uri.LocalPath -Destination $fileName -Force
            }

            return
          }
        } catch {
          #continue on
          $null
        }

        $req = [System.Net.HttpWebRequest]::Create($url);
        $defaultCreds = [System.Net.CredentialCache]::DefaultCredentials
        if ($null -ne $defaultCreds) {
          $req.Credentials = $defaultCreds
        }

        $webclient = New-Object System.Net.WebClient
        if ($null -ne $defaultCreds) {
          $webClient.Credentials = $defaultCreds
        }

        # check if a proxy is required
        $explicitProxy = $env:dotfilesProxyLocation
        $explicitProxyUser = $env:dotfilesProxyUser
        $explicitProxyPassword = $env:dotfilesProxyPassword
        $explicitProxyBypassList = $env:dotfilesProxyBypassList
        $explicitProxyBypassOnLocal = $env:dotfilesProxyBypassOnLocal
        if ($null -ne $explicitProxy) {
          # explicit proxy
          $proxy = New-Object System.Net.WebProxy($explicitProxy, $true)
          if ($null -ne $explicitProxyPassword) {
            $passwd = ConvertTo-SecureString $explicitProxyPassword
            $proxy.Credentials = New-Object System.Management.Automation.PSCredential ($explicitProxyUser, $passwd)
          }

          if ($null -ne $explicitProxyBypassList -and $explicitProxyBypassList -ne '') {
            $proxy.BypassList = $explicitProxyBypassList.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)
          }
          if ($explicitProxyBypassOnLocal -eq 'true') { $proxy.BypassProxyOnLocal = $true; }

          Write-Info "Using explicit proxy server '$explicitProxy'."
          $req.Proxy = $proxy
        } elseif ($webclient.Proxy -and !$webclient.Proxy.IsBypassed($url)) {
          # system proxy (pass through)
          $creds = [net.CredentialCache]::DefaultCredentials
          if ($null -eq $creds) {
            Write-Debug "Default credentials were null. Attempting backup method"
            $cred = Get-Credential
            $creds = $cred.GetNetworkCredential();
          }
          $proxyaddress = $webclient.Proxy.GetProxy($url).Authority
          Write-Info "Using system proxy server '$proxyaddress'."
          $proxy = New-Object System.Net.WebProxy($proxyaddress)
          $proxy.Credentials = $creds
          $proxy.BypassProxyOnLocal = $true
          $req.Proxy = $proxy
        }

        $req.Accept = "*/*"
        $req.AllowAutoRedirect = $true
        $req.MaximumAutomaticRedirections = 20
        #$req.KeepAlive = $true
        $req.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
        $req.Timeout = 30000
        if ($null -ne $env:dotfilesRequestTimeout -and $env:dotfilesRequestTimeout -ne '') {
          Write-Debug "Setting request timeout to  $env:dotfilesRequestTimeout"
          $req.Timeout = $env:dotfilesRequestTimeout
        }
        if ($null -ne $env:dotfilesResponseTimeout -and $env:dotfilesResponseTimeout -ne '') {
          Write-Debug "Setting read/write timeout to  $env:dotfilesResponseTimeout"
          $req.ReadWriteTimeout = $env:dotfilesResponseTimeout
        }

        #http://stackoverflow.com/questions/518181/too-many-automatic-redirections-were-attempted-error-message-when-using-a-httpw
        $req.CookieContainer = New-Object System.Net.CookieContainer
        if ($null -ne $userAgent) {
          Write-Debug "Setting the UserAgent to `'$userAgent`'"
          $req.UserAgent = $userAgent
        }

        if ($options.Headers.Count -gt 0) {
          Write-Debug "Setting custom headers"
          foreach ($key in $options.headers.keys) {
            $uri = (New-Object -TypeName system.uri $url)
            switch ($key) {
              'Accept' { $req.Accept = $options.headers.$key }
              'Cookie' { $req.CookieContainer.SetCookies($uri, $options.headers.$key) }
              'Referer' { $req.Referer = $options.headers.$key }
              'User-Agent' { $req.UserAgent = $options.headers.$key }
              Default { $req.Headers.Add($key, $options.headers.$key) }
            }
          }
        }

        try {
          $res = $req.GetResponse();

          try {
            $headers = @{}
            foreach ($key in $res.Headers) {
              $value = $res.Headers[$key];
              if ($value) {
                $headers.Add("$key", "$value")
              }
            }

            $binaryIsTextCheckFile = "$fileName.istext"
            if (Test-Path($binaryIsTextCheckFile)) { Remove-Item $binaryIsTextCheckFile -Force -EA SilentlyContinue; }

            if ($headers.ContainsKey("Content-Type")) {
              $contentType = $headers['Content-Type']
              if ($null -ne $contentType) {
                if ($contentType.ToLower().Contains("text/html") -or $contentType.ToLower().Contains("text/plain")) {
                  Write-Warning "$fileName is of content type $contentType"
                  Set-Content -Path $binaryIsTextCheckFile -Value "$fileName has content type $contentType" -Encoding UTF8 -Force
                }
              }
            }
          } catch {
            # not able to get content-type header
            Write-Debug "Error getting content type - $($_.Exception.Message)"
          }

          if ($fileName -and !(Split-Path $fileName)) {
            $fileName = Join-Path (Get-Location -PSProvider "FileSystem") $fileName
          } elseif ((!$Passthru -and ($null -eq $fileName)) -or (($null -ne $fileName) -and (Test-Path -PathType "Container" $fileName))) {
            [string]$fileName = ([regex]'(?i)filename=(.*)$').Match( $res.Headers["Content-Disposition"] ).Groups[1].Value
            $fileName = $fileName.trim("\/""'")
            if (!$fileName) {
              $fileName = $res.ResponseUri.Segments[-1]
              $fileName = $fileName.trim("\/")
              if (!$fileName) {
                $fileName = Read-Host "Please provide a file name"
              }
              $fileName = $fileName.trim("\/")
              if (!([IO.FileInfo]$fileName).Extension) {
                $fileName = $fileName + "." + $res.ContentType.Split(";")[0].Split("/")[1]
              }
            }
            $fileName = Join-Path (Get-Location -PSProvider "FileSystem") $fileName
          }
          if ($Passthru) {
            $encoding = [System.Text.Encoding]::GetEncoding( $res.CharacterSet )
            [string]$output = ""
          }

          if ($res.StatusCode -eq 401 -or $res.StatusCode -eq 403 -or $res.StatusCode -eq 404) {
            $env:dotfilesExitCode = $res.StatusCode
            throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$url'."
          }

          if ($res.StatusCode -eq 200) {
            [long]$goal = $res.ContentLength
            $goalFormatted = Format-ItemSize $goal
            $reader = $res.GetResponseStream()

            if ($fileName) {
              $fileDirectory = $([System.IO.Path]::GetDirectoryName($fileName))
              if (!(Test-Path($fileDirectory))) {
                [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null
              }

              try {
                $writer = New-Object System.IO.FileStream $fileName, "Create"
              } catch {
                throw $_.Exception
              }
            }

            [byte[]]$buffer = New-Object byte[] 1048576
            [long]$total = [long]$count = [long]$iterLoop = 0

            $OgEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Stop'
            try {
              do {
                $count = $reader.Read($buffer, 0, $buffer.Length);
                if ($fileName) {
                  $writer.Write($buffer, 0, $count);
                }

                if ($Passthru) {
                  $output += $encoding.GetString($buffer, 0, $count)
                } elseif (!$quiet) {
                  $total += $count
                  $totalFormatted = Format-ItemSize $total
                  if ($goal -gt 0 -and ++$iterLoop % 10 -eq 0) {
                    $percentComplete = [Math]::Truncate(($total / $goal) * 100)
                    Write-Progress "Downloading $url to $fileName" "Saving $totalFormatted of $goalFormatted" -Id 0 -PercentComplete $percentComplete
                  }

                  if ($total -eq $goal -and $count -eq 0) {
                    Write-Progress "Completed download of $url." "Completed download of $fileName ($goalFormatted)." -Id 0 -Completed -PercentComplete 100
                  }
                }
              } while ($count -gt 0)
              Write-Info ""
              Write-Info "Download of $([System.IO.Path]::GetFileName($fileName)) ($goalFormatted) completed."
            } catch {
              throw $_.Exception
            } finally {
              $ErrorActionPreference = $OgEAP
            }

            $reader.Close()
            if ($fileName) {
              $writer.Flush()
              $writer.Close()
            }
            if ($Passthru) {
              $output
            }
          }
        } catch {
          if ($null -ne $req) {
            $req.ServicePoint.MaxIdleTime = 0
            $req.Abort();
            # ruthlessly remove $req to ensure it isn't reused
            Remove-Variable req
            Start-Sleep 1
            [System.GC]::Collect()
          }

          Set-PowerShellExitCode 404
          if ($env:DownloadCacheAvailable -eq 'true') {
            throw "The remote file either doesn't exist, is unauthorized, or is forbidden for url '$url'. $($_.Exception.Message) `nThis package is likely not broken for licensed users - see https://docs.chocolatey.org/en-us/features/private-cdn."
          } else {
            throw "The remote file either doesn't exist, is unauthorized, or is forbidden for url '$url'. $($_.Exception.Message)"
          }
        } finally {
          if ($null -ne $res) {
            $res.Close()
          }

          Start-Sleep 1
        }
      }
    }
  }
  process {
    $OutPath = if ($PSBoundParameters.Keys.Contains('OutPath')) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutPath) }else { [System.IO.Path]::Combine($([IO.Path]::GetTempPath()), $((New-Guid).Guid.trim()).ToUpper()) }
    Write-Debug "`$OutPath = $OutPath"
    if (!(Test-Path $OutPath -Type Container)) { New-Item -Path $OutPath -Type Directory | Out-Null; [bool]$OutPathWasnotThere = $true }
    $testCNs = ('142.250.188.238', '20.112.52.29', '20.103.85.33', '20.81.111.85', '20.53.203.50', '20.84.181.62')
    try {
      if (!(Test-Connection -ComputerName $testCNs[0] -Count 2 -Delay 1 -ErrorAction SilentlyContinue )) {
        throw [System.Net.NetworkInformation.PingException]::New('Testing connection failed: Error due to lack of resources')
      }
      # TODO: Add a cool progressbar
      $Progress = @{}
      $Count = 0
      $Timer = New-Object System.Timers.Timer
      $timer.Interval = 100
      $timer.AutoReset = $true
      $timer.Start()
      $WebClients = [System.Collections.ArrayList]::new()
      foreach ($link in $Url) {
        $w = New-Object System.Net.WebClient
        $null = Register-ObjectEvent -InputObject $w -EventName DownloadProgressChanged -Action ([scriptblock]::Create(
            "`$Percent = 100 * `$eventargs.BytesReceived / `$eventargs.TotalBytesToReceive; `$null = New-Event -SourceIdentifier MyDownloadUpdate -MessageData @($count,`$Percent)"
          )
        )
        [int]$fn = 0
        do {
          $Name = if ($PSBoundParameters.Keys.Contains('Name')) {
            if ($fn -eq 0) { $Name }else {
              $x = $Name.Split('.') # $x = extention
              $(($x.Split($x[-1]) | Where-Object { $_.Trim().Length -ne 0 }) -join '.') + $fn + '.' + $x[-1]
            }
          } else {
            if ($fn -eq 0) { $link.Split('/')[-1] }else {
              $x = $link.Split('/')[-1].Split('.')
              $(($x.Split($x[-1]) | Where-Object { $_.Trim().Length -ne 0 }) -join '.') + $fn + '.' + $x[-1]
            }
          }
          $fn++
          $OutFile = Join-Path "$OutPath" $Name
        } while (Test-Path $OutFile -Type Leaf)
        Write-Info "`nDownloading`t" -NoNewline -ForegroundColor Green; Write-Info $Name -NoNewline -ForegroundColor DarkCyan; Write-Info "`t..." -NoNewline -ForegroundColor Green
        $w.DownloadFileAsync($link, "$OutFile")
        Write-Info "`tDone" -ForegroundColor Green
        $Count++
        $WebClients.Add($w) | Out-Null

        $dlevent = Register-EngineEvent -SourceIdentifier MyDownloadUpdate -Action {
          $progress[$dlevent.MessageData[0]] = $dlevent.MessageData[1]
        }

        Register-ObjectEvent -InputObject $Timer -EventName Elapsed -Action {
          if ($Progress.Values.Count -gt 0) {
            $PercentComplete = 100 * ($Progress.values | Measure-Object -Sum | Select-Object -ExpandProperty Sum) / $Progress.Values.Count
            Write-Progress -Activity "Download Progress" -PercentComplete $PercentComplete
          }
        } | Out-Null
      }
      if ([bool]@($WebClients | ForEach-Object { $_.IsBusy -eq $false })) {
        # "I guess at this point it should be finished"
        $timer.Stop()
      }
      $WebClients.Clear()
    } catch [System.Net.WebException], [System.IO.IOException] {
      if ($OutPathWasnotThere) { Remove-Item -Path $OutPath -Force }
      Write-Warning "Unable to download $Name from $Url`n"; Write-Info "[Info] $($Error.exeption.message)"; Start-Sleep -Seconds 3;
      return
    } catch [System.Net.NetworkInformation.PingException], [System.Management.ManagementException], [System.Net.Sockets.SocketException] {
      Write-Warning "Network connection failed!"
      Write-Info "[Info] Please Check your Internet Connection, and try again."; Start-Sleep -Seconds 3;
      return
    } catch {
      if ($OutPathWasnotThere) { Remove-Item -Path $OutPath -Force }
      Write-Info "`n[Info] An error occurred that could not be resolved."; Start-Sleep -Seconds 3;
      return
    }
  }
}