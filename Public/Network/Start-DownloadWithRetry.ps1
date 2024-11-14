function Start-DownloadWithRetry {

  # .SYNOPSIS
  #     Starts n item Download With Retry
  # .DESCRIPTION
  #     A longer description of the function, its purpose, common use cases, etc.
  # .NOTES
  #     Information or caveats about the function e.g. 'This function is not supported in Linux'
  # .EXAMPLE
  #     $releasesJsonUrl = "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/6.0/releases.json"
  #     Start-DownloadWithRetry -Url $releasesJsonUrl -DownloadPath $pwd -Verbose
  [Alias('DownloadWithRetry')]
  [CmdletBinding(ConfirmImpact = 'Medium')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
  Param(
    [Parameter(Mandatory = $true, Position = 0)]
    [Alias('uri')]
    [string]$Url,

    [Parameter(Mandatory = $false, Position = 1)]
    [Alias('N')]
    [string]$Name,

    [Parameter(Mandatory = $false, Position = 2)]
    [Alias('dlPath')]
    [string]$DownloadPath = "${env:Temp}",

    [Parameter(Mandatory = $false, Position = 3)]
    [int]$Retries = 5,

    [Parameter(Mandatory = $false, Position = 4)]
    [int]$SecondsBetweenAttempts = 5,

    [Parameter(Mandatory = $false, Position = 5)]
    [string]$Message,

    [Parameter(Mandatory = $false, Position = 6)]
    [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
  )

  Begin {
    [System.Management.Automation.ActionPreference]$eap = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
    if ([String]::IsNullOrEmpty($Name)) {
      $Name = [IO.Path]::GetFileName($Url)
    }
    $Url_short = $($Url.substring(0, $([System.Console]::WindowWidth / 4)))
    #region Classes
    class DownloadClient {
      [ValidateNotNullOrEmpty()][string]$Url
      [ValidateNotNullOrEmpty()][string]$FilePath

      $sw = [System.Diagnostics.Stopwatch]::new();
      DownloadClient() {}
      DownloadClient([string]$Url, [string]$FilePath) {
        [Uri]$this.Url = GetUrl($Url)
      }
      DownloadClient([Uri]$Url, [string]$FilePath) {
        [Uri]$this.Url = GetUrl($Url)
      }
      DownloadClient([Uri]$Url, [IO.FileInfo]$FilePath) {
        [Uri]$this.Url = GetUrl($Url)
      }
      [Uri]GetUrl($Url) {
        $comparison = [System.StringComparison]::OrdinalIgnoreCase
        $This.Url = $Url.ToString()
        $Uri = if ($Url.StartsWith("http://", $comparison) -or $Url.StartsWith("https://", $comparison)) { [Uri]::new($Url) } else { [Uri]::new("https://" + $Url) }
        return $Uri
      }
      [void]DownloadFile([Uri]$urlAddress, [string]$location, [System.Diagnostics.Stopwatch]$sw) {
        $webClient = [System.Net.WebClient]::new();
        # $webClient.DownloadFileCompleted =+ [System.ComponentModel.AsyncCompletedEventHandler]::new([System.Object]$object, [System.IntPtr]$method);
        # $webClient.DownloadProgressChanged += [System.Net.DownloadProgressChangedEventHandler]::new([System.Object]$object, [System.IntPtr]$method);
        $sw.Start();
        try {
          $webClient.DownloadFile($urlAddress, $location);
        } catch [System.Net.WebException], [System.IO.IOException] {
          # Write-Log $_.Exception.ErrorRecord
          # Out-Verbose $fxn "Unable to download '$Name' from '$Url_short...'"
          $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]$_)
        } catch {
          # Write-Log $_.Exception.ErrorRecord
          # Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
          $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]$_)
        }
      }
      [void]DownloadFileAsync([Uri]$urlAddress, [String]$location, [System.Diagnostics.Stopwatch]$sw) {
        $webClient = [System.Net.WebClient]::new();
        # $webClient.DownloadFileCompleted =+ [System.ComponentModel.AsyncCompletedEventHandler]::new([System.Object]$object, [System.IntPtr]$method);
        # $webClient.DownloadProgressChanged += [System.Net.DownloadProgressChangedEventHandler]::new([System.Object]$object, [System.IntPtr]$method);
        $sw.Start();
        try {
          $webClient.DownloadFileAsync($urlAddress, $location);
        } catch [System.Net.WebException], [System.IO.IOException] {
          # Write-Log $_.Exception.ErrorRecord
          # Out-Verbose $fxn "Unable to download '$Name' from '$Url_short...'"
          $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]$_)
        } catch {
          # Write-Log $_.Exception.ErrorRecord
          # Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
          $PSCmdlet.WriteError([System.Management.Automation.ErrorRecord]$_)
        }
      }
      hidden [void]ProgressChanged([System.Object]$sendr, [System.Net.DownloadProgressChangedEventArgs]$e, [System.Diagnostics.Stopwatch]$sw) {
        # Calculate download speed and output it to labelSpeed.
        $SpeedText = [string]::Format("{0} kb/s", $($e.BytesReceived / 1024d / $sw.Elapsed.TotalSeconds));
        # Show the percentage on our label.
        $Perc = $e.ProgressPercentage.ToString() + "%";
        # Update the label with how much data have been downloaded so far and the total size of the file we are currently downloading
        $totdL = [string]::Format("{0} MB / {1} MB", $($e.BytesReceived / 1048576), $($e.TotalBytesToReceive / 1048576));
        [System.console]::writeLine("$totdL $SpeedText $Perc");
      }
      hidden [void]Completed([System.Object]$sendr, [System.ComponentModel.AsyncCompletedEventArgs]$e, [System.Diagnostics.Stopwatch]$sw) {
        $sw.Reset();
        if ($e.Cancelled -eq $true) {
          [System.console]::writeLine("Download has been canceled.");
        } else {
          [System.console]::writeLine("Download completed.");
        }
      }
    }
    #endregion
    $downloadScript = [ScriptBlock]::Create({
        try {
          $filePath = Join-Path -Path $DownloadPath -ChildPath $Name
          $WebClient = [System.Net.WebClient]::new()
          $WebClient.DownloadFile($Url, $filePath)
        } catch [System.Net.WebException], [System.IO.IOException] {
          # Write-Log $_.Exception.ErrorRecord
          Out-Verbose $fxn "Unable to download '$Name' from '$Url_short...'"
          throw $_
        } catch {
          # Write-Log $_.Exception.ErrorRecord
          Out-Verbose $fxn "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
          throw $_
        }
        if ([IO.File]::Exists($filePath)) {
          return $filePath
        } else {
          return [string]::Empty
        }
      }
    )
  }

  Process {
    Write-Invocation $MyInvocation
    if ([string]::IsNullOrEmpty($Message)) { $Message = "Downloading '$Name' from '$Url_short...'" }
    try {
      if ([bool]$VerbosePreference.Equals('Continue')) {
        $Command = Invoke-RetriableCommand -ScriptBlock $downloadScript -MaxRetries $Retries -Message $Message -CancellationToken $CancellationToken -SecondsBetweenAttempts $SecondsBetweenAttempts -Verbose
      } else {
        $Command = Invoke-RetriableCommand -ScriptBlock $downloadScript -MaxRetries $Retries -Message $Message -CancellationToken $CancellationToken -SecondsBetweenAttempts $SecondsBetweenAttempts
      }
      if (!$Command.IsSuccess) {
        throw $Command.ErrorRecord
      }
    } catch {
      throw $_
    }
  }
  End {
    Out-Verbose $fxn "Completed $(if ($Command.IsSuccess) { 'Successfully' } else {'With Errors'})"
    $ErrorActionPreference = $eap;
    return $Command.Output
  }
}