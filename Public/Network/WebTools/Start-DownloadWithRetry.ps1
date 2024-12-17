function Start-DownloadWithRetry {
  <#
    .SYNOPSIS
      Downloads a file from a specified URL with retries.

    .DESCRIPTION
      The Start-DownloadWithRetry cmdlet attempts to download a file from the specified URL to a local path.
      It includes retry logic for handling transient failures, allowing you to specify the maximum number of retries and the delay between attempts.

    .EXAMPLE
      Start-DownloadWithRetry -Url "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_5mb.mp4"

      Downloads a video to mysamplevideo.mp4 from the specified URL to the system's temporary directory.

    .EXAMPLE
      Start-DownloadWithRetry -Url "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_5mb.mp4" -Name "mysamplevideo.mp4" -DownloadPath $pwd

      Downloads a video to mysamplevideo.mp4 from the specified URL and saves it as 'mysamplevideo.mp4' in the $pwd directory.

    .EXAMPLE
      $link = (iwr -Method Get -Uri https://catalog.data.gov/dataset/national-student-loan-data-system-722b0 -SkipHttpErrorCheck -verbose:$false).Links.Where({ $_.href.EndsWith(".xls") })[0].href
      Start-DownloadWithRetry -Url $link -Retries 3 -SecondsBetweenAttempts 10

      Attempts to download the file with a maximum of 3 retries, waiting 10 seconds between each attempt.

    .EXAMPLE
      Start-DownloadWithRetry -Url $link -WhatIf

      Displays what would happen if the cmdlet runs without actually downloading the file.

    .EXAMPLE
      Start-DownloadWithRetry -Url $link -Verbose

      Provides detailed output about the download process, including retry attempts and success/failure messages.

    .NOTES
      Author: Alain Herve
      Version: 1.0

    .LINK
      Online Version: https://github.com/alainQtec/cliHelper.Core/blob/main/Public/Network/WebTools/Start-DownloadWithRetry.ps1
  #>
  [Alias('DownloadWithRetry')][OutputType([IO.FileInfo])]
  [CmdletBinding(ConfirmImpact = 'Medium', SupportsShouldProcess = $true)]
  Param(
    # Specifies the URL of the file to download. This parameter is mandatory.
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({
        if ([xcrypt]::IsValidUrl($_)) {
          return $true
        }; throw [System.ArgumentException]::new("Please Provide a valid URL: $_", "Url")
      })]
    [Alias('uri')][ValidateNotNullOrWhiteSpace()]
    [string]$Url,

    # Specifies the name of the file to save locally. If not provided, the file name will be derived from the URL.
    [Parameter(Mandatory = $false, Position = 1)]
    [Alias('n')][ValidateNotNullOrWhiteSpace()]
    [string]$Name,

    # Specifies the local directory where the file will be saved. Defaults to the current directory.
    [Parameter(Mandatory = $false, Position = 2)]
    [Alias('dlPath')][ValidateNotNullOrWhiteSpace()]
    [string]$DownloadPath = (Get-Location).Path,

    # Specifies the maximum number of retry attempts if the download fails. Defaults to 5.
    [Parameter(Mandatory = $false, Position = 3)]
    [Alias('r')]
    [int]$Retries = 5,

    # Specifies the delay, in seconds, between retry attempts. Defaults to 5 seconds.
    [Parameter(Mandatory = $false, Position = 4)]
    [Alias('s', 'timeout')]
    [int]$SecondsBetweenAttempts = 5,

    # Specifies a custom message to display during the download process.
    [Parameter(Mandatory = $false, Position = 5)]
    [Alias('m')]
    [string]$Message = "Downloading file",

    # Allows cancellation of the download operation using a System.Threading.CancellationToken.
    [Parameter(Mandatory = $false, Position = 6)]
    [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
  )

  Process {
    if ([String]::IsNullOrEmpty($Name)) { $Name = [IO.Path]::GetFileName($Url) }
    $OutputFilePath = [IO.Path]::Combine([xcrypt]::GetUnResolvedPath($DownloadPath), $Name)
    $url_verbose_txt = $url | Invoke-PathShortener
    $outfile_verbose_txt = $OutputFilePath | Invoke-PathShortener
    $GetfileSize = {
      param([long]$Bytes)
      switch ($bytes) {
        { $bytes -lt 1MB } { return "$([Math]::Round($bytes / 1KB, 2)) KB" }
        { $bytes -lt 1GB } { return "$([Math]::Round($bytes / 1MB, 2)) MB" }
        { $bytes -lt 1TB } { return "$([Math]::Round($bytes / 1GB, 2)) GB" }
        Default { return "$([Math]::Round($bytes / 1TB, 2)) TB" }
      }
    }
    $dlEvent = [PSCustomObject]@{ size_str = [string]::Empty }
    $DownloadScript = {
      param([uri]$Uri, [string]$FilePath)
      try {
        $vOutptTxt = $outfile_verbose_txt ? $outfile_verbose_txt : ($FilePath | Split-Path -Leaf)
        $webClient = [System.Net.WebClient]::new()
        # $webClient.Credentials = $login
        $task = $webClient.DownloadFileTaskAsync($Uri, $FilePath)
        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -SourceIdentifier WebClient.DownloadProgressChanged | Out-Null
        $verbose ? (Write-Console "  Attempting to download '$url_verbose_txt' to '$vOutptTxt'..." -f SteelBlue) : $null
        $dlEvent.PsObject.Properties.Add([PSScriptProperty]::new('Data', {
              $e = Get-Event -SourceIdentifier WebClient.DownloadProgressChanged -ea Ignore
              if ($e) {
                return $e[-1].SourceEventArgs
              }; return $null
            }
          )
        )
        While (!$task.IsCompleted) {
          if ($null -ne $dlEvent.Data) {
            $ReceivedData = $dlEvent.Data.BytesReceived
            $TotalToReceive = $dlEvent.Data.TotalBytesToReceive
            $TotalPercent = $dlEvent.Data.ProgressPercentage
            if ($null -ne $ReceivedData -and $verbose) {
              $dlEvent.size_str = "{0} / {1}" -f $($GetfileSize.Invoke($ReceivedData)), $($GetfileSize.Invoke($TotalToReceive))
              [ProgressUtil]::WriteProgressBar([int]$TotalPercent, "  Downloading : $($dlEvent.size_str)")
            }
          }
          [System.Threading.Thread]::Sleep(50)
        }
      } catch {
        Write-Console $_.Exception.Message -f Salmon
        throw $_
      } finally {
        $verbose ? ([ProgressUtil]::WriteProgressBar(100, $true, "  Downloaded $($dlEvent.size_str)", $true)) : $null
        if ([IO.File]::Exists($FilePath)) {
          $verbose ? (Write-Console "  OutPath: '$FilePath'" -f SteelBlue) : $null
        }
        Invoke-Command { Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged -Force -ea Ignore; $webClient.Dispose() } -ea Ignore
      }
      if ([IO.File]::Exists($FilePath)) {
        return Get-Item $FilePath
      } else {
        return [IO.FileInfo]::new($FilePath)
      }
    }

    try {
      $SplatParams = @{
        ScriptBlock            = $DownloadScript
        ArgumentList           = @($Url, $OutputFilePath)
        MaxAttempts            = $Retries
        SecondsBetweenAttempts = $SecondsBetweenAttempts
        Message                = $Message
        CancellationToken      = $CancellationToken
        Verbose                = $VerbosePreference
      }
      $result = Invoke-RetriableCommand @SplatParams
    } catch {
      throw $_
    }
  }

  end {
    return $result.Output
  }
}
