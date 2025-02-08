function Start-DownloadWithRetry {
  <#
    .SYNOPSIS
      Downloads a file from a specified Uri with retries.

    .DESCRIPTION
      The Start-DownloadWithRetry cmdlet attempts to download a file from the specified Uri to a local path.
      It includes retry logic for handling transient failures, allowing you to specify the maximum number of retries and the delay between attempts.

    .EXAMPLE
      $d = Start-DownloadWithRetry -Uri "https://pastebin.com/raw/JVciSv1S"

    .EXAMPLE
      $baseUri = 'https://github.com/PowerShell/PowerShell/releases/download'
      @(
        "$baseUri/v7.3.0-preview.5/PowerShell-7.3.0-preview.5-win-x64.msi"
        "$baseUri/v7.3.0-preview.5/PowerShell-7.3.0-preview.5-win-x64.zip"
        "$baseUri/v7.2.5/PowerShell-7.2.5-win-x64.zip"
        "$baseUri/v7.2.5/PowerShell-7.2.5-win-x64.msi"
      ) | % { Start-DownloadWithRetry $_}

    .EXAMPLE
      Start-DownloadWithRetry -Uri "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_5mb.mp4" -Name "mysamplevideo.mp4" -DownloadPath $pwd

      Downloads a video to mysamplevideo.mp4 from the specified Uri and saves it as 'mysamplevideo.mp4' in the $pwd directory.

    .EXAMPLE
      $link = (iwr -Method Get -Uri https://catalog.data.gov/dataset/national-student-loan-data-system-722b0 -SkipHttpErrorCheck -verbose:$false).Links.Where({ $_.href.EndsWith(".xls") })[0].href
      Start-DownloadWithRetry -Uri $link -Retries 3 -SecondsBetweenAttempts 10

      Attempts to download the file with a maximum of 3 retries, waiting 10 seconds between each attempt.

    .EXAMPLE
      Start-DownloadWithRetry -Uri $link -WhatIf

      Displays what would happen if the cmdlet runs without actually downloading the file.

    .EXAMPLE
      Start-DownloadWithRetry -Uri $link -Verbose

      Provides detailed output about the download process, including retry attempts and success/failure messages.

    .NOTES
      Author: Alain Herve
      Version: 1.0

    .LINK
      Online Version: https://github.com/alainQtec/cliHelper.Core/blob/main/Public/Network/WebTools/Start-DownloadWithRetry.ps1
  #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
  [Alias('DownloadWithRetry')][OutputType([IO.FileInfo])]
  [CmdletBinding(ConfirmImpact = 'Medium', SupportsShouldProcess = $false)]
  Param(
    # Specifies the Uri of the file to download. This parameter is mandatory.
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [ValidateScript({
        if ([xcrypt]::IsValidUrl($_)) {
          return $true
        }; throw [System.ArgumentException]::new("Please Provide a valid Uri: $_", "Uri")
      })]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Uri,

    # Specifies the name of the file to save locally. If not provided, the file name will be derived from the Uri.
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
    [int]$SecondsBetweenAttempts = 1,

    # Specifies a custom message to display during the download process.
    [Parameter(Mandatory = $false, Position = 5)]
    [Alias('m')]
    [string]$Message = "Downloading file",

    # Allows cancellation of the download operation using a System.Threading.CancellationToken.
    [Parameter(Mandatory = $false, Position = 6)]
    [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
  )

  begin {
    class dlh {
      [string]$Id
      dlh() {
        $this.Id = [Guid]::NewGuid().Guid.replace('-', '').SubString(0, 20)
        $this.PsObject.Properties.Add([PSScriptProperty]::new('Data', [scriptblock]::Create("`$e = Get-Event -SourceIdentifier $($this.Id) -ea Ignore; if (`$e) { return `$e[-1].SourceEventArgs }; return `$null")))
      }
      [string] GetfileSize([long]$Bytes) {
        $sizestr = switch ($bytes) {
          { $bytes -lt 1MB } { "$([Math]::Round($bytes / 1KB, 2)) KB"; break }
          { $bytes -lt 1GB } { "$([Math]::Round($bytes / 1MB, 2)) MB"; break }
          { $bytes -lt 1TB } { "$([Math]::Round($bytes / 1GB, 2)) GB"; break }
          Default { "$([Math]::Round($bytes / 1TB, 2)) TB" }
        }
        return [string]$sizestr
      }
      [string] GetSizeProgress() {
        if ($null -eq $this.Data) {
          return [string]::Empty
        }
        return $this.GetSizeProgress($this.Data.BytesReceived, $this.Data.TotalBytesToReceive)
      }
      [string] GetSizeProgress($r, $t) {
        return "{0} / {1}" -f $($this.GetfileSize($r)), $($this.GetfileSize($t))
      }
    }
  }
  Process {
    if ([String]::IsNullOrEmpty($Name)) { $Name = [IO.Path]::GetFileName($Uri) }
    $OutputFilePath = [IO.Path]::Combine([xcrypt]::GetUnResolvedPath($DownloadPath), $Name)
    $DownloadScript = {
      param([uri]$Uri, [string]$OutFile, $dlEvent, [bool]$verbose)
      try {
        $webClient = [System.Net.WebClient]::new()
        $vOutptTxt = $OutFile | Get-ShortPath
        $Uri_verbose_txt = $Uri.AbsolutePath | Get-ShortPath
        # $webClient.Credentials = $login
        $task = $webClient.DownloadFileTaskAsync($Uri, $OutFile)
        Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -SourceIdentifier $dlEvent.Id | Out-Null
        $verbose ? (Write-Console "  Attempting to download '$Uri_verbose_txt' to '$vOutptTxt'..." -f SteelBlue) : $null
        While (!$task.IsCompleted) {
          if ($null -ne $dlEvent.Data) {
            $ReceivedData = $dlEvent.Data.BytesReceived
            $TotalToReceive = $dlEvent.Data.TotalBytesToReceive
            $TotalPercent = $dlEvent.Data.ProgressPercentage
            if ($null -ne $ReceivedData) {
              [ProgressUtil]::WriteProgressBar([int]$TotalPercent, "  Downloading : $($dlEvent.GetSizeProgress($ReceivedData, $TotalToReceive))")
            }
          }
          [System.Threading.Thread]::Sleep(50)
        }
      } catch {
        Write-Console $_.Exception.Message -f Salmon
        throw $_
      } finally {
        $verbose ? ([ProgressUtil]::WriteProgressBar(100, $true, "  Downloaded $($dlEvent.GetSizeProgress())", $true)) : $null
        if ([IO.File]::Exists($OutFile)) {
          $verbose ? (Write-Console "  OutPath: '$OutFile'" -f SteelBlue) : $null
        }
        Invoke-Command { $webClient.Dispose(); Unregister-Event -SourceIdentifier $dlEvent.Id -Force -ea Ignore } -ea Ignore
      }
      if ([IO.File]::Exists($OutFile)) {
        return Get-Item $OutFile
      } else {
        return [IO.FileInfo]::new($OutFile)
      }
    }
    try {
      $use_verbose = $VerbosePreference -eq 'Continue' -or $verbose.IsPresent
      $SplatParams = @{
        ScriptBlock            = $DownloadScript
        ArgumentList           = @([uri]$Uri, [string]$OutputFilePath, [dlh]::New(), [bool]$use_verbose)
        MaxAttempts            = $Retries
        SecondsBetweenAttempts = $SecondsBetweenAttempts
        Message                = $Message
        CancellationToken      = $CancellationToken
        Verbose                = $use_verbose
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