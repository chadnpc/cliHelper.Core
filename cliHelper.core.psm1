using namespace System
using namespace System.IO
using namespace System.Web
using namespace System.Threading
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Text.Json.Serialization
using namespace System.Runtime.InteropServices

using module Private/cliHelper.core.config
using module Private/cliHelper.core.xcrypt
using module Private/cliHelper.core.PsRunner
using module Private/cliHelper.core.WeatherClient

#Requires -RunAsAdministrator
#Requires -Modules cliHelper.xconvert
#Requires -Psedition Core

# xconvert
#!/usr/bin/env pwsh
#region    Classes
# art and animations

# .SYNOPSIS
#   A console writeline helper
# .EXAMPLE
#   Write-AnimatedHost "Hello world" -f magenta
class cli {
  static hidden [ValidateNotNull()][string]$Preffix # .EXAMPLE Try this: # [cli]::Preffix = '@:'; [void][cli]::Write('animations and stuff', [ConsoleColor]::Magenta)
  static hidden [ValidateNotNull()][scriptblock]$textValidator # ex: if $text does not match a regex throw 'erro~ ..'
  static [string] write([string]$text) {
    return [cli]::Write($text, 20, 1200)
  }
  static [string] Write([string]$text, [bool]$AddPreffix) {
    return [cli]::Write($text, 20, 1200, $AddPreffix)
  }
  static [string] Write([string]$text, [int]$Speed, [int]$Duration) {
    return [cli]::Write($text, 20, 1200, $true)
  }
  static [string] write([string]$text, [ConsoleColor]$color) {
    return [cli]::Write($text, $color, $true)
  }
  static [string] write([string]$text, [ConsoleColor]$color, [bool]$Animate) {
    return [cli]::Write($text, [cli]::Preffix, 20, 1200, $color, $Animate, $true)
  }
  static [string] write([string]$text, [int]$Speed, [int]$Duration, [bool]$AddPreffix) {
    return [cli]::Write($text, [cli]::Preffix, $Speed, $Duration, [ConsoleColor]::White, $true, $AddPreffix)
  }
  static [string] write([string]$text, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix) {
    return [cli]::Write($text, [cli]::Preffix, 20, 1200, $color, $Animate, $AddPreffix)
  }
  static [string] write([string]$text, [string]$Preffix, [System.ConsoleColor]$color) {
    return [cli]::Write($text, $Preffix, $color, $true)
  }
  static [string] write([string]$text, [string]$Preffix, [System.ConsoleColor]$color, [bool]$Animate) {
    return [cli]::Write($text, $Preffix, 20, 1200, $color, $Animate, $true)
  }
  static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [bool]$AddPreffix) {
    return [cli]::Write($text, $Preffix, $Speed, $Duration, [ConsoleColor]::White, $true, $AddPreffix)
  }
  static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix) {
    return [cli]::Write($text, $Preffix, $Speed, $Duration, $color, $Animate, $AddPreffix, [cli]::textValidator)
  }
  static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix, [scriptblock]$textValidator) {
    if ($null -ne $textValidator) {
      $textValidator.Invoke($text)
    }
    if ([string]::IsNullOrWhiteSpace($text)) {
      return $text
    }
    [int]$length = $text.Length; $delay = 0
    # Check if delay time is required:
    $delayIsRequired = if ($length -lt 50) { $false } else { $delay = $Duration - $length * $Speed; $delay -gt 0 }
    if ($AddPreffix -and ![string]::IsNullOrEmpty($Preffix)) {
      [void][cli]::Write($Preffix, [string]::Empty, 1, 100, [ConsoleColor]::Green, $false, $false);
    }
    $FgColr = [Console]::ForegroundColor
    [Console]::ForegroundColor = $color
    if ($Animate) {
      for ($i = 0; $i -lt $length; $i++) {
        [void][Console]::Write($text[$i]);
        Start-Sleep -Milliseconds $Speed;
      }
    } else {
      [void][Console]::Write($text);
    }
    if ($delayIsRequired) {
      Start-Sleep -Milliseconds $delay
    }
    [Console]::ForegroundColor = $FgColr
    return $text
  }
  static [string] ReadHost(
    [string]$Default = { throw 'Please enter what the default value will be if user just hits [Enter]' }.Invoke(),
    [string]$Prompt = { throw 'Enter a password value or accept default of' }.Invoke()
  ) {
    $Response = Read-Host -Prompt ($Prompt + " [$Default]")
    if ('' -eq $response) {
      return $Default
    } else {
      return $Response
    }
  }
}

# .SYNOPSIS
#  cliart helper.
# .DESCRIPTION
#  A class to convert dot ascii arts to b64string & vice versa
# .LINK
#  https://lachlanarthur.github.io/Braille-ASCII-Art/
# .EXAMPLE
#  $art = [cliart]::Create((Get-Item ./ascii))
# .EXAMPLE
#  $a = [cliart]"/home/alain/Documents/GitHub/clihelper_modules/cliHelper.core/Tests/cliart_test.txt/hacker"
#  $print_expression = $a.GetPrinter()
#  Now instead of hard coding the content of the art file, you can use $print_expression anywhere in your script
class cliart {
  [string]$cstr
  cliart() {}
  cliart([byte[]]$bytes) { [void][cliart]::_init_($bytes, [ref]$this) }
  cliart([string]$b64str) {
    if ([xcrypt]::IsBase64String($b64str)) {
      [void][cliart]::_init_($b64str, [ref]$this)
    } else {
      if ([IO.Path]::IsPathFullyQualified($b64str)) {
        $this.cstr = [cliart]::Create((Get-Item $b64str)).cstr
      }
    }
  }
  cliart([IO.FileInfo]$file) { [void][cliart]::_init_($file, [ref]$this) }

  static [cliart] Create([byte[]]$bytes) { return [cliart]::_init_($bytes, [ref][cliart]::new()) }
  static [cliart] Create([string]$b64str) { return [cliart]::_init_($b64str, [ref][cliart]::new()) }
  static [cliart] Create([IO.FileInfo]$file) { return [cliart]::_init_($file, [ref][cliart]::new()) }

  static hidden [cliart] _init_([string]$s, $o) { $o.Value.cstr = $s; return $o.Value }
  static hidden [cliart] _init_([IO.FileInfo]$file, $o) {
    return [cliart]::_init_([IO.File]::ReadAllBytes($file.FullName), $o)
  }
  static hidden [cliart] _init_([byte[]]$bytes, $o) {
    $o.Value.cstr = [convert]::ToBase64String($bytes) | xconvert ToCompressed; return $o.Value
  }
  static [string] Print([string]$cstr) {
    return [System.Text.Encoding]::UTF8.GetString([convert]::FromBase64String(($cstr | xconvert FromCompressed)))
  }
  [string] GetPrinter() {
    return '[cliart]::Print("{0}")' -f $this.cstr
  }
  [string] ToString() {
    return [cliart]::Print($this.cstr)
  }
}

class NetworkManager {
  [string] $HostName
  static [System.Net.IPAddress[]] $IPAddresses
  static [PsRecord] $DownloadOptions = [PsRecord]::New(@{
      ShowProgress      = $true
      ProgressBarLength = [int]([Console]::WindowWidth * 0.7)
      ProgressMessage   = [string]::Empty
      RetryTimeout      = 1000 #(milliseconds)
      Headers           = @{}
      Proxy             = $null
      Force             = $false
    }
  )
  static [string] $caller

  NetworkManager ([string]$HostName) {
    $this.HostName = $HostName
    $this::IPAddresses = [System.Net.Dns]::GetHostAddresses($HostName)
  }
  static [string] GetResponse ([string]$URL) {
    [System.Net.HttpWebRequest]$Request = [System.Net.HttpWebRequest]::Create($URL)
    $Request.Method = "GET"
    $Request.Timeout = 10000 # 10 seconds
    [System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]$Request.GetResponse()
    if ($Response.StatusCode -eq [System.Net.HttpStatusCode]::OK) {
      [System.IO.Stream]$ReceiveStream = $Response.GetResponseStream()
      [System.IO.StreamReader]$ReadStream = [System.IO.StreamReader]::new($ReceiveStream)
      [string]$Content = $ReadStream.ReadToEnd()
      $ReadStream.Close()
      $Response.Close()
      return $Content
    } else {
      throw "The request failed with status code: $($Response.StatusCode)"
    }
  }
  static [void] BlockAllOutbound() {
    $HostOs = [xcrypt]::Get_Host_Os()
    if ($HostOs -eq "Linux") {
      sudo iptables -P OUTPUT DROP
    } else {
      netsh advfirewall set allprofiles firewallpolicy blockinbound, blockoutbound
    }
  }
  static [void] UnblockAllOutbound() {
    $HostOs = [xcrypt]::Get_Host_Os()
    if ($HostOs -eq "Linux") {
      sudo iptables -P OUTPUT ACCEPT
    } else {
      netsh advfirewall set allprofiles firewallpolicy blockinbound, allowoutbound
    }
  }
  static [IO.FileInfo] DownloadFile([uri]$url) {
    # No $outFile so we create ones ourselves, and use suffix to prevent duplicaltes
    $randomSuffix = [Guid]::NewGuid().Guid.subString(15).replace('-', [string]::Join('', (0..9 | Get-Random -Count 1)))
    return [NetworkManager]::DownloadFile($url, "$(Split-Path $url.AbsolutePath -Leaf)_$randomSuffix");
  }
  static [IO.FileInfo] DownloadFile([uri]$url, [string]$outFile) {
    return [NetworkManager]::DownloadFile($url, $outFile, $false)
  }
  static [IO.FileInfo] DownloadFile([uri]$url, [string]$outFile, [bool]$Force) {
    [ValidateNotNullOrEmpty()][uri]$url = $url; [ValidateNotNull()][bool]$Force = ($Force -as [bool])
    [ValidateNotNullOrEmpty()][string]$outFile = $outFile; $stream = $null;
    $fileStream = $null; $name = Split-Path $url -Leaf;
    $request = [System.Net.HttpWebRequest]::Create($url)
    $request.UserAgent = "Mozilla/5.0"
    $response = $request.GetResponse()
    $contentLength = $response.ContentLength
    $stream = $response.GetResponseStream()
    $buffer = New-Object byte[] 1024
    $outPath = [xcrypt]::GetUnResolvedPath($outFile)
    if ([System.IO.Directory]::Exists($outFile)) {
      if (!$Force) { throw [InvalidArgumentException]::new("outFile", "Please provide valid file path, not a directory.") }
      $outPath = Join-Path -Path $outFile -ChildPath $name
    }
    $Outdir = [IO.Path]::GetDirectoryName($outPath)
    if (![System.IO.Directory]::Exists($Outdir)) { [void][System.IO.Directory]::CreateDirectory($Outdir) }
    if ([IO.File]::Exists($outPath)) {
      if (!$Force) { throw "$outFile already exists" }
      Remove-Item $outPath -Force -ErrorAction Ignore | Out-Null
    }
    $fileStream = [System.IO.FileStream]::new($outPath, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $totalBytesReceived = 0
    $totalBytesToReceive = $contentLength
    $OgForeground = (Get-Variable host).Value.UI.RawUI.ForegroundColor
    $Progress_Msg = [NetworkManager]::DownloadOptions.ProgressMessage
    if ([string]::IsNullOrWhiteSpace($Progress_Msg)) { $Progress_Msg = "[+] Downloading $name to $Outfile" }
    Write-Host $Progress_Msg -ForegroundColor Magenta
    $(Get-Variable host).Value.UI.RawUI.ForegroundColor = [ConsoleColor]::Green
    while ($totalBytesToReceive -gt 0) {
      $bytesRead = $stream.Read($buffer, 0, 1024)
      $totalBytesReceived += $bytesRead
      $totalBytesToReceive -= $bytesRead
      $fileStream.Write($buffer, 0, $bytesRead)
      if ([NetworkManager]::DownloadOptions.ShowProgress) {
        [ProgressUtil]::WriteProgressBar([int]($totalBytesReceived / $contentLength * 100), $true, [NetworkManager]::DownloadOptions.progressBarLength);
      }
    }
    $(Get-Variable host).Value.UI.RawUI.ForegroundColor = $OgForeground
    try { Invoke-Command -ScriptBlock { $stream.Close(); $fileStream.Close() } -ErrorAction SilentlyContinue } catch { $null }
    return (Get-Item $outFile)
  }
  static [void] UploadFile ([string]$SourcePath, [string]$DestinationURL) {
    Invoke-RestMethod -Uri $DestinationURL -Method Post -InFile $SourcePath
  }
  static [bool] TestConnection ([string]$HostName) {
    [ValidateNotNullOrEmpty()][string]$HostName = $HostName
    if (![bool]("System.Net.NetworkInformation.Ping" -as 'type')) { Add-Type -AssemblyName System.Net.NetworkInformation };
    $cs = $null; $cc = [NetworkManager]::caller; $re = @{ true = @{ m = "Success"; c = "Green" }; false = @{ m = "Failed"; c = "Red" } }
    Write-Host "$cc Testing Connection ... " -ForegroundColor Blue -NoNewline
    try {
      [System.Net.NetworkInformation.PingReply]$PingReply = [System.Net.NetworkInformation.Ping]::new().Send($HostName);
      $cs = $PingReply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success
    } catch [System.Net.Sockets.SocketException], [System.Net.NetworkInformation.PingException] {
      $cs = $false
    } catch {
      $cs = $false;
      Write-Error $_
    }
    $re = $re[$cs.ToString()]
    Write-Host $re.m -ForegroundColor $re.c
    return $cs
  }
  static [bool] IsIPv6AddressValid([string]$IP) {
    $IPv4Regex = '(((25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))'
    $G = '[a-f\d]{1,4}'
    $Tail = @(":",
      "(:($G)?|$IPv4Regex)",
      ":($IPv4Regex|$G(:$G)?|)",
      "(:$IPv4Regex|:$G(:$IPv4Regex|(:$G){0,2})|:)",
      "((:$G){0,2}(:$IPv4Regex|(:$G){1,2})|:)",
      "((:$G){0,3}(:$IPv4Regex|(:$G){1,2})|:)",
      "((:$G){0,4}(:$IPv4Regex|(:$G){1,2})|:)")
    [string] $IPv6RegexString = $G
    $Tail | ForEach-Object { $IPv6RegexString = "${G}:($IPv6RegexString|$_)" }
    $IPv6RegexString = ":(:$G){0,5}((:$G){1,2}|:$IPv4Regex)|$IPv6RegexString"
    $IPv6RegexString = $IPv6RegexString -replace '\(' , '(?:' # make all groups non-capturing
    [regex] $IPv6Regex = $IPv6RegexString
    if ($IP -imatch "^$IPv6Regex$") {
      return $true
    } else {
      return $false
    }
  }
  static [bool] IsMACAddressValid([string]$mac) {
    $RegEx = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})|([0-9A-Fa-f]{2}){6}$"
    if ($mac -match $RegEx) {
      return $true
    } else {
      return $false
    }
  }
  static [bool] IsSubNetMaskValid([string]$IP) {
    $RegEx = "^(254|252|248|240|224|192|128).0.0.0$|^255.(254|252|248|240|224|192|128|0).0.0$|^255.255.(254|252|248|240|224|192|128|0).0$|^255.255.255.(255|254|252|248|240|224|192|128|0)$"
    if ($IP -match $RegEx) {
      return $true
    } else {
      return $false
    }
  }
  static [bool] IsIPv4AddressValid([string]$IP) {
    $RegEx = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
    if ($IP -match $RegEx) {
      return $true
    } else {
      return $false
    }
  }
}
#endregion Classes

# Types that will be available to users when they import the module.
$typestoExport = @(
  [CredentialManager], [NetworkManager], [WeatherClient], [GeoCoordinate], [color],
  [ProgressUtil], [FileMonitor], [ShellConfig], [FileCryptr], [dotProfile], [PsRunner], [GitHub], [PsRecord],
  [xcrypt], [cliart], [AesGCM], [AesCng], [AesCtr], [Gist], [X509], [RSA], [RGB], [K3Y], [cli]
)
$TypeAcceleratorsClass = [PsObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
foreach ($Type in $typestoExport) {
  if ($Type.FullName -in $TypeAcceleratorsClass::Get.Keys) {
    $Message = @(
      "Unable to register type accelerator '$($Type.FullName)'"
      'Accelerator already exists.'
    ) -join ' - '

    [System.Management.Automation.ErrorRecord]::new(
      [System.InvalidOperationException]::new($Message),
      'TypeAcceleratorAlreadyExists',
      [System.Management.Automation.ErrorCategory]::InvalidOperation,
      $Type.FullName
    ) | Write-Warning
  }
}
# Add type accelerators for every exportable type.
foreach ($Type in $typestoExport) {
  $TypeAcceleratorsClass::Add($Type.FullName, $Type)
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
  foreach ($Type in $typestoExport) {
    $TypeAcceleratorsClass::Remove($Type.FullName)
  }
}.GetNewClosure();

$scripts = @(); $Public = Get-ChildItem "$PSScriptRoot/Public/" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += Get-ChildItem "$PSScriptRoot/Private/" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += $Public

foreach ($file in $scripts) {
  Try {
    if ([string]::IsNullOrWhiteSpace($file.fullname)) { continue }
    . "$($file.fullname)"
  } Catch {
    Write-Warning "Failed to import function $($file.BaseName): $_"
    $host.UI.WriteErrorLine($_)
  }
}

$Param = @{
  Function = $Public.BaseName
  Cmdlet   = '*'
  Alias    = '*'
  Verbose  = $false
}
Export-ModuleMember @Param