#!/usr/bin/env pwsh
using namespace System
using namespace System.IO
using namespace System.Web
using namespace System.Text
using namespace System.Threading
using namespace System.Collections
using namespace System.ComponentModel
using namespace System.Threading.workers
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Collections.Concurrent
using namespace System.Collections.Specialized
using namespace System.Text.Json.Serialization
using namespace System.Runtime.InteropServices
using namespace System.Management.Automation.Runspaces

#region    Classes
#Requires -RunAsAdministrator
#Requires -Modules cliHelper.xconvert, cliHelper.xcrypt
#Requires -Psedition Core

#region    Config_classes
class PsRecord {
  hidden [uri] $Remote # usually a gist uri
  hidden [string] $File
  hidden [datetime] $LastWriteTime = [datetime]::Now

  PsRecord() {
    $this._init_()
  }
  PsRecord([hashtable]$hashtable) {
    $this.Add(@($hashtable)); $this._init_()
  }
  PsRecord([hashtable[]]$array) {
    $this.Add($array); $this._init_()
  }
  hidden [void] _init_() {
    $this.PsObject.Methods.Add([PSScriptMethod]::new('GetCount', [ScriptBlock]::Create({ ($this | Get-Member -Type *Property).count })))
    $this.PsObject.Methods.Add([PSScriptMethod]::new('GetKeys', [ScriptBlock]::Create({ ($this | Get-Member -Type *Property).Name })))
  }
  [void] Edit() {
    $this.Set([PsRecord]::EditFile([IO.FileInfo]::new($this.File)))
    $this.Save()
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
  [void] Add([string]$key, [System.Object]$value) {
    [ValidateNotNullOrEmpty()][string]$key = $key
    if (!$this.HasNoteProperty($key)) {
      $htab = [hashtable]::new(); $htab.Add($key, $value); $this.Add($htab)
    } else {
      Write-Warning "Config.Add() Skipped $Key. Key already exists."
    }
  }
  [void] Add([List[hashtable]]$items) {
    foreach ($item in $items) { $this.Add($item) }
  }
  [void] Set([OrderedDictionary]$dict) {
    $dict.Keys.Foreach({ $this.Set($_, $dict["$_"]) });
  }
  [void] Set([hashtable]$table) {
    [ValidateNotNullOrEmpty()][hashtable]$table = $table
    $Keys = $table.Keys | Where-Object { $_.GetType().FullName -eq 'System.String' -or $_.GetType().BaseType.FullName -eq 'System.ValueType' } | Sort-Object -Unique
    foreach ($key in $Keys) {
      if (!$this.HasNoteProperty($key)) {
        $this | Add-Member -MemberType NoteProperty -Name $key -Value $table[$key] -Force
      } else {
        $this.$key = $table[$key]
      }
    }
  }
  [void] Set([hashtable[]]$items) {
    foreach ($item in $items) { $this.Set($item) }
  }
  [void] Set([string]$key, [System.Object]$value) {
    $htab = [hashtable]::new(); $htab.Add($key, $value)
    $this.Set($htab)
  }
  # work in progress
  static [hashtable[]] Read([string]$FilePath) {
    $cfg = $null
    # $pass = $null;
    # try {
    #   [ValidateNotNullOrEmpty()][string]$FilePath = [AesGCM]::GetUnResolvedPath($FilePath)
    #   if (![IO.File]::Exists($FilePath)) { throw [System.IO.FileNotFoundException]::new("File '$FilePath' was not found") }
    #   if ([string]::IsNullOrWhiteSpace([AesGCM]::caller)) { [AesGCM]::caller = [PsRecord]::caller }
    #   Set-Variable -Name pass -Scope Local -Visibility Private -Option Private -Value $(if ([xcrypt]::EncryptionScope.ToString() -eq "User") { Read-Host -Prompt "$([PsRecord]::caller) Paste/write a Password to decrypt configs" -AsSecureString }else { [AesGCM]::GetUniqueMachineId() | xconvert ToSecurestring })
    #   $_ob = [AesGCM]::Decrypt(([IO.File]::ReadAllText($FilePath) | xconvert FromBase85), $pass) | xconvert FromCompressed, FromBytes
    #   $cfg = [hashtable[]]$_ob.Keys.ForEach({ @{ $_ = $_ob.$_ } })
    # } catch {
    #   throw $_.Exeption
    # } finally {
    #   Remove-Variable Pass -Force -ErrorAction SilentlyContinue
    # }
    return $cfg
  }
  # static [hashtable[]] EditFile([IO.FileInfo]$File) {
  #   $result = @(); $private:config_ob = $null; $fswatcher = $null; $process = $null;
  #   [ValidateScript({ if ([IO.File]::Exists($_)) { return $true } ; throw [System.IO.FileNotFoundException]::new("File '$_' was not found") })][IO.FileInfo]$File = $File;
  #   $OutFile = [IO.FileInfo][IO.Path]::GetTempFileName()
  #   $UseVerbose = [bool]$((Get-Variable verbosePreference -ValueOnly) -eq "continue")
  #   try {
  #     [NetworkManager]::BlockAllOutbound()
  #     if ($UseVerbose) { "[+] Edit Config started .." | Write-Host -ForegroundColor Magenta }
  #     [PsRecord]::Read($File.FullName) | ConvertTo-Json | Out-File $OutFile.FullName -Encoding utf8BOM
  #     Set-Variable -Name OutFile -Value $(Rename-Item $outFile.FullName -NewName ($outFile.BaseName + '.json') -PassThru)
  #     $process = [System.Diagnostics.Process]::new()
  #     $process.StartInfo.FileName = 'nvim'
  #     $process.StartInfo.Arguments = $outFile.FullName
  #     $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Maximized
  #     $process.Start(); $fswatcher = [FileMonitor]::MonitorFile($outFile.FullName, [ScriptBlock]::Create("Stop-Process -Id $($process.Id) -Force"));
  #     if ($null -eq $fswatcher) { Write-Warning "Failed to start FileMonitor"; Write-Host "Waiting nvim process to exit..." $process.WaitForExit() }
  #     $private:config_ob = [IO.FILE]::ReadAllText($outFile.FullName) | ConvertFrom-Json
  #   } finally {
  #     [NetworkManager]::UnblockAllOutbound()
  #     if ($fswatcher) { $fswatcher.Dispose() }
  #     if ($process) {
  #       "[+] Neovim process {0} successfully" -f $(if (!$process.HasExited) {
  #           $process.Kill($true)
  #           "closed"
  #         } else {
  #           "exited"
  #         }
  #       ) | Write-Host -ForegroundColor Green
  #       $process.Close()
  #       $process.Dispose()
  #     }
  #     Remove-Item $outFile.FullName -Force
  #     if ($UseVerbose) { "[+] FileMonitor Log saved in variable: `$$([fileMonitor]::LogvariableName)" | Write-Host -ForegroundColor Magenta }
  #     if ($null -ne $config_ob) { $result = $config_ob.ForEach({ $_ | xconvert ToHashTable }) }
  #     if ($UseVerbose) { "[+] Edit Config completed." | Write-Host -ForegroundColor Magenta }
  #   }
  #   return $result
  # }
  # [void] Save() {
  #   $pass = $null;
  #   try {
  #     Write-Host "$([PsRecord]::caller) Save records to file: $($this.File) ..." -ForegroundColor Blue
  #     Set-Variable -Name pass -Scope Local -Visibility Private -Option Private -Value $(if ([xcrypt]::EncryptionScope.ToString() -eq "User") { Read-Host -Prompt "$([PsRecord]::caller) Paste/write a Password to encrypt configs" -AsSecureString } else { [AesGCM]::GetUniqueMachineId() | xconvert ToSecurestring })
  #     $this.LastWriteTime = [datetime]::Now; [IO.File]::WriteAllText($this.File, ([AesGCM]::Encrypt($($this.ToByte() | xconvert ToCompressed), $pass) | xconvert ToBase85), [System.Text.Encoding]::UTF8)
  #     Write-Host "$([PsRecord]::caller) Save records " -ForegroundColor Blue -NoNewline; Write-Host "Completed." -ForegroundColor Green
  #   } catch {
  #     throw $_.Exeption
  #   } finally {
  #     Remove-Variable Pass -Force -ErrorAction SilentlyContinue
  #   }
  # }
  hidden [bool] HasNoteProperty([object]$Name) {
    [ValidateNotNullOrEmpty()][string]$Name = $($Name -as 'string')
    return (($this | Get-Member -Type NoteProperty | Select-Object -ExpandProperty name) -contains "$Name")
  }
  [void] Import([String]$FilePath) {
    Write-Host "Import records: $FilePath ..." -ForegroundColor Green
    $this.Set([PsRecord]::Read($FilePath))
    Write-Host "Import records Complete" -ForegroundColor Green
  }
  [byte[]] ToByte() {
    return $this | xconvert ToBytes
  }
  [void] Import([uri]$raw_uri) {
    # try {
    #   $pass = $null;
    #   Set-Variable -Name pass -Scope Local -Visibility Private -Option Private -Value $(if ([xcrypt]::EncryptionScope.ToString() -eq "User") { Read-Host -Prompt "$([PsRecord]::caller) Paste/write a Password to decrypt configs" -AsSecureString }else { [xconvert]::ToSecurestring([AesGCM]::GetUniqueMachineId()) })
    #   $_ob = [xconvert]::Deserialize([xconvert]::ToDeCompressed([AesGCM]::Decrypt([base85]::Decode($(Invoke-WebRequest $raw_uri -Verbose:$false).Content), $pass)))
    #   $this.Set([hashtable[]]$_ob.Keys.ForEach({ @{ $_ = $_ob.$_ } }))
    # } catch {
    #   throw $_.Exeption
    # } finally {
    #   Remove-Variable Pass -Force -ErrorAction SilentlyContinue
    # }
  }
  [void] Upload() {
    if ([string]::IsNullOrWhiteSpace($this.Remote)) { throw [System.ArgumentException]::new('remote') }
    # $gisturi = 'https://gist.github.com/' + $this.Remote.Segments[2] + $this.Remote.Segments[2].replace('/', '')
    # [GitHub]::UpdateGist($gisturi, $content)
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
  [string] ToString() {
    $r = $this.ToArray(); $s = ''
    $shortnr = [ScriptBlock]::Create({
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

class RGB {
  [ValidateRange(0, 255)]
  [int]$Red
  [ValidateRange(0, 255)]
  [int]$Green
  [ValidateRange(0, 255)]
  [int]$Blue
  RGB() {}
  RGB([string]$Name) {
    $IsValid = [color].GetProperties().Name.Contains($Name)
    if (!$IsValid) { throw [System.InvalidCastException]::new("Color name '$Name' is not valid. See: [color].GetProperties().Name") }
    [RGB]$c = [color]::$Name
    $this.Red = $c.Red
    $this.Green = $c.Green
    $this.Blue = $c.Blue
  }
  RGB([int]$r, [int]$g, [int]$b) {
    $this.Red = $r
    $this.Green = $g
    $this.Blue = $b
  }
  [string] ToString() {
    return [color].GetProperties().Name.Where({ [color]::$_ -eq $this })
  }
}

class Color : System.ValueType {
  static [rgb] $Red = [rgb]::new(255, 0, 0)
  static [rgb] $DarkRed = [rgb]::new(128, 0, 0)
  static [rgb] $Green = [rgb]::new(0, 255, 0)
  static [rgb] $DarkGreen = [rgb]::new(0, 128, 0)
  static [rgb] $Blue = [rgb]::new(0, 0, 255)
  static [rgb] $DarkBlue = [rgb]::new(0, 0, 128)
  static [rgb] $White = [rgb]::new(255, 255, 255)
  static [rgb] $Black = [rgb]::new(0, 0, 0)
  static [rgb] $Yellow = [rgb]::new(255, 255, 0)
  static [rgb] $DarkGray = [rgb]::new(128, 128, 128)
  static [rgb] $Gray = [rgb]::new(192, 192, 192)
  static [rgb] $LightGray = [rgb]::new(238, 237, 240)
  static [rgb] $Cyan = [rgb]::new(0, 255, 255)
  static [rgb] $DarkCyan = [rgb]::new(0, 128, 128)
  static [rgb] $Magenta = [rgb]::new(255, 0, 255)
  static [rgb] $PSBlue = [rgb]::new(1, 36, 86)
  static [rgb] $AliceBlue = [rgb]::new(240, 248, 255)
  static [rgb] $AntiqueWhite = [rgb]::new(250, 235, 215)
  static [rgb] $AquaMarine = [rgb]::new(127, 255, 212)
  static [rgb] $Azure = [rgb]::new(240, 255, 255)
  static [rgb] $Beige = [rgb]::new(245, 245, 220)
  static [rgb] $Bisque = [rgb]::new(255, 228, 196)
  static [rgb] $BlanchedAlmond = [rgb]::new(255, 235, 205)
  static [rgb] $BlueViolet = [rgb]::new(138, 43, 226)
  static [rgb] $Brown = [rgb]::new(165, 42, 42)
  static [rgb] $Burlywood = [rgb]::new(222, 184, 135)
  static [rgb] $CadetBlue = [rgb]::new(95, 158, 160)
  static [rgb] $Chartreuse = [rgb]::new(127, 255, 0)
  static [rgb] $Chocolate = [rgb]::new(210, 105, 30)
  static [rgb] $Coral = [rgb]::new(255, 127, 80)
  static [rgb] $CornflowerBlue = [rgb]::new(100, 149, 237)
  static [rgb] $CornSilk = [rgb]::new(255, 248, 220)
  static [rgb] $Crimson = [rgb]::new(220, 20, 60)
  static [rgb] $DarkGoldenrod = [rgb]::new(184, 134, 11)
  static [rgb] $DarkKhaki = [rgb]::new(189, 183, 107)
  static [rgb] $DarkMagenta = [rgb]::new(139, 0, 139)
  static [rgb] $DarkOliveGreen = [rgb]::new(85, 107, 47)
  static [rgb] $DarkOrange = [rgb]::new(255, 140, 0)
  static [rgb] $DarkOrchid = [rgb]::new(153, 50, 204)
  static [rgb] $DarkSalmon = [rgb]::new(233, 150, 122)
  static [rgb] $DarkSeaGreen = [rgb]::new(143, 188, 143)
  static [rgb] $DarkSlateBlue = [rgb]::new(72, 61, 139)
  static [rgb] $DarkSlateGray = [rgb]::new(47, 79, 79)
  static [rgb] $DarkTurquoise = [rgb]::new(0, 206, 209)
  static [rgb] $DarkViolet = [rgb]::new(148, 0, 211)
  static [rgb] $DeepPink = [rgb]::new(255, 20, 147)
  static [rgb] $DeepSkyBlue = [rgb]::new(0, 191, 255)
  static [rgb] $DimGray = [rgb]::new(105, 105, 105)
  static [rgb] $DodgerBlue = [rgb]::new(30, 144, 255)
  static [rgb] $FireBrick = [rgb]::new(178, 34, 34)
  static [rgb] $FloralWhite = [rgb]::new(255, 250, 240)
  static [rgb] $ForestGreen = [rgb]::new(34, 139, 34)
  static [rgb] $GainsBoro = [rgb]::new(220, 220, 220)
  static [rgb] $GhostWhite = [rgb]::new(248, 248, 255)
  static [rgb] $Gold = [rgb]::new(255, 215, 0)
  static [rgb] $Goldenrod = [rgb]::new(218, 165, 32)
  static [rgb] $GreenYellow = [rgb]::new(173, 255, 47)
  static [rgb] $HoneyDew = [rgb]::new(240, 255, 240)
  static [rgb] $HotPink = [rgb]::new(255, 105, 180)
  static [rgb] $IndianRed = [rgb]::new(205, 92, 92)
  static [rgb] $Indigo = [rgb]::new(75, 0, 130)
  static [rgb] $Ivory = [rgb]::new(255, 255, 240)
  static [rgb] $Khaki = [rgb]::new(240, 230, 140)
  static [rgb] $Lavender = [rgb]::new(230, 230, 250)
  static [rgb] $LavenderBlush = [rgb]::new(255, 240, 245)
  static [rgb] $LawnGreen = [rgb]::new(124, 252, 0)
  static [rgb] $LemonChiffon = [rgb]::new(255, 250, 205)
  static [rgb] $LightBlue = [rgb]::new(173, 216, 230)
  static [rgb] $LightCoral = [rgb]::new(240, 128, 128)
  static [rgb] $LightCyan = [rgb]::new(224, 255, 255)
  static [rgb] $LightGoldenrodYellow = [rgb]::new(250, 250, 210)
  static [rgb] $LightPink = [rgb]::new(255, 182, 193)
  static [rgb] $LightSalmon = [rgb]::new(255, 160, 122)
  static [rgb] $LightSeaGreen = [rgb]::new(32, 178, 170)
  static [rgb] $LightSkyBlue = [rgb]::new(135, 206, 250)
  static [rgb] $LightSlateGray = [rgb]::new(119, 136, 153)
  static [rgb] $LightSteelBlue = [rgb]::new(176, 196, 222)
  static [rgb] $LightYellow = [rgb]::new(255, 255, 224)
  static [rgb] $LimeGreen = [rgb]::new(50, 205, 50)
  static [rgb] $Linen = [rgb]::new(250, 240, 230)
  static [rgb] $MediumAquaMarine = [rgb]::new(102, 205, 170)
  static [rgb] $MediumOrchid = [rgb]::new(186, 85, 211)
  static [rgb] $MediumPurple = [rgb]::new(147, 112, 219)
  static [rgb] $MediumSeaGreen = [rgb]::new(60, 179, 113)
  static [rgb] $MediumSlateBlue = [rgb]::new(123, 104, 238)
  static [rgb] $MediumSpringGreen = [rgb]::new(0, 250, 154)
  static [rgb] $MediumTurquoise = [rgb]::new(72, 209, 204)
  static [rgb] $MediumVioletRed = [rgb]::new(199, 21, 133)
  static [rgb] $MidnightBlue = [rgb]::new(25, 25, 112)
  static [rgb] $MintCream = [rgb]::new(245, 255, 250)
  static [rgb] $MistyRose = [rgb]::new(255, 228, 225)
  static [rgb] $Moccasin = [rgb]::new(255, 228, 181)
  static [rgb] $NavajoWhite = [rgb]::new(255, 222, 173)
  static [rgb] $OldLace = [rgb]::new(253, 245, 230)
  static [rgb] $Olive = [rgb]::new(128, 128, 0)
  static [rgb] $OliveDrab = [rgb]::new(107, 142, 35)
  static [rgb] $Orange = [rgb]::new(255, 165, 0)
  static [rgb] $OrangeRed = [rgb]::new(255, 69, 0)
  static [rgb] $Orchid = [rgb]::new(218, 112, 214)
  static [rgb] $PaleGoldenrod = [rgb]::new(238, 232, 170)
  static [rgb] $PaleGreen = [rgb]::new(152, 251, 152)
  static [rgb] $PaleTurquoise = [rgb]::new(175, 238, 238)
  static [rgb] $PaleVioletRed = [rgb]::new(219, 112, 147)
  static [rgb] $PapayaWhip = [rgb]::new(255, 239, 213)
  static [rgb] $PeachPuff = [rgb]::new(255, 218, 185)
  static [rgb] $Peru = [rgb]::new(205, 133, 63)
  static [rgb] $Pink = [rgb]::new(255, 192, 203)
  static [rgb] $Plum = [rgb]::new(221, 160, 221)
  static [rgb] $PowderBlue = [rgb]::new(176, 224, 230)
  static [rgb] $Purple = [rgb]::new(128, 0, 128)
  static [rgb] $RosyBrown = [rgb]::new(188, 143, 143)
  static [rgb] $RoyalBlue = [rgb]::new(65, 105, 225)
  static [rgb] $SaddleBrown = [rgb]::new(139, 69, 19)
  static [rgb] $Salmon = [rgb]::new(250, 128, 114)
  static [rgb] $SandyBrown = [rgb]::new(244, 164, 96)
  static [rgb] $SeaGreen = [rgb]::new(46, 139, 87)
  static [rgb] $SeaShell = [rgb]::new(255, 245, 238)
  static [rgb] $Sienna = [rgb]::new(160, 82, 45)
  static [rgb] $SkyBlue = [rgb]::new(135, 206, 235)
  static [rgb] $SlateBlue = [rgb]::new(106, 90, 205)
  static [rgb] $SlateGray = [rgb]::new(112, 128, 144)
  static [rgb] $Snow = [rgb]::new(255, 250, 250)
  static [rgb] $SpringGreen = [rgb]::new(0, 255, 127)
  static [rgb] $SteelBlue = [rgb]::new(70, 130, 180)
  static [rgb] $Tan = [rgb]::new(210, 180, 140)
  static [rgb] $Thistle = [rgb]::new(216, 191, 216)
  static [rgb] $Tomato = [rgb]::new(255, 99, 71)
  static [rgb] $Turquoise = [rgb]::new(64, 224, 208)
  static [rgb] $Violet = [rgb]::new(238, 130, 238)
  static [rgb] $Wheat = [rgb]::new(245, 222, 179)
  static [rgb] $WhiteSmoke = [rgb]::new(245, 245, 245)
  static [rgb] $YellowGreen = [rgb]::new(154, 205, 50)

  static [tuple[int, int, int]] ToHsv([rgb]$RGB) {
    return [Color]::ToHsv($RGB.Red, $RGB.Green, $RGB.Blue)
  }
  static [tuple[int, int, int]] ToHsv([int]$Red, [int]$Green, [int]$Blue) {
    $redPercent = $Red / 255.0
    $greenPercent = $Green / 255.0
    $bluePercent = $Blue / 255.0

    $max = [Math]::Max([Math]::Max($redPercent, $greenPercent), $bluePercent)
    $min = [Math]::Min([Math]::Min($redPercent, $greenPercent), $bluePercent)
    $delta = $max - $min

    $saturation = 0
    $value = 0
    $hue = 0

    if ($delta -eq 0) {
      $hue = 0
    } elseif ($max -eq $redPercent) {
      $hue = 60 * ((($greenPercent - $bluePercent) / $delta) % 6)
    } elseif ($max -eq $greenPercent) {
      $hue = 60 * ((($bluePercent - $redPercent) / $delta) + 2)
    } elseif ($max -eq $bluePercent) {
      $hue = 60 * ((($redPercent - $greenPercent) / $delta) + 4)
    }
    if ($hue -lt 0) { $hue = 360 + $hue }

    if ($max -eq 0) {
      $saturation = 0
    } else {
      $saturation = $delta / $max * 100
    }
    $value = $max * 100

    return [tuple]::Create([int]$hue, [int]$saturation, [int]$value)
  }
  static [RGB] FromHsl([int]$Hue, [int]$Saturation, [int]$Lightness) {
    $huePercent = $Hue / 360.0
    $saturationPercent = $Saturation / 100.0
    $lightnessPercent = $Lightness / 100.0
    ($r, $g, $b) = if ($saturationPercent -eq 0) {
      $lightnessPercent,
      $lightnessPercent,
      $lightnessPercent
    } else {
      $q = ($lightnessPercent -lt 0.5) ? ($lightnessPercent * (1 + $saturationPercent)) : ($lightnessPercent + $saturationPercent - ($lightnessPercent * $saturationPercent))
      $p = 2 * $lightnessPercent - $q

      [Color]::FromPQT($p, $q, ($huePercent + (1 / 3))),
      [Color]::FromPQT($p, $q, $huePercent),
      [Color]::FromPQT($p, $q, ($huePercent - (1 / 3)))
    }
    return [RGB]::new([int]($r * 255), [int]($g * 255), [int]($b * 255))
  }
  static [int] FromPQT([double]$P, [double]$Q, [double]$T) {
    if ($T -lt 0) { $T += 1 }
    if ($T -gt 1) { $T -= 1 }

    if ($T -lt (1 / 6)) { return $P + ($Q - $P) * 6 * $T }

    if ($T -lt (1 / 2)) { return $Q }
    if ($T -lt (2 / 3)) { return $P + ($Q - $P) * (2 / 3 - $T) * 6 }

    return $P
  }
  static [int] GetLightness([int]$Red, [int]$Green, [int]$Blue) {
    $redPercent = $Red / 255.0
    $greenPercent = $Green / 255.0
    $bluePercent = $Blue / 255.0
    $max = [Math]::Max([Math]::Max($redPercent, $greenPercent), $bluePercent)
    $min = [Math]::Min([Math]::Min($redPercent, $greenPercent), $bluePercent)

    return ($max + $min) / 2
  }
  static [string] GetCategory([int]$Hue, [int]$Saturation, [int]$Value) {
    $categories = @{
      "02 Red"    = @(0..20 + 350..360)
      "03 Orange" = @(21..45)
      "04 Yellow" = @(46..60)
      "05 Green"  = @(61..108)
      "06 Green2" = @(109..150)
      "07 Cyan"   = @(151..190)
      "08 Blue"   = @(191..220)
      "09 Blue2"  = @(221..240)
      "10 Purple" = @(241..280)
      "11 Pink1"  = @(281..300)
      "12 Pink"   = @(301..350)
    }

    if ($Saturation -lt 15) {
      if ($Value -lt 40) {
        return "00 Grey"
      }
      return "00 GreyZMud"
    }
    $res = @()
    foreach ($category in $categories.GetEnumerator()) {
      if ($Hue -in $category.Value) {
        $cat = $category.Key
        if ($Saturation -lt 2) {
          $cat = $cat + "ZMud"
        }
        $res += $cat
      }
    }
    return $res
  }
}

# .SYNOPSIS
#   shell config.
# .LINK
#   https://effective-shell.com
# .NOTES
#   Props reference: https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup
class ShellConfig : PsRecord {
  [string]$Title = 'Terminal'
  [Encoding]$Encoding = 'UTF8' # Default is utf-8 Encoding
  [bool]$AutoLogon #Specifies credentials for an account that is used to automatically log on to the computer.
  [bool]$BluetoothTaskbarIconEnabled #Specifies whether to enable the Bluetooth taskbar icon.
  [string]$ComputerName #Specifies the name of the computer.
  [bool]$ConvertibleSlateModePromptPreference # Configure to support prompts triggered by changes to ConvertibleSlateMode. OEMs must make sure that ConvertibleSlateMode is always accurate for their devices.
  [dotProfile]$dotProfile = $( { ConvertFrom-Json '
        {
            "path": "PathTo\\Microsoft.PowerShell_profile.ps1",
            "autoUpdate": true,
            "autoLoad": true,
            "ExecutionPolicy": "RemoteSigned",
            "CopyProfile": true
        }
    '}.Invoke())
  [bool]$DisableAutoDaylightTimeSet #Specifies whether to enable the destination computer to automatically change between daylight saving time and standard time.
  [array]$Display # Specifies display settings to apply to a destination computer.
  [string[]]$FirstLogonCommands #Specifies commands to run the first time that an end user logs on to the computer. This setting is not supported in Windows 10 in S mode.
  [string[]]$FolderLocations #Specifies the location of the user profile and program data folders.
  [string[]]$LogonCommands #Specifies commands to run when an end user logs on to the computer.
  [array]$NotificationArea #Specifies settings that are related to the system notification area at the far right of the taskbar.
  [string]$SignInMode #Specifies whether users switch to tablet mode by default after signing in.
  [string[]]$TaskbarLinks #Specifies shortcuts to display on the taskbar. You can specify up to three links.
  [string[]]$Themes #Specifies custom elements of the Windows visual style.
  [TimeZone]$TimeZone = [TimeZone]::CurrentTimeZone #Specifies the computer's time zone.
  [string[]]$VisualEffects #Specifies additional display settings.
  [string[]]$WindowsFeatures
  [PSObject]$RequiredModules = { ConvertFrom-Json '
        [
            {
                "name": "posh-git",
                "version": "1.0"
            },
            {
                "name": "oh-my-posh",
                "version": "1.0"
            },
            {
                "name": "PSReadLine",
                "version": "2.0.4"
            }
        ]
    '}.Invoke()
  [string]$OmpConfig #Path to omp.json

  ShellConfig() {}

  [xml] ToXML() {
    return $this.PsObject.Properties | Export-Clixml
  }
  [string] ToJSON() {
    return $this.PsObject.Properties | Select-Object Name, value | ConvertTo-Json
  }
  [string] ToString() {
    return [string]::Empty
  }
}
class dotProfile {
  [string]$path = [IO.Path]::Combine([Environment]::GetFolderPath('MyDocuments'), 'WindowsPowershell', 'Microsoft.PowerShell_profile.ps1')
  [Microsoft.PowerShell.ExecutionPolicy]$ExecutionPolicy
  [cliart]$Banner = [cliart]::Create("H4sIAAAAAAAAA22SQQ+CMAyFf5AHTVwiV2UHCVFMDOyMiS4kHHA4iP/edmW2EA4v27r27XsE1ZmP6u4nlvEq1IzP0qMNKvLKPfPSsirnQ61y1jVtdmvaeg/rGdYDnYMuMK/prlboU9rN3ws96AzqC+EFc8CiWZKR+fhMfZM/eUa+OTPv41sPPXFvBTfm2QWGFzOTJ3p89bw3uyaCSfCaIfWrmUMNM4fcMT/fyR6am9e4F3zfsg9zYaY6AX4zIgOtxCO+4yA0Lu48z6zN8T5tpn9koej5A1txgllgAgAA", ("Quick productive tech"))
  [bool]$CopyProfile
  [bool]$autoLoad = $true
  [bool]$autoUpdate = $true
  [bool]$IsLoaded = $false
  dotProfile() { }
  dotProfile([string]$Json) {
    $this.Import($Json)
  }
  dotProfile([System.IO.FileInfo]$JsonPath) {
    $this.Import($(Get-Content $JsonPath.FullName))
  }
  [void] Install() {
    # Copies the profile Script to all ProfilePaths
    [dotProfile]::Install($(Get-Variable -Name PROFILE -Scope global).Value)
  }
  [object] static Install([string]$Path) {
    # Installs all necessary cli stuff as configured.
    if ($null -eq [dotProfile]::config) {
      throw [System.ArgumentNullException]::new('Config')
    }
    $IsSuccess = $true; $ErrorRecord = $Result = $Output = $null
    try {
      #region    Self_Update
      if ([dotProfile]::config.dotProfile.autoUpdate) {
        # Make $profile Auto update itself to the latest version gist
        Invoke-Command -ScriptBlock $([ScriptBlock]::Create({
              While ($true) {
                Start-Sleep 3 #seconds
                #Run this script, change the text below, and save this script
                #and the PowerShell window stays open and starts running the new version without a hitch
                # "Hi"
                $lastWriteTimeOfThisScriptNow = [datetime](Get-ItemProperty -Path $PSCommandPath -Name LastWriteTime).LastWriteTime
                if ($lastWriteTimeOfThisScriptWhenItFirstStarted -ne $lastWriteTimeOfThisScriptNow) {
                  Get-LatestdotProfile
                  exit
                }
              }
            }
          )
        )
      }
      #endregion Self_Update
      if ([dotProfile]::config.dotProfile.autoLoad) {
        if (![dotProfile]::config.dotProfile.IsLoaded) {
          # Invoke-Command -ScriptBlock $Load_Profile_Functions
          $IsSuccess = $? -and $([dotProfile]::SetHostUI())
          $IsSuccess = $? -and $([dotProfile]::Set_PowerlinePrompt())
        } else {
          Write-Debug "dotProfile is already Initialized, Skipping This step ..."
        }
      } else {
        # Invoke-Command -ScriptBlock $Load_Profile_Functions
        $IsSuccess = $? -and $([dotProfile]::SetHostUI())
        $IsSuccess = $? -and $([dotProfile]::Set_PowerlinePrompt())
      }
      # show Banner # or 'Message Of The Day' ...
      if (($IsSuccess -eq $true) -and [dotProfile]::config.dotProfile.IsLoaded) {
        Write-Host ''
        Write-Console $([dotProfile]::Banner) -ForegroundColor SlateBlue -BackgroundColor Black;
        Write-Host ''
      }
    } catch {
      $IsSuccess = $false
      $ErrorRecord = [System.Management.Automation.ErrorRecord]$_
      # Write-Log -ErrorRecord $_
    } finally {
      $Result = [PSCustomObject]@{
        Output      = $Output
        IsSuccess   = $IsSuccess
        ErrorRecord = $ErrorRecord
      }
    }
    return $Result
  }
  [bool] static SetHostUI() {
    $Title = [dotProfile]::config.Title
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    [void][Security.Principal.WindowsIdentity]::GetAnonymous()
    $ob = [Security.Principal.WindowsPrincipal]::new($user)
    $UserRole = [PSCustomObject]@{
      'HasUserPriv'  = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::User)
      'HasAdminPriv' = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
      'HasSysPriv'   = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::SystemOperator)
      'IsPowerUser'  = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::PowerUser)
      'IsGuest'      = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::Guest)
    }
    $UserRole.PSObject.TypeNames.Insert(0, 'Security.User.RoleProperties')
    $b1 = [string][char]91
    $b2 = [string][char]93
    if ($UserRole.IsPowerUser) {
      $Title += $($b1 + 'E' + $b2) # IsElevated
    }
    if ($UserRole.HasSysPriv) {
      $Title += $($b1 + 'S' + $b2) # IsSYSTEM
    }
    # Admin indicator maybe not neded, since Windows11 build 22557.1
    if ($UserRole.HasAdminPriv) { $Title += ' (Admin)' }
    if ($UserRole.HasUserPriv -and !($UserRole.HasAdminPriv)) { $Title += ' (User)' }
    $h = Get-Variable -Name Host -Scope Global -ErrorAction SilentlyContinue
    if ([bool]$h) {
      $h.UI.RawUI.WindowTitle = "$Title"
      $h.UI.RawUI.ForegroundColor = "White"
      $h.PrivateData.ErrorForegroundColor = "DarkGray"
    }
    # Write-Verbose "Set Encoding"
    $c = "[System.Text.Encoding]::Get_{0}()" -f [dotProfile]::config.Encoding
    [console]::InputEncoding = [console]::OutputEncoding = [scriptblock]::Create($c).Invoke()
    #Banner was Generated using an online tool, then converted to base64 for easyUsage
    [dotProfile]::config.dotProfile.IsLoaded = $true
    return $true -and $([dotProfile]::Set_PowerlinePrompt())
  }
  [bool] static hidden Set_PowerlinePrompt() {
    # Sets Custom prompt if nothing goes wrong then shows a welcome Ascii Art
    $IsSuccess = $true
    try {
      $null = New-Item -Path function:prompt -Value $([dotProfile]::config.dotProfile.PSObject.Methods['ShowPrompt']) -Force
      $IsSuccess = $IsSuccess -and $?
    } catch {
      $IsSuccess = $false
      # Write-Log -ErrorRecord $_
    } finally {
      Set-Variable -Name dotProfileIsLoaded -Value $IsSuccess -Visibility Public -Scope Global;
    }
    return $IsSuccess
  }
  [void] Import([string]$Json) {
    $props = { ConvertFrom-Json $Json }.Invoke()
    $this.PsObject.Properties.Name | ForEach-Object {
      $val = $props[$_]
      if ($null -ne $val) {
        $this.PsObject.Properties[$_] = $val
      }
    }
    # $this.IsLoaded = $true
  }
  [string]ShowPrompt() {
    $realLASTEXITCODE = $LASTEXITCODE
    $nl = [Environment]::NewLine;
    # UTF8 Characters from https://www.w3schools.com/charsets/ref_utf_box.asp
    $dt = [string][char]8230
    $b1 = [string][char]91
    $b2 = [string][char]93
    $swiglyChar = [char]126
    $Home_Indic = $swiglyChar + [IO.Path]::DirectorySeparatorChar
    # $leadingChar = [char]9581 + [char]9472 + [char]9592 # long
    # $trailngChar = [char]9584 + [char]9472 + [char]9588 # long
    $leadingChar = [char]9581 + [char]9592;
    $trailngChar = [char]9584 + [char]9588; if ($NestedPromptLevel -ge 1) { $trailngChar += [string][char]9588 }
    $location = $shortLoc = [string]::Empty
    # Grab current loaction
    try {
      $location = "$((Get-Variable ExecutionContext -Scope local).SessionState.Path.CurrentLocation.Path)";
      $shortLoc = Invoke-PathShortener $location -TruncateChar $dt;
    } catch {
      Set-Location ..
    }
    $IsGitRepo = if ([bool]$(try { Test-Path .git -ErrorAction silentlyContinue }catch { $false })) { $true }else { $false }
    try {
      $(Get-Variable Host -Scope local).UI.Write($leadingChar)
      Write-Host -NoNewline $b1;
      Write-Host $([Environment]::UserName).ToLower() -NoNewline -ForegroundColor Magenta;
      Write-Host $([string][char]64) -NoNewline -ForegroundColor Gray;
      Write-Host $([System.Net.Dns]::GetHostName().ToLower()) -NoNewline -ForegroundColor DarkYellow;
      Write-Host -NoNewline "$b2 ";
      if ($location -eq "$env:UserProfile") {
        Write-Host $Home_Indic -NoNewline -ForegroundColor DarkCyan;
      } elseif ($location.Contains("$env:UserProfile")) {
        $location = $($location.replace("$env:UserProfile", "$swiglyChar"));
        if ($location.Length -gt 25) {
          $location = $(Invoke-PathShortener $location -TruncateChar $dt)
        }
        Write-Host $location -NoNewline -ForegroundColor DarkCyan
      } else {
        Write-Host $shortLoc -NoNewline -ForegroundColor DarkCyan
      }
      if ($IsGitRepo) {
        Write-Host $(Write-VcsStatus)
      } else {
        # No alternate display, just send a newline
        Write-Host ''
      }
      # $vs = Write-VcsStatus
      # [char[]]$vs.count
      # ' ' * $($Host.UI.RawUI.WindowSize.Width - 19) + 'Time______goes_Here'
      # $dt = [datetime]::Now; $day = $dt.ToLongDateString().split(',')[1].trim()
      # $CurrentTime = "$day, $($dt.Year) $($dt.Hour):$($dt.Minute)"
    } catch {
      <#Do this if a terminating exception happens#>
      # if ($_.Exception.WasThrownFromThrowStatement) {
      #     [System.Management.Automation.ErrorRecord]$_ | Write-Log $LogFile
      # }
      $(Get-Variable Host -Scope local).UI.WriteErrorLine("[PromptError] [$($_.FullyQualifiedErrorId)] $($_.Exception.Message) # see the Log File : `$LogFile $nl")
    } finally {
      #Do this after the try block regardless of whether an exception occurred or not#
      $LASTEXITCODE = $realLASTEXITCODE
    }
    return $trailngChar
  }
}

#endregion Config_classes

# .SYNOPSIS
#   A console writeline helper
class cli {
  static hidden [ValidateNotNull()][string]$Preffix # .EXAMPLE Try this: # [AnsiConsole]::Preffix = '@:'; [void][cli]::Write('animations and stuff', [ConsoleColor]::Magenta)
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

#region    console_art
# .SYNOPSIS
#  cliart helper.
# .DESCRIPTION
#  A class to convert dot ascii arts to b64string & vice versa
# .LINK
#  https://getcliart.vercel.app
# .EXAMPLE
#  $art = [cliart]::Create((Get-Item ./ascii))
# .EXAMPLE
#  $a = [cliart]"/home/alain/Documents/GitHub/clihelper_modules/cliHelper.core/Tests/cliart_test.txt/hacker"
#  Write-Console -Text $a -f SpringGreen
#  $print_expression = $a.GetPrinter()
#  Now instead of hard coding the content of the art file, you can use $print_expression anywhere in your script
class cliart {
  hidden [list[string]] $taglines = @()
  hidden [ValidateNotNullOrWhiteSpace()][string] $cstr
  cliart() { }
  cliart([byte[]]$bytes) { [void][cliart]::_init_($bytes, [ref]$this) }
  cliart([string]$string) { [void][cliart]::_init_($string, [string[]]@(), [ref]$this) }
  cliart([IO.FileInfo]$file) { [void][cliart]::_init_($file, [ref]$this) }

  static [cliart] Create([byte[]]$bytes) { return [cliart]::_init_($bytes, [ref][cliart]::new()) }
  static [cliart] Create([string]$string) { return [cliart]::_init_($string, [ref][cliart]::new()) }
  static [cliart] Create([IO.FileInfo]$file) { return [cliart]::_init_($file, [ref][cliart]::new()) }
  static [cliart] Create([byte[]]$bytes, [string[]]$taglines) { return [cliart]::_init_($bytes, $taglines, [ref][cliart]::new()) }
  static [cliart] Create([string]$string, [string[]]$taglines) { return [cliart]::_init_($string, $taglines, [ref][cliart]::new()) }

  static hidden [cliart] _init_([string]$s, $o) { $o.Value.cstr = $s; return $o.Value }

  static hidden [cliart] _init_([string]$s, [string[]]$taglines, $o) {
    $use_verbose = (Get-Variable VerbosePreference -Scope global -ValueOnly) -eq 'Continue'
    $i = switch ($true) {
      ([xcrypt]::IsValidUrl($s)) { Get-Item (Start-DownloadWithRetry -Uri $s -Message "download cliart" -Verbose:$use_verbose).FullName; break }
      ([xcrypt]::IsBase64String($s)) { $s; break }
      ([IO.Path]::IsPathFullyQualified($s)) { (Get-Item $s); break }
      Default {
        throw [ArgumentException]::new('Invalid input string. [cliart]::Create() requires a valid url, base64 string or path.')
      }
    }
    $o.Value.cstr = [cliart]::_init_($i, $o).cstr;
    if ([IO.File]::Exists($i)) { Remove-Item $i -Verbose:$false -Force -ea Ignore }
    if ($taglines.Count -gt 0) { $taglines.ForEach({ [void]$o.Value.taglines.Add($_) }) }
    return $o.Value
  }
  static hidden [cliart] _init_([IO.FileInfo]$file, $o) {
    return [cliart]::_init_([IO.File]::ReadAllBytes($file.FullName), @(), $o)
  }
  static hidden [cliart] _init_([byte[]]$bytes, [string[]]$taglines, $o) {
    $o.Value.cstr = [convert]::ToBase64String($bytes) | xconvert ToCompressed;
    if ($taglines.Count -gt 0) { $taglines.ForEach({ [void]$o.Value.taglines.Add($_) }) }
    return $o.Value
  }
  static [string] Print([string]$cstr) {
    if ([string]::IsNullOrWhiteSpace($cstr)) { return [string]::Empty }
    return [System.Text.Encoding]::UTF8.GetString([convert]::FromBase64String(($cstr | xconvert FromCompressed)))
  }
  hidden [string] GetPrinter() {
    return '[cliart]::Print("{0}")' -f $this.cstr
  }
  [void] Write() {
    $this.Write($true)
  }
  [void] Write([bool]$Animate) {
    $this.Write(0, $true, $Animate)
  }
  [void] Write([string]$AdditionalText) {
    $this.Write('LimeGreen', 0, $true, $AdditionalText, $true)
  }
  [void] Write([int]$SpaceBeforeTagline, [bool]$Nonewline, [bool]$Animate) {
    $this.Write('LimeGreen', $SpaceBeforeTagline, $Nonewline, [string]::Empty, $Animate)
  }
  [void] Write([string]$asciicolor, [int]$SpaceBeforeTagline, [bool]$Nonewline, [string]$AdditionalText, [bool]$Animate) {
    $this.Write($asciicolor, $SpaceBeforeTagline, $asciicolor, $Nonewline, $AdditionalText, $Animate)
  }
  [void] Write([string]$asciicolor, [int]$SpaceBeforeTagline, [string]$TaglineColor, [bool]$Nonewline, [string]$AdditionalText, [bool]$Animate) {
    $this.ToString() | Write-Console -f $asciicolor; $last_line = '{0}{1}' -f $([string][char]32 * $SpaceBeforeTagline), $this.GetTagline()
    if (![string]::IsNullOrWhiteSpace($last_line)) { $last_line | Write-Console -f $TaglineColor -NoNewLine:$Nonewline -Animate:$Animate }
    if (![string]::IsNullOrWhiteSpace($AdditionalText)) { $AdditionalText | Write-Console -f LightCyan -Animate:$Animate }
  }
  [string] GetTagline() { return $this.taglines | Get-Random }

  [string] ToString() { return [cliart]::Print($this.cstr) }
}

#endregion console_art
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
      if (!$Force) { throw [ArgumentException]::new("Please provide valid file path, not a directory.", "outFile") }
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


<#
.SYNOPSIS
  A simple progress utility class
.EXAMPLE
  for ($i = 0; $i -le 100; $i++) {
    [ProgressUtil]::WriteProgressBar($i, "doing stuff")
  }
.EXAMPLE
  [progressUtil]::WaitJob("waiting", { Start-Sleep -Seconds 3 });
.EXAMPLE
  $j = [ProgressUtil]::WaitJob("waiting", { Param($ob) Start-Sleep -Seconds 3; return $ob }, (Get-Process pwsh));
  $j | Receive-Job

  NPM(K)    PM(M)      WS(M)     CPU(s)      Id  SI ProcessName
  ------    -----      -----     ------      --  -- -----------
        0     0.00     559.55      94.22   53184 …84 pwsh
        0     0.00     253.84       6.91   55195 …23 pwsh
.EXAMPLE
  Wait-Task -ScriptBlock { Start-Sleep -Seconds 3; $input | Out-String } -InputObject (Get-Process pwsh)
.EXAMPLE
  $RequestParams = @{
    Uri    = "placeholderuri"
    Method = "Post"
    Body   = "jsonbody"
  }
  $r = [progressUtil]::WaitJob($progressmsg, { $p = $input; Invoke-RestMethod @p }, $RequestParams)
#>
class ProgressUtil {
  static hidden [string] $_block = '■';
  static hidden [string] $_back = "`b";
  static hidden [string[]] $_twirl = @(
    "◰◳◲◱",
    "◇◈◆",
    "◐◓◑◒",
    "←↖↑↗→↘↓↙",
    "┤┘┴└├┌┬┐",
    "⣾⣽⣻⢿⡿⣟⣯⣷",
    "|/-\\",
    "-\\|/",
    "|/-\\"
  );
  static hidden [int] $_twirlIndex = 0
  static hidden [string]$frames
  static [void] WriteProgressBar([int]$percent) {
    [ProgressUtil]::WriteProgressBar($percent, $true, "")
  }
  static [void] WriteProgressBar([int]$percent, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $true, $message)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $update, [int]([Console]::WindowWidth * 0.7), $message)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [string]$message, [bool]$Completed) {
    [ProgressUtil]::WriteProgressBar($percent, $update, [int]([Console]::WindowWidth * 0.7), $message, $Completed)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $update, $PBLength, $message, $false)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength, [string]$message, [bool]$Completed) {
    [ValidateNotNull()][int]$PBLength = $PBLength
    [ValidateNotNull()][int]$percent = $percent
    [ValidateNotNull()][bool]$update = $update
    [ValidateNotNull()][string]$message = $message
    [ProgressUtil]::_back = "`b" * [Console]::WindowWidth
    if ($update) { [Console]::Write([ProgressUtil]::_back) }
    Write-Console ("{0} [" -f $message) -f SlateBlue -NoNewLine
    $p = [int](($percent / 100.0) * $PBLength + 0.5)
    for ($i = 0; $i -lt $PBLength; $i++) {
      if ($i -ge $p) {
        Write-Console ' ' -NoNewLine
      } else {
        Write-Console ([ProgressUtil]::_block) -f SlateBlue -NoNewLine
      }
    }
    Write-Console ("] {0,3:##0}%" -f $percent) -f SlateBlue -NoNewLine:(!$Completed)
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [scriptblock]$sb) {
    return [ProgressUtil]::WaitJob($progressMsg, $sb, $null)
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [System.Management.Automation.Job]$Job) {
    [Console]::CursorVisible = $false;
    [ProgressUtil]::frames = [ProgressUtil]::_twirl[0]
    [int]$length = [ProgressUtil]::frames.Length;
    $originalY = [Console]::CursorTop
    while ($Job.JobStateInfo.State -notin ('Completed', 'failed')) {
      for ($i = 0; $i -lt $length; $i++) {
        [ProgressUtil]::frames.Foreach({ [Console]::Write("$progressMsg $($_[$i])") })
        [System.Threading.Thread]::Sleep(50)
        [Console]::Write(("`b" * ($length + $progressMsg.Length)))
        [Console]::CursorTop = $originalY
      }
    }
    Write-Host "`b$progressMsg ... " -NoNewline -ForegroundColor Magenta
    [System.Management.Automation.Runspaces.RemotingErrorRecord[]]$Errors = $Job.ChildJobs.Where({
        $null -ne $_.Error
      }
    ).Error;
    if ($Job.JobStateInfo.State -eq "Failed" -or $Errors.Count -gt 0) {
      $errormessages = [string]::Empty
      if ($null -ne $Errors) {
        $errormessages = $Errors.Exception.Message -join "`n"
      }
      Write-Host "Completed with errors.`n`t$errormessages" -ForegroundColor Red
    } else {
      Write-Host "Done" -ForegroundColor Green
    }
    [Console]::CursorVisible = $true;
    return $Job
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [scriptblock]$sb, [Object[]]$ArgumentList) {
    $Job = ($null -ne $ArgumentList) ? (Start-ThreadJob -ScriptBlock $sb -ArgumentList $ArgumentList ) : (Start-ThreadJob -ScriptBlock $sb)
    return [ProgressUtil]::WaitJob($progressMsg, $Job)
  }
}

class StackTracer {
  static [System.Collections.Concurrent.ConcurrentStack[string]]$stack = [System.Collections.Concurrent.ConcurrentStack[string]]::new()
  static [System.Collections.Generic.List[hashtable]]$CallLog = @()
  static [void] Push([string]$class) {
    $str = "[{0}]" -f $class
    if ([StackTracer]::Peek() -ne "$class") {
      [StackTracer]::stack.Push($str)
      $LAST_ERROR = $(Get-Variable -Name Error -ValueOnly)[0]
      [StackTracer]::CallLog.Add(@{ ($str + ' @ ' + [datetime]::Now.ToShortTimeString()) = $(if ($null -ne $LAST_ERROR) { $LAST_ERROR.ScriptStackTrace } else { [System.Environment]::StackTrace }).Split("`n").Replace("at ", "# ").Trim() })
    }
  }
  static [type] Pop() {
    $result = $null
    if ([StackTracer]::stack.TryPop([ref]$result)) {
      return $result
    } else {
      throw [System.InvalidOperationException]::new("Stack is empty!")
    }
  }
  static [string] Peek() {
    $result = $null
    if ([StackTracer]::stack.TryPeek([ref]$result)) {
      return $result
    } else {
      return [string]::Empty
    }
  }
  static [int] GetSize() {
    return [StackTracer]::stack.Count
  }
  static [bool] IsEmpty() {
    return [StackTracer]::stack.IsEmpty
  }
}

<#
.SYNOPSIS
  PsRunner : Main class of the module
.DESCRIPTION
  Provides simple multithreading implementation in powerhsell
.NOTES
  Author  : Alain Herve
  Created : <release_date>
  Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action ([PsRunner]::GetOnRemovalScript())

 .EXAMPLE
  $r = [PsRunner]::new();
  $worker1 = { $res = "worker running on thread $([Threading.Thread]::CurrentThread.ManagedThreadId)"; Start-Sleep -Seconds 5; return $res };
  $worker2 = { return (Get-Variable PsRunner_* -ValueOnly) };
  $worker3 = { $res = "worker running on thread $([Threading.Thread]::CurrentThread.ManagedThreadId)"; 10..20 | Get-Random | ForEach-Object {  Start-Sleep -Milliseconds ($_ * 100) }; return $res };
  $r.Add_BGWorker($worker1); $r.Add_BGWorker($worker2); $r.Add_BGWorker($worker3);
  $r.Run()

 .EXAMPLE
  $ps = $r.RunAsync()
  $or = $ps.Instance.EndInvoke($ps.AsyncHandle)

 .EXAMPLE
  $ps = [powershell]::Create([PsRunner]::CreateRunspace())
  $ps = $ps.AddScript({
    $(Get-Variable SyncHash -ValueOnly)["JobsCleanup"] = "hello from rs manager"
    return [PSCustomObject]@{
      Setup    = Get-Variable RunSpace_Setup -ValueOnly
      SyncHash = Get-Variable SyncHash -ValueOnly
    }
  })
 $h = $ps.BeginInvoke()
 $ps.EndInvoke($h)
#>
class PsRunner {
  hidden [int] $_MinThreads = 2
  hidden [int] $_MaxThreads = [PsRunner]::GetThreadCount()
  static hidden [string] $SyncId = { [void][PsRunner]::SetSyncHash(); return [PsRunner].SyncId }.Invoke() # Unique ID for each runner instance

  static PsRunner() {
    # set properties (Once-time)
    "PsRunner" | Update-TypeData -MemberName Id -MemberType ScriptProperty -Value { return [PsRunner]::SyncId } -SecondValue { throw [SetValueException]::new('Id is read-only') } -Force;
    "PsRunner" | Update-TypeData -MemberName MinThreads -MemberType ScriptProperty -Value { return $this._MinThreads } -SecondValue {
      param($value) if ($value -lt 2) { throw [ArgumentOutOfRangeException]::new("MinThreads must be greater than or equal to 2") };
      $this._MinThreads = $value
    } -Force;
    "PsRunner" | Update-TypeData -MemberName MaxThreads -MemberType ScriptProperty -Value { return $this._MaxThreads } -SecondValue {
      param($value) $m = [PsRunner]::GetThreadCount(); if ($value -gt $m) { throw [ArgumentOutOfRangeException]::new("MaxThreads must be less than or equal to $m") }
      $this._MaxThreads = $value
    } -Force;
    [PsRunner].PsObject.Properties.Add([PSScriptProperty]::new('Instance', {
          if (![PsRunner]::GetSyncHash()["Instance"]) { [PsRunner].SyncHash["Instance"] = [PsRunner]::Get_runspace_manager() };
          return [PsRunner].SyncHash["Instance"]
        }, {
          throw [SetValueException]::new('Instance is read-only')
        }
      )
    )
    "PsRunner" | Update-TypeData -MemberName GetOutput -MemberType ScriptMethod -Value {
      $o = [PsRunner]::GetSyncHash()["Output"]; [PsRunner].SyncHash["Output"] = [PSDataCollection[PsObject]]::new()
      [PsRunner].SyncHash["Runspaces"] = [ConcurrentDictionary[int, powershell]]::new()
      return $o
    } -Force;
  }
  [void] Add_BGWorker([ScriptBlock]$Worker) {
    $this.Add_BGWorker([PsRunner]::GetWorkerId(), $Worker, @())
  }
  [void] Add_BGWorker([int]$Id, [ScriptBlock]$Worker, [object[]]$Arguments) {
    [void][PsRunner]::Isvalid_NewRunspaceId($Id)
    $ps = [powershell]::Create([PsRunner]::CreateRunspace())
    $ps = $ps.AddScript($Worker)
    if ($Arguments.Count -gt 0) { $Arguments.ForEach({ [void]$ps.AddArgument($_) }) }
    # $ps.RunspacePool = [PsRunner].SyncHash["RunspacePool"] # https://github.com/PowerShell/PowerShell/issues/18934
    # Save each Worker in a dictionary, ie: {Int_Id, Powershell_instance_on_different_thread}
    if (![PsRunner]::GetSyncHash()["Runspaces"].TryAdd($Id, $ps)) { throw [System.InvalidOperationException]::new("worker $Id already exists.") }
    [PsRunner].SyncHash["Jobs"][$Id] = @{
      __PS   = ([ref]$ps).Value
      Status = ([ref]$ps).Value.Runspace.RunspaceStateInfo.State
      Result = $null
    }
  }
  [PsObject[]] Run() { $o = [PsRunner]::Run([PsRunner]::GetSyncHash()["Runspaces"]); [PsRunner].SyncHash["Output"] += $o; return $o }
  static [PsObject[]] Run([ConcurrentDictionary[int, powershell]]$Runspaces) {
    if (![PsRunner]::HasPendingJobs()) { return $null }
    [PsRunner].SyncHash["Runspaces"] = $Runspaces
    $Handle = [PsRunner].Instance.BeginInvoke()
    Write-Host ">>> Started background jobs" -f Green
    $i = 0
    while ($Handle.IsCompleted -eq $false) {
      Start-Sleep -Milliseconds 500
      Write-Progress -Activity "Running" -Status "In Progress" -PercentComplete $($i % 100)
      $i += 5
    }
    Write-Host "`n>>> All background jobs are complete." -f Green
    return [PsRunner].Instance.EndInvoke($Handle)
  }
  [PsObject] RunAsync() { return [PsRunner]::RunAsync([PsRunner]::GetSyncHash()["Runspaces"]) }
  static [PsObject] RunAsync([ConcurrentDictionary[int, powershell]]$Runspaces) {
    if (![PsRunner]::HasPendingJobs()) { return $null }
    [PsRunner]::GetSyncHash()["Runspaces"] = $Runspaces
    return [PSCustomObject]@{
      Instance    = [PsRunner].Instance
      AsyncHandle = [IAsyncResult][PsRunner].Instance.BeginInvoke()
    }
  }
  static [Runspace] CreateRunspace() {
    $defaultvars = @(
      [PSVariable]::new("RunSpace_Setup", [PsRunner]::GetRunSpace_Setup())
      [PSVariable]::new("SyncHash", [PsRunner]::GetSyncHash())
    )
    return [PsRunner]::CreateRunspace($defaultvars)
  }
  static [Runspace] CreateRunspace([PSVariable[]]$variables) {
    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables
    $automatic_variables = @('$', '?', '^', '_', 'args', 'ConsoleFileName', 'EnabledExperimentalFeatures', 'Error', 'Event', 'EventArgs', 'EventSubscriber', 'ExecutionContext', 'false', 'foreach', 'HOME', 'Host', 'input', 'IsCoreCLR', 'IsLinux', 'IsMacOS', 'IsWindows', 'LASTEXITCODE', 'Matches', 'MyInvocation', 'NestedPromptLevel', 'null', 'PID', 'PROFILE', 'PSBoundParameters', 'PSCmdlet', 'PSCommandPath', 'PSCulture', 'PSDebugContext', 'PSEdition', 'PSHOME', 'PSItem', 'PSScriptRoot', 'PSSenderInfo', 'PSUICulture', 'PSVersionTable', 'PWD', 'Sender', 'ShellId', 'StackTrace', 'switch', 'this', 'true')
    $_variables = [PsRunner]::GetVariables().Where({ $_.Name -notin $automatic_variables }); $r = [runspacefactory]::CreateRunspace()
    if ((Get-Variable PSVersionTable -ValueOnly).PSEdition -ne "Core") { $r.ApartmentState = "STA" }
    $r.ThreadOptions = "ReuseThread"; $r.Open()
    $variables.ForEach({ $r.SessionStateProxy.SetVariable($_.Name, $_.Value) })
    [void]$r.SessionStateProxy.Path.SetLocation((Resolve-Path ".").Path)
    $_variables.ForEach({ $r.SessionStateProxy.PSVariable.Set($_.Name, $_.Value) })
    return $r
  }
  static [RunspacePool] CreateRunspacePool([int]$minRunspaces, [int]$maxRunspaces, [initialsessionstate]$initialSessionState, [Host.PSHost]$PsHost) {
    Write-Verbose "Creating runspace pool and session states"
    #If specified, add variables and modules/snapins to session state
    $sessionstate = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    # if ($UserVariables.count -gt 0) {
    #   foreach ($Variable in $UserVariables) {
    #     $sessionstate.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $Variable.Name, $Variable.Value, $null) )
    #   }
    # }
    # if ($UserModules.count -gt 0) {
    #   foreach ($ModulePath in $UserModules) {
    #     $sessionstate.ImportPSModule($ModulePath)
    #   }
    # }
    # if ($UserSnapins.count -gt 0) {
    #   foreach ($PSSnapin in $UserSnapins) {
    #     [void]$sessionstate.ImportPSSnapIn($PSSnapin, [ref]$null)
    #   }
    # }
    # if ($UserFunctions.count -gt 0) {
    #   foreach ($FunctionDef in $UserFunctions) {
    #     $sessionstate.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $FunctionDef.Name, $FunctionDef.ScriptBlock))
    #   }
    # }
    $runspacepool = [runspacefactory]::CreateRunspacePool($minRunspaces, $maxRunspaces, $sessionstate, $PsHost)
    if ((Get-Variable PSVersionTable -ValueOnly).PSEdition -ne "Core") { $runspacepool.ApartmentState = "STA" }
    $runspacepool.Open()
    return $runspacepool
  }
  static [bool] Isvalid_NewRunspaceId([int]$RsId) {
    return [PsRunner]::Isvalid_NewRunspaceId($RsId, $true)
  }
  static [bool] Isvalid_NewRunspaceId([int]$RsId, [bool]$ThrowOnFail) {
    $v = $null -eq (Get-Runspace -Id $RsId)
    if (!$v -and $ThrowOnFail) {
      throw [System.InvalidOperationException]::new("Runspace with ID $RsId already exists.")
    }; return $v
  }
  static [PSVariable[]] GetVariables() {
    # Set Environment Variables
    # if ($EnvironmentVariablesToForward -notcontains '*') {
    #   $EnvVariables = foreach ($obj in $EnvVariables) {
    #     if ($EnvironmentVariablesToForward -contains $obj.Name) {
    #       $obj
    #     }
    #   }
    # }
    # Write-Verbose "Setting SyncId <=> (OneTime/Session)"
    return (Get-Variable).Where({ $o = $_.Options.ToString(); $o -notlike "*ReadOnly*" -and $o -notlike "*Constant*" })
  }
  static [Object[]] GetCommands() {
    # if ($FunctionsToForward -notcontains '*') {
    #   $Functions = foreach ($FuncObj in $Functions) {
    #     if ($FunctionsToForward -contains $FuncObj.Name) {
    #       $FuncObj
    #     }
    #   }
    # }
    # $res = [PsRunner].SyncHash["Commands"]; if ($res) { return $res }
    return (Get-ChildItem Function:).Where({ ![System.String]::IsNullOrWhiteSpace($_.Name) })
  }
  static [string[]] GetModuleNames() {
    # if ($ModulesToForward -notcontains '*') {
    #   $Modules = foreach ($obj in $Modules) {
    #     if ($ModulesToForward -contains $obj.Name) {
    #       $obj
    #     }
    #   }
    # }
    return (Get-Module).Name
  }
  static [ArrayList] GetRunSpace_Setup() {
    return [PsRunner]::GetRunSpace_Setup((Get-ChildItem Env:), [PsRunner]::GetModuleNames(), [PsRunner]::GetCommands());
  }
  static [ArrayList] GetRunSpace_Setup([DictionaryEntry[]]$EnvVariables, [string[]]$ModuleNames, [Object[]]$Functions) {
    [ArrayList]$RunSpace_Setup = @(); $EnvVariables = Get-ChildItem Env:\
    $SetEnvVarsPrep = foreach ($obj in $EnvVariables) {
      if ([char[]]$obj.Name -contains '(' -or [char[]]$obj.Name -contains ' ') {
        $strr = @(
          'try {'
          $(' ${env:' + $obj.Name + '} = ' + "@'`n$($obj.Value)`n'@")
          'catch {'
          " Write-Debug 'Unable to forward environment variable $($obj.Name)'"
          '}'
        )
      } else {
        $strr = @(
          'try {'
          $(' $env:' + $obj.Name + ' = ' + "@'`n$($obj.Value)`n'@")
          '} catch {'
          " Write-Debug 'Unable to forward environment variable $($obj.Name)'"
          '}'
        )
      }
      [string]::Join("`n", $strr)
    }
    [void]$RunSpace_Setup.Add([string]::Join("`n", $SetEnvVarsPrep))
    $Modules = Get-Module -Name $ModuleNames | Select-Object Name, @{ l = "Manifest"; e = { [IO.Path]::Combine($_.ModuleBase, $_.Name + ".psd1") } }
    $SetModulesPrep = foreach ($obj in $Modules) {
      $strr = @(
        '$tempfile = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName())'
        "if (![bool]('$($obj.Name)' -match '\.WinModule')) {"
        ' try {'
        "  Import-Module '$($obj.Name)' -NoClobber -ErrorAction Stop 2>`$tempfile"
        '} catch {'
        '  try {'
        "   Import-Module '$($obj.Manifest)' -NoClobber -ErrorAction Stop 2>`$tempfile"
        '  } catch {'
        "   Write-Debug 'Unable to Import-Module $($obj.Name)'"
        '  }'
        ' }'
        '}'
        'if ([IO.File]::Exists($tempfile)) {'
        ' Remove-Item $tempfile -Force'
        '}'
      )
      [string]::Join("`n", $strr)
    }
    [void]$RunSpace_Setup.Add([string]::Join("`n", $SetModulesPrep))
    $SetFunctionsPrep = foreach ($obj in $Functions) {
      $_src_txt = '@(${Function:' + $obj.Name + '}.Ast.Extent.Text)'
      $FunctionText = [scriptblock]::Create($_src_txt).InvokeReturnAsIs()
      if ($($FunctionText -split "`n").Count -gt 1) {
        if ($($FunctionText -split "`n")[0] -match "^function ") {
          if ($($FunctionText -split "`n") -match "^'@") {
            Write-Debug "Unable to forward function $($obj.Name) due to heredoc string: '@"
          } else {
            'Invoke-Expression ' + "@'`n$FunctionText`n'@"
          }
        }
      } elseif ($($FunctionText -split "`n").Count -eq 1) {
        if ($FunctionText -match "^function ") {
          'Invoke-Expression ' + "@'`n$FunctionText`n'@"
        }
      }
    }
    [void]$RunSpace_Setup.Add([string]::Join("`n", $SetFunctionsPrep))
    return $RunSpace_Setup
  }
  static [Hashtable] SetSyncHash() {
    return [PsRunner]::SetSyncHash($False)
  }
  static [Hashtable] SetSyncHash([bool]$Force) {
    if (![PsRunner].SyncHash -or $Force) {
      $Id = [string]::Empty; $sv = Get-Variable PsRunner_* -Scope Global; if ($sv.Count -gt 0) { $Id = $sv[0].Name }
      if ([string]::IsNullOrWhiteSpace($Id)) { $Id = "PsRunner_{0}" -f [Guid]::NewGuid().Guid.substring(0, 21).replace('-', [string]::Join('', (0..9 | Get-Random -Count 1))) };
      [PsRunner].PsObject.Properties.Add([PSScriptProperty]::new('SyncId', [scriptblock]::Create("return '$Id'"), { throw [SetValueException]::new('SyncId is read-only') }))
      [PsRunner].PsObject.Properties.Add([PsNoteProperty]::new('SyncHash', [Hashtable]::Synchronized(@{
              Id          = [string]::Empty
              Jobs        = [Hashtable]::Synchronized(@{})
              Runspaces   = [ConcurrentDictionary[int, powershell]]::new()
              JobsCleanup = @{}
              Output      = [PSDataCollection[PsObject]]::new()
            }
          )
        )
      );
      New-Variable -Name $Id -Value $([ref][PsRunner].SyncHash).Value -Option AllScope -Scope Global -Visibility Public -Description "PID_$(Get-Variable PID -ValueOnly)_PsRunner_variables" -Force
      [PsRunner].SyncHash["Id"] = $Id;
    }
    return [PsRunner].SyncHash
  }
  static [PowerShell] Get_runspace_manager() {
    Write-Verbose "Creating Runspace Manager (OneTime) ..."
    $i = [powershell]::Create([PsRunner]::CreateRunspace())
    $i.AddScript({
        $Runspaces = $SyncHash["Runspaces"]
        $Jobs = $SyncHash["Jobs"]
        if ($RunSpace_Setup) {
          foreach ($obj in $RunSpace_Setup) {
            if ([string]::IsNullOrWhiteSpace($obj)) { continue }
            try {
              Invoke-Expression -Command $obj
            } catch {
              throw ("Error {0} `n{1}" -f $_.Exception.Message, $_.ScriptStackTrace)
            }
          }
        }
        $Runspaces.Keys.ForEach({
            $Jobs[$_]["Handle"] = [IAsyncResult]$Jobs[$_]["__PS"].BeginInvoke()
            Write-Host "Started worker $_" -f Yellow
          }
        )
        # Monitor workers until they complete
        While ($Runspaces.ToArray().Where({ $Jobs[$_.Key]["Handle"].IsCompleted -eq $false }).count -gt 0) {
          # Write-Host "$(Get-Date) Still running..." -f Green
          # foreach ($worker in $Runspaces.ToArray()) {
          #   $Id = $worker.Key
          #   $status = $Jobs[$Id]["Status"]
          #   Write-Host "worker $Id Status: $status"
          # }
          Start-Sleep -Milliseconds 500
        }
        Write-Host "All workers are complete." -f Yellow
        $SyncHash["Results"] = @(); foreach ($i in $Runspaces.Keys) {
          $__PS = $Jobs[$i]["__PS"]
          try {
            $Jobs[$i] = @{
              Result = $__PS.EndInvoke($Jobs[$i]["Handle"])
              Status = "Completed"
            }
          } catch {
            $Jobs[$i] = @{
              Result = $_.Exception.Message
              Status = "Failed"
            }
          } finally {
            # Dispose of the PowerShell instance
            $__PS.Runspace.Close()
            $__PS.Runspace.Dispose()
            $__PS.Dispose()
          }
          # Store results
          $SyncHash["Results"] += [pscustomobject]@{
            Id     = $i
            Result = $Jobs[$i]["Result"]
            Status = $Jobs[$i]["Status"]
          }
        }
        return $SyncHash["Results"]
      }
    )
    return $i
  }
  static [hashtable] GetSyncHash() {
    return (Get-Variable -Name $([PsRunner]::SyncId) -ValueOnly -Scope Global)
  }
  static [bool] HasPendingJobs() {
    $hpj = [PsRunner]::GetSyncHash()["Jobs"].Values.Keys.Contains("__PS")
    if (!$hpj) { Write-Warning "There are no pending jobs. Please run GetOutput(); and Add_BGWorker(); then try again." }
    return $hpj
  }
  static [int] GetWorkerId() {
    $Id = 0; do {
      $Id = ((Get-Runspace).Id)[-1] + 1
    } until ([PsRunner]::Isvalid_NewRunspaceId($Id, $false))
    return $Id
  }
  static [int] GetThreadCount() {
    $_PID = Get-Variable PID -ValueOnly
    return $(if ((Get-Variable IsLinux, IsMacOs).Value -contains $true) { &ps huH p $_PID | wc --lines } else { $(Get-Process -Id $_PID).Threads.Count })
  }
}

# Types that will be available to users when they import the module.
$typestoExport = @(
  [NetworkManager], [RGB], [color],
  [ProgressUtil], [StackTracer], [ShellConfig], [dotProfile],
  [PsRunner], [PsRecord], [cli], [cliart]
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