# this could be cleaned up with http://learn-powershell.net/2013/02/08/powershell-and-events-object-events/
# learn from:
function Get-FtpFile {
  <#
    .SYNOPSIS
    Downloads a file from a File Transfter Protocol (FTP) location.

    .DESCRIPTION
    This will download a file from an FTP location, saving the file to the
    FileName location specified.

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
    This is the url to download the file from.

    .PARAMETER FileName
    This is the full path to the file to create. If FTPing to the
    package folder next to the install script, the path will be like
    `"$(Split-Path -Parent $MyInvocation.MyCommand.Definition)\\file.exe"`

    .PARAMETER UserName
    The user account to connect to FTP with.

    .PARAMETER Password
    The password for the user account on the FTP server.

    .PARAMETER Quiet
    Silences the progress output.

    .PARAMETER IgnoredArguments
    Allows splatting with arguments that do not apply. Do not use directly.

    .LINK
    Get-ChocolateyWebFile

    .LINK
    Get-WebFile
    #>
  param(
    [parameter(Mandatory = $false, Position = 0)][string] $url = '',
    [parameter(Mandatory = $true, Position = 1)][string] $fileName = $null,
    [parameter(Mandatory = $false, Position = 2)][string] $username = $null,
    [parameter(Mandatory = $false, Position = 3)][SecureString] $password = $null,
    [parameter(Mandatory = $false)][switch] $quiet,
    [parameter(ValueFromRemainingArguments = $true)][Object[]] $ignoredArguments
  )

  # Log Invocation  and Parameters used. $MyInvocation, $PSBoundParameters

  if ($url -eq $null -or $url -eq '') {
    Write-Warning "Url parameter is empty, Get-FtpFile has nothing to do."
    return
  }

  if ($fileName -eq $null -or $fileName -eq '') {
    Write-Warning "FileName parameter is empty, Get-FtpFile cannot save the output."
    return
  }

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
    $null
  }

  # Create a FTPWebRequest object to handle the connection to the ftp server
  $ftprequest = [System.Net.FtpWebRequest]::create($url)

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
    $ftprequest.Proxy = $proxy
  }

  # set the request's network credentials for an authenticated connection
  $ftprequest.Credentials = New-Object System.Net.NetworkCredential($username, $password)

  $ftprequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
  $ftprequest.UseBinary = $true
  $ftprequest.KeepAlive = $false

  # use the default request timeout of 100000
  if ($null -ne $env:dotfilesRequestTimeout -and $env:dotfilesRequestTimeout -ne '') {
    $ftprequest.Timeout = $env:dotfilesRequestTimeout
  }
  if ($null -ne $env:dotfilesResponseTimeout -and $env:dotfilesResponseTimeout -ne '') {
    $ftprequest.ReadWriteTimeout = $env:dotfilesResponseTimeout
  }

  try {
    # send the ftp request to the server
    $ftpresponse = $ftprequest.GetResponse()
    [long]$goal = $ftpresponse.ContentLength
    $goalFormatted = Format-ItemSize $goal

    # get a download stream from the server response
    $reader = $ftpresponse.GetResponseStream()

    # create the target file on the local system and the download buffer
    $writer = New-Object IO.FileStream ($fileName, [IO.FileMode]::Create)
    [byte[]]$buffer = New-Object byte[] 1048576
    [long]$total = [long]$count = 0

    $OgEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    try {
      # loop through the download stream and send the data to the target file
      do {
        $count = $reader.Read($buffer, 0, $buffer.Length);
        $writer.Write($buffer, 0, $count);
        if (!$quiet) {
          $total += $count
          $totalFormatted = Format-ItemSize $total
          if ($goal -gt 0) {
            $percentComplete = [Math]::Truncate(($total / $goal) * 100)
            Write-Progress "Downloading $url to $fileName" "Saving $totalFormatted of $goalFormatted ($total/$goal)" -Id 0 -PercentComplete $percentComplete
          } else {
            Write-Progress "Downloading $url to $fileName" "Saving $total bytes..." -Id 0 -Completed
          }
          if ($total -eq $goal -and $count -eq 0) {
            Write-Progress "Completed download of $url." "Completed a total of $total bytes of $fileName" -Id 0 -Completed -PercentComplete 100
          }
        }
      } while ($count -ne 0)
      Write-Info ""
      Write-Info "Download of $([System.IO.Path]::GetFileName($fileName)) ($goalFormatted) completed."
    } finally {
      $ErrorActionPreference = $OgEAP
    }
    $writer.Flush() # closed in finally block
  } catch {
    if ($null -ne $ftprequest) {
      $ftprequest.ServicePoint.MaxIdleTime = 0
      $ftprequest.Abort();
      # ruthlessly remove $ftprequest to ensure it isn't reused
      Remove-Variable ftprequest
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

    if ($null -ne $reader) {
      try { $reader.Close(); } catch { $null }
    }

    if ($null -ne $writer) {
      try { $writer.Close(); } catch { $null }
    }

    if ($null -ne $ftpresponse) {
      try { $ftpresponse.Close(); } catch { $null }
    }
    Start-Sleep 1
  }
}
