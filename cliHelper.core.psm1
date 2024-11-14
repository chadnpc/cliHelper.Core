using namespace System.IO
using module Private/cliHelper.core.help
using module Private/cliHelper.core.output
using module Private/cliHelper.core.xcrypt
using module Private/cliHelper.core.PsRunner
using module Private/cliHelper.core.Interaction
Import-Module cliHelper.xconvert

# xconvert
#!/usr/bin/env pwsh
#region    Classes
# art and animations

# .SYNOPSIS
#     A console writeline helper
# .EXAMPLE
#     Write-AnimatedHost "Hello world" -f magenta
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
#   A class to convert dot ascii arts to b64string & vice versa
# .DESCRIPTION
#   Cli art created from sites like https://lachlanarthur.github.io/Braille-ASCII-Art/ can only be embeded as b64 string
#   So this class helps speed up the conversion process
# .EXAMPLE
#   $art = [cliart]::Create((Get-Item ./ascii))
#   Write-Host "$art" -f Green
class cliart {
  hidden [string]$bstr
  cliart([byte[]]$bytes) { [void][cliart]::_init_($bytes, [ref]$this) }
  cliart([string]$b64str) { [void][cliart]::_init_($b64str, [ref]$this) }
  cliart([FileInfo]$file) { [void][cliart]::_init_($file, [ref]$this) }

  static [cliart] Create([byte[]]$bytes) { return [cliart]::_init_($bytes, [ref][cliart]::new()) }
  static [cliart] Create([string]$b64str) { return [cliart]::_init_($b64str, [ref][cliart]::new()) }
  static [cliart] Create([FileInfo]$file) { return [cliart]::_init_($file, [ref][cliart]::new()) }

  static hidden [cliart] _init_([string]$s, [ref]$o) { $o.Value.bstr = $s; return $o.Value }
  static hidden [cliart] _init_([FileInfo]$file, [ref]$o) { return [cliart]::_init_([IO.File]::ReadAllBytes($file.FullName), [ref]$o) }
  static hidden [cliart] _init_([byte[]]$bytes, [ref]$o) { $o.Value.bstr = $bytes | xconvert ToBase85, FromUTF8str, ToCompressed, ToBase64str; return $o.Value }

  static [string] Print([string]$B64String) {
    return ($B64String | xconvert FromBase64str, FromCompressed, FromBase85, ToUTF8str)
  }
  [string] ToString() {
    return [cliart]::Print($this.bstr)
  }
}
class NetworkManager {
  [string] $HostName
  static [System.Net.IPAddress[]] $IPAddresses
  static [RecordBase] $DownloadOptions = [RecordBase]::New(@{
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
}

class RecordBase {
  RecordBase() {}
  [void] Add([string]$key, [System.Object]$value) {
    [ValidateNotNullOrEmpty()][string]$key = $key
    if (!$this.HasNoteProperty($key)) {
      $htab = [hashtable]::new(); $htab.Add($key, $value); $this.Add($htab)
    } else {
      Write-Warning "Config.Add() Skipped $Key. Key already exists."
    }
  }
  [void] Add([hashtable]$table) {
    [ValidateNotNullOrEmpty()][hashtable]$table = $table
    $Keys = $table.Keys | Where-Object { !$this.HasNoteProperty($_) -and ($_.GetType().FullName -eq 'System.String' -or $_.GetType().BaseType.FullName -eq 'System.ValueType') }
    foreach ($key in $Keys) {
      if ($key -notin ('File', 'Remote', 'LastWriteTime')) {
        $this | Add-Member -MemberType NoteProperty -Name $key -Value $table[$key]
      } else {
        $this.$key = $table[$key]
      }
    }
  }
  [void] Add([hashtable[]]$items) {
    foreach ($item in $items) { $this.Add($item) }
  }
  [void] Add([System.Collections.Generic.List[hashtable]]$items) {
    foreach ($item in $items) { $this.Add($item) }
  }
  [void] Set([string]$key, [System.Object]$value) {
    $htab = [hashtable]::new(); $htab.Add($key, $value)
    $this.Set($htab)
  }
  [void] Set([hashtable]$table) {
    [ValidateNotNullOrEmpty()][hashtable]$table = $table
    $Keys = $table.Keys | Where-Object { $_.GetType().FullName -eq 'System.String' -or $_.GetType().BaseType.FullName -eq 'System.ValueType' } | Sort-Object -Unique
    foreach ($key in $Keys) {
      if (!$this.psObject.Properties.Name.Contains($key)) {
        $this | Add-Member -MemberType NoteProperty -Name $key -Value $table[$key] -Force
      } else {
        $this.$key = $table[$key]
      }
    }
  }
  [void] Set([hashtable[]]$items) {
    foreach ($item in $items) { $this.Set($item) }
  }
  [void] Set([System.Collections.Specialized.OrderedDictionary]$dict) {
    $dict.Keys.Foreach({ $this.Set($_, $dict["$_"]) });
  }
  [bool] HasNoteProperty([object]$Name) {
    [ValidateNotNullOrEmpty()][string]$Name = $($Name -as 'string')
    return (($this | Get-Member -Type NoteProperty | Select-Object -ExpandProperty name) -contains "$Name")
  }
  [array] ToArray() {
    $array = @(); $props = $this | Get-Member -MemberType NoteProperty
    if ($null -eq $props) { return @() }
    $props.name | ForEach-Object { $array += @{ $_ = $this.$_ } }
    return $array
  }
  [string] ToJson() {
    return [string]($this | Select-Object -ExcludeProperty count | ConvertTo-Json -Depth 3)
  }
  [System.Collections.Specialized.OrderedDictionary] ToOrdered() {
    $dict = [System.Collections.Specialized.OrderedDictionary]::new(); $Keys = $this.PsObject.Properties.Where({ $_.Membertype -like "*Property" }).Name
    if ($Keys.Count -gt 0) {
      $Keys | ForEach-Object { [void]$dict.Add($_, $this."$_") }
    }
    return $dict
  }
  static [hashtable[]] Read([string]$FilePath) {
    $pass = $null; $cfg = $null
    try {
      [ValidateNotNullOrEmpty()][string]$FilePath = [AesGCM]::GetUnResolvedPath($FilePath)
      if (![IO.File]::Exists($FilePath)) { throw [FileNotFoundException]::new("File '$FilePath' was not found") }
      if ([string]::IsNullOrWhiteSpace([AesGCM]::caller)) { [AesGCM]::caller = [RecordBase]::caller }
      Set-Variable -Name pass -Scope Local -Visibility Private -Option Private -Value $(if ([xcrypt]::EncryptionScope.ToString() -eq "User") { Read-Host -Prompt "$([RecordBase]::caller) Paste/write a Password to decrypt configs" -AsSecureString }else { [xconvert]::ToSecurestring([AesGCM]::GetUniqueMachineId()) })
      $_ob = [xconvert]::Deserialize([xconvert]::ToDeCompressed([AesGCM]::Decrypt([base85]::Decode([IO.File]::ReadAllText($FilePath)), $pass)))
      $cfg = [hashtable[]]$_ob.Keys.ForEach({ @{ $_ = $_ob.$_ } })
    } catch {
      throw $_.Exeption
    } finally {
      Remove-Variable Pass -Force -ErrorAction SilentlyContinue
    }
    return $cfg
  }
  static [hashtable[]] EditFile([IO.FileInfo]$File) {
    $result = @(); $private:config_ob = $null; $fswatcher = $null; $process = $null;
    [ValidateScript({ if ([IO.File]::Exists($_)) { return $true } ; throw [FileNotFoundException]::new("File '$_' was not found") })][IO.FileInfo]$File = $File;
    $OutFile = [IO.FileInfo][IO.Path]::GetTempFileName()
    $UseVerbose = [bool]$((Get-Variable verbosePreference -ValueOnly) -eq "continue")
    try {
      [NetworkManager]::BlockAllOutbound()
      if ($UseVerbose) { "[+] Edit Config started .." | Write-Host -ForegroundColor Magenta }
      [RecordBase]::Read($File.FullName) | ConvertTo-Json | Out-File $OutFile.FullName -Encoding utf8BOM
      Set-Variable -Name OutFile -Value $(Rename-Item $outFile.FullName -NewName ($outFile.BaseName + '.json') -PassThru)
      $process = [System.Diagnostics.Process]::new()
      $process.StartInfo.FileName = 'nvim'
      $process.StartInfo.Arguments = $outFile.FullName
      $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Maximized
      $process.Start(); $fswatcher = [FileMonitor]::MonitorFile($outFile.FullName, [scriptblock]::Create("Stop-Process -Id $($process.Id) -Force"));
      if ($null -eq $fswatcher) { Write-Warning "Failed to start FileMonitor"; Write-Host "Waiting nvim process to exit..." $process.WaitForExit() }
      $private:config_ob = [IO.FILE]::ReadAllText($outFile.FullName) | ConvertFrom-Json
    } finally {
      [NetworkManager]::UnblockAllOutbound()
      if ($fswatcher) { $fswatcher.Dispose() }
      if ($process) {
        "[+] Neovim process {0} successfully" -f $(if (!$process.HasExited) {
            $process.Kill($true)
            "closed"
          } else {
            "exited"
          }
        ) | Write-Host -ForegroundColor Green
        $process.Close()
        $process.Dispose()
      }
      Remove-Item $outFile.FullName -Force
      if ($UseVerbose) { "[+] FileMonitor Log saved in variable: `$$([fileMonitor]::LogvariableName)" | Write-Host -ForegroundColor Magenta }
      if ($null -ne $config_ob) { $result = $config_ob.ForEach({ [xconvert]::ToHashTable($_) }) }
      if ($UseVerbose) { "[+] Edit Config completed." | Write-Host -ForegroundColor Magenta }
    }
    return $result
  }
  [void] Save() {
    $pass = $null;
    try {
      Write-Host "$([RecordBase]::caller) Save records to file: $($this.File) ..." -ForegroundColor Blue
      Set-Variable -Name pass -Scope Local -Visibility Private -Option Private -Value $(if ([xcrypt]::EncryptionScope.ToString() -eq "User") { Read-Host -Prompt "$([RecordBase]::caller) Paste/write a Password to encrypt configs" -AsSecureString } else { [xconvert]::ToSecurestring([AesGCM]::GetUniqueMachineId()) })
      $this.LastWriteTime = [datetime]::Now; [IO.File]::WriteAllText($this.File, [Base85]::Encode([AesGCM]::Encrypt([xconvert]::ToCompressed($this.ToByte()), $pass)), [System.Text.Encoding]::UTF8)
      Write-Host "$([RecordBase]::caller) Save records " -ForegroundColor Blue -NoNewline; Write-Host "Completed." -ForegroundColor Green
    } catch {
      throw $_.Exeption
    } finally {
      Remove-Variable Pass -Force -ErrorAction SilentlyContinue
    }
  }
  [void] Import([String]$FilePath) {
    Write-Host "$([RecordBase]::caller) Import records: $FilePath ..." -ForegroundColor Green
    $this.Set([RecordBase]::Read($FilePath))
    Write-Host "$([RecordBase]::caller) Import records Complete" -ForegroundColor Green
  }
  [byte[]] ToByte() {
    return [xconvert]::Serialize($this)
  }
  [string] ToString() {
    $r = $this.ToArray(); $s = ''
    $shortnr = [scriptblock]::Create({
        param([string]$str, [int]$MaxLength)
        while ($str.Length -gt $MaxLength) {
          $str = $str.Substring(0, [Math]::Floor(($str.Length * 4 / 5)))
        }
        return $str
      }
    )
    if ($r.Count -gt 1) {
      $b = $r[0]; $e = $r[-1]
      $0 = $shortnr.Invoke("{'$($b.Keys)' = '$($b.values.ToString())'}", 40)
      $1 = $shortnr.Invoke("{'$($e.Keys)' = '$($e.values.ToString())'}", 40)
      $s = "@($0 ... $1)"
    } elseif ($r.count -eq 1) {
      $0 = $shortnr.Invoke("{'$($r[0].Keys)' = '$($r[0].values.ToString())'}", 40)
      $s = "@($0)"
    } else {
      $s = '@()'
    }
    return $s
  }
}
#endregion Classes

#region    Functions
function Write-Ascii {
  # .SYNOPSIS
  # Svendsen Tech's PowerShell ASCII art module creates ASCII art characters
  # from a subset of common letters, numbers and punctuation characters.
  # You can add new characters by editing the XML (for developers).

  # MIT license.

  # Copyright (c) 2012-present, Joakim Borger Svendsen, Svendsen Tech.
  # All rights reserved.

  # .DESCRIPTION
  # This script reads characters from an XML file that's expected to have the name
  # "letters.xml", be encoded in UTF-8 and to be in the module's working directory.

  # It was written to be used in conjunction with a modified version of
  # PowerBot (http://poshcode.org/2510), a simple IRC bot framework written
  # using SmartIrc4Net; that's why it can prepend an apostrophe - because somewhere
  # along the way the leading spaces get lost before it hits the IRC channel.

  # Currently the XML only contains lowercase letters, mostly because PowerShell/
  # Windows is case-insensitive by default, which isn't an advantage here.

  # Example:
  # PS C:\> Import-Module WriteAscii
  # PS C:\> Write-Ascii "ASCII!"
  #                    _  _  _
  #   __ _  ___   ___ (_)(_)| |
  #  / _` |/ __| / __|| || || |
  # | (_| |\__ \| (__ | || ||_|
  #  \__,_||___/ \___||_||_|(_)
  # PS C:\>

  # .PARAMETER InputText
  # String(s) to convert to ASCII.
  # .PARAMETER PrependChar
  # Optional. Makes the script prepend an apostrophe.
  # .PARAMETER Compression
  # Optional. Compress to five lines when possible, even when it causes incorrect
  # alignment of the letters g, y, p and q (and "¤").
  # .PARAMETER ForegroundColor
  # Optional. Console only. Changes text foreground color.
  # .PARAMETER BackgroundColor
  # Optional. Console only. Changes text background color.
  [CmdletBinding()]
  param(
    [Parameter(
      ValueFromPipeline = $True,
      Mandatory = $True)]
    [Alias('InputText')]
    [String[]] $InputObject,
    [Switch] $PrependChar,
    [Alias('Compression')] [Switch] $Compress,
    [ValidateSet("Black", "Blue", "Cyan", "DarkBlue", "DarkCyan", "DarkGray",
      "DarkGreen", "DarkMagenta", "DarkRed", "DarkYellow", "Default", "Gray", "Green",
      "Magenta", "Red", "Rainbow", "White", "Yellow")]
    [String] $ForegroundColor = 'Default',
    [ValidateSet("Black", "Blue", "Cyan", "DarkBlue", "DarkCyan", "DarkGray",
      "DarkGreen", "DarkMagenta", "DarkRed", "DarkYellow", "Default", "Gray", "Green",
      "Magenta", "Red", "Rainbow", "White", "Yellow")]
    [String] $BackgroundColor = 'Default'
    #[int] $MaxChars = '25'
  )

  begin {

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Algorithm from hell... This was painful. I hope there's a better way.
    function Get-Ascii {

      param([String] $Text)

      $LetterArray = [Char[]] $Text.ToLower()

      #Write-Host -fore green $LetterArray

      # Find the letter with the most lines.
      $MaxLines = 0
      $LetterArray | ForEach-Object {
        if ($Letters.([String] $_).Lines -gt $MaxLines ) {
          $MaxLines = $Letters.([String] $_).Lines
        }
      }

      # Now this sure was a simple way of making sure all letter align tidily without changing a lot of code!
      if (-not $Compress) { $MaxLines = 6 }

      $LetterWidthArray = $LetterArray | ForEach-Object {
        $Letter = [String] $_
        $Letters.$Letter.Width
      }
      $LetterLinesArray = $LetterArray | ForEach-Object {
        $Letter = [String] $_
        $Letters.$Letter.Lines
      }

      #$LetterLinesArray

      $Lines = @{
        '1' = ''
        '2' = ''
        '3' = ''
        '4' = ''
        '5' = ''
        '6' = ''
      }

      #$LineLengths = @(0, 0, 0, 0, 0, 0)

      # Debug
      #Write-Host "MaxLines: $Maxlines"

      $LetterPos = 0
      foreach ($Letter in $LetterArray) {

        # We need to work with strings for indexing the hash by letter
        $Letter = [String] $Letter

        # Each ASCII letter can be from 4 to 6 lines.

        # If the letter has the maximum of 6 lines, populate hash with all lines.
        if ($LetterLinesArray[$LetterPos] -eq 6) {

          #Write-Host "Six letter letter"

          foreach ($Num in 1..6) {

            $LineFragment = [String](($Letters.$Letter.ASCII).Split("`n"))[$Num - 1]

            if ($LineFragment.Length -lt $Letters.$Letter.Width) {
              $LineFragment += ' ' * ($Letters.$Letter.Width - $LineFragment.Length)
            }

            $StringNum = [String] $Num
            $Lines.$StringNum += $LineFragment
          }
        }

        # Add padding for line 1 for letters with 5 lines and populate lines 2-6.
        ## Changed to top-adjust 5-line letters if there are 6 total.
        ## Added XML properties for letter alignment. Most are "default", which is top-aligned.
        ## Also added script logic to handle it (2012-12-29): <fixation>bottom</fixation>
        elseif ($LetterLinesArray[$LetterPos] -eq 5) {

          if ($MaxLines -lt 6 -or $Letters.$Letter.fixation -eq 'bottom') {

            $Padding = ' ' * $LetterWidthArray[$LetterPos]
            $Lines.'1' += $Padding

            foreach ($Num in 2..6) {

              $LineFragment = [String](($Letters.$Letter.ASCII).Split("`n"))[$Num - 2]

              if ($LineFragment.Length -lt $Letters.$Letter.Width) {
                $LineFragment += ' ' * ($Letters.$Letter.Width - $LineFragment.Length)
              }
              $StringNum = [String] $Num
              $Lines.$StringNum += $LineFragment
            }
          }

          else {
            $Padding = ' ' * $LetterWidthArray[$LetterPos]
            $Lines.'6' += $Padding
            foreach ($Num in 1..5) {
              $StringNum = [String] $Num
              $LineFragment = [String](($Letters.$Letter.ASCII).Split("`n"))[$Num - 1]
              if ($LineFragment.Length -lt $Letters.$Letter.Width) {
                $LineFragment += ' ' * ($Letters.$Letter.Width - $LineFragment.Length)
              }
              $Lines.$StringNum += $LineFragment
            }
          }
        } else {
          # Here we deal with letters with four lines.
          # Dynamic algorithm that places four-line letters on the bottom line if there are
          # 4 or 5 lines only in the letter with the most lines.
          # Default to putting the 4-liners at line 3-6
          $StartRange, $EndRange, $IndexSubtract = 3, 6, 3
          $Padding = ' ' * $LetterWidthArray[$LetterPos]

          # If there are 4 or 5 lines...
          if ($MaxLines -lt 6) {
            $Lines.'2' += $Padding
          } else {
            # There are 6 lines maximum, put 4-line letters in the middle.
            $Lines.'1' += $Padding
            $Lines.'6' += $Padding
            $StartRange, $EndRange, $IndexSubtract = 2, 5, 2
          }

          # There will always be at least four lines. Populate lines 2-5 or 3-6 in the hash.
          foreach ($Num in $StartRange..$EndRange) {

            $StringNum = [String] $Num

            $LineFragment = [String](($Letters.$Letter.ASCII).Split("`n"))[$Num - $IndexSubtract]

            if ($LineFragment.Length -lt $Letters.$Letter.Width) {
              $LineFragment += ' ' * ($Letters.$Letter.Width - $LineFragment.Length)
            }
            $Lines.$StringNum += $LineFragment
          }
        }
        $LetterPos++
      }

      # Return stuff
      $Lines.GetEnumerator() |
        Sort-Object -Property Name |
        Select-Object -ExpandProperty Value |
        Where-Object {
          $_ -match '\S'
        } | ForEach-Object {
          if ($PrependChar) {
            "'" + $_
          } else {
            $_
          }
        }
    }

    # Populate the $Letters hashtable with character data from the XML.
    Function Get-LetterXML {

      $LetterFile = Join-Path $PSScriptRoot 'letters.xml'
      $Xml = [xml] (Get-Content $LetterFile)

      $Xml.Chars.Char | ForEach-Object {

        $Letters.($_.Name) = New-Object PSObject -Property @{

          'Fixation' = $_.fixation
          'Lines'    = $_.lines
          'ASCII'    = $_.data
          'Width'    = $_.width
        }
      }
    }

    function Write-RainbowString {

      param([String] $Line,
        [String] $ForegroundColor = '',
        [String] $BackgroundColor = '')

      $Colors = @('Black', 'DarkBlue', 'DarkGreen', 'DarkCyan', 'DarkRed', 'DarkMagenta', 'DarkYellow',
        'Gray', 'DarkGray', 'Blue', 'Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'White')


      # $Colors[(Get-Random -Min 0 -Max 16)]

      [Char[]] $Line | ForEach-Object {

        if ($ForegroundColor -and $ForegroundColor -ieq 'rainbow') {

          if ($BackgroundColor -and $BackgroundColor -ieq 'rainbow') {
            Write-Host -ForegroundColor $Colors[(
              Get-Random -Min 0 -Max 16
            )] -BackgroundColor $Colors[(
              Get-Random -Min 0 -Max 16
            )] -NoNewline $_
          } elseif ($BackgroundColor) {
            Write-Host -ForegroundColor $Colors[(
              Get-Random -Min 0 -Max 16
            )] -BackgroundColor $BackgroundColor `
              -NoNewline $_
          } else {
            Write-Host -ForegroundColor $Colors[(
              Get-Random -Min 0 -Max 16
            )] -NoNewline $_
          }
        } else {
          # One of them has to be a rainbow, so we know the background is a rainbow here...
          if ($ForegroundColor) {
            Write-Host -ForegroundColor $ForegroundColor -BackgroundColor $Colors[(
              Get-Random -Min 0 -Max 16
            )] -NoNewline $_
          } else {
            Write-Host -BackgroundColor $Colors[(Get-Random -Min 0 -Max 16)] -NoNewline $_
          }
        }
      }
      Write-Host ''
    }

    # Get ASCII art letters/characters and data from XML. Make it persistent for the module.
    if (-not (Get-Variable -EA SilentlyContinue -Scope Script -Name Letters)) {
      $script:Letters = @{}
      Get-LetterXML
    }

    # Turn the [string[]] into a [String] the only way I could figure out how... wtf
    #$Text = ''
    #$InputObject | ForEach-Object { $Text += "$_ " }

    # Limit to 30 characters
    #$MaxChars = 30
    #if ($Text.Length -gt $MaxChars) { "Too long text. There's a maximum of $MaxChars characters."; return }

    # Replace spaces with underscores (that's what's used for spaces in the XML).
    #$Text = $Text -replace ' ', '_'

    # Define accepted characters (which are found in XML).
    #$AcceptedChars = '[^a-z0-9 _,!?./;:<>()¤{}\[\]\|\^=\$\-''+`\\"æøåâàáéèêóòôü]' # Some chars only works when sent as UTF-8 on IRC
    $LetterArray = [string[]]($Letters.GetEnumerator() | Sort-Object Name | Select-Object -ExpandProperty Name)
    $AcceptedChars = [regex] ( '(?i)[^' + ([regex]::Escape(($LetterArray -join '')) -replace '-', '\-' -replace '\]', '\]') + ' ]' )
    # Debug
    #Write-Host -fore cyan $AcceptedChars.ToString()
  }

  process {
    if ($InputObject -match $AcceptedChars) {
      "Unsupported character, using these accepted characters: " + ($LetterArray -replace '^template$' -join ', ') + "."
      return
    }

    # Filthy workaround (now worked around in the foreach creating the string).
    #if ($Text.Length -eq 1) { $Text += '_' }

    $Lines = @()

    foreach ($Text in $InputObject) {

      $ASCII = Get-Ascii ($Text -replace ' ', '_')

      if ($ForegroundColor -ne 'Default' -and $BackgroundColor -ne 'Default') {
        if ($ForegroundColor -ieq 'rainbow' -or $BackGroundColor -ieq 'rainbow') {
          $ASCII | ForEach-Object {
            Write-RainbowString -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor -Line $_
          }
        } else {
          Write-Host -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor ($ASCII -join "`n")
        }
      } elseif ($ForegroundColor -ne 'Default') {
        if ($ForegroundColor -ieq 'rainbow') {
          $ASCII | ForEach-Object {
            Write-RainbowString -ForegroundColor $ForegroundColor -Line $_
          }
        } else {
          Write-Host -ForegroundColor $ForegroundColor ($ASCII -join "`n")
        }
      } elseif ($BackgroundColor -ne 'Default') {
        if ($BackgroundColor -ieq 'rainbow') {
          $ASCII | ForEach-Object {
            Write-RainbowString -BackgroundColor $BackgroundColor -Line $_
          }
        } else {
          Write-Host -BackgroundColor $BackgroundColor ($ASCII -join "`n")
        }
      } else { $ASCII -replace '\s+$' }
    }
  }
}

#endregion Functions

# Types that will be available to users when they import the module.
$typestoExport = @(
  [ProgressUtil],
  [PsRunner],
  [cliart],
  [cli]
)
$TypeAcceleratorsClass = [PsObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
foreach ($Type in $typestoExport) {
  if ($Type.FullName -in $TypeAcceleratorsClass::Get.Keys) {
    $Message = @(
      "Unable to register type accelerator '$($Type.FullName)'"
      'Accelerator already exists.'
    ) -join ' - '

    throw [System.Management.Automation.ErrorRecord]::new(
      [System.InvalidOperationException]::new($Message),
      'TypeAcceleratorAlreadyExists',
      [System.Management.Automation.ErrorCategory]::InvalidOperation,
      $Type.FullName
    )
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

$Private = Get-ChildItem ([IO.Path]::Combine($PSScriptRoot, 'Private')) -Filter "*.ps1" -ErrorAction SilentlyContinue
$Public = Get-ChildItem ([IO.Path]::Combine($PSScriptRoot, 'Public')) -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $($Public + $Private)) {
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
  # Alias    = '*'
}
Export-ModuleMember @Param -Verbose