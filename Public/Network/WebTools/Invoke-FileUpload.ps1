function Invoke-FileUpload {
  # .SYNOPSIS
  #    Uploads a local file to a FTP server
  # .DESCRIPTION
  #    This PowerShell script uploads a local file to a FTP server.
  # .PARAMETER File
  #    Specifies the path to the local file
  # .PARAMETER URL
  #    Specifies the FTP server URL
  # .PARAMETER Username
  #    Specifies the user name
  # .PARAMETER Password
  #    Specifies the password
  # .EXAMPLE
  #    PS> Invoke-FileUpload -File $filePath
  [CmdletBinding()]
  param(
    [string]$File,
    [string]$URL,
    [string]$Username,
    [SecureString]$Password
  )

  begin {
    #$PasswordString = [System.Net.NetworkCredential]::new("", $Password).Password
  }

  process {
    try {
      if ($File -eq "") { $File = Read-Host "Enter local file to upload" }
      if ($URL -eq "") { $URL = Read-Host "Enter URL of FTP server" }
      if ($Username -eq "") { $Username = Read-Host "Enter username for login" }
      if ($Password -eq "") { $Password = Read-Host "Enter password for login" }
      [bool]$EnableSSL = $true
      [bool]$UseBinary = $true
      [bool]$UsePassive = $true
      [bool]$KeepAlive = $true
      [bool]$IgnoreCert = $true

      $StopWatch = [system.diagnostics.stopwatch]::startNew()

      # check local file:
      $FullPath = Resolve-Path "$File"
      if (-not(Test-Path "$FullPath"-PathType leaf)) { throw "Can't access file: $FullPath" }
      $Filename = (Get-Item $FullPath).Name
      $FileSize = (Get-Item $FullPath).Length
      Out-Verbose "⏳ Uploading 📄$Filename ($FileSize bytes) to $URL ..."

      # prepare request:
      $Request = [Net.WebRequest]::Create("$URL/$Filename")
      $Request.Credentials = [System.Net.NetworkCredential]::new($Username, $Password)
      $Request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
      $Request.EnableSSL = $EnableSSL
      $Request.UseBinary = $UseBinary
      $Request.UsePassive = $UsePassive
      $Request.KeepAlive = $KeepAlive
      [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $IgnoreCert }

      $fileStream = [System.IO.File]::OpenRead("$FullPath")
      $ftpStream = $Request.GetRequestStream()

      $Buf = New-Object Byte[] 32KB
      while (($DataRead = $fileStream.Read($Buf, 0, $Buf.Length)) -gt 0) {
        $ftpStream.Write($Buf, 0, $DataRead)
        $pct = ($fileStream.Position / $fileStream.Length)
        Write-Progress -Activity "Uploading" -Status "$($pct + '% complete')" -PercentComplete $($pct * 100)
      }

      # cleanup:
      $ftpStream.Dispose()
      $fileStream.Dispose()

      [int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
      Out-Verbose "✅ uploaded 📄$Filename to $URL in $Elapsed sec"
      # success
    } catch {
      [int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
      Write-Error "⛔  Error in line $($_.InvocationInfo.ScriptLineNumber): $($Error[0]) after $Elapsed sec."
      break
    }
  }

  end {
  }
}