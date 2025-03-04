#!/usr/bin/env pwsh
using namespace System
using namespace System.IO
using namespace System.Web
using namespace System.Text
using namespace System.Threading
using namespace PresentationCore
using namespace System.Collections
using namespace System.Diagnostics
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

enum HostOS {
  Windows
  Linux
  MacOS
  FreeBSD
  UNKNOWN
}

enum ErrorSeverity {
  Warning = 0
  Error = 1
  Critical = 2
  Fatal = 3
}

class InstallException : Exception {
  InstallException() {}
  InstallException([string]$message) : base($message) {}
  InstallException([string]$message, [Exception]$innerException) : base($message, $innerException) {}
}

class InstallFailedException : InstallException {
  InstallFailedException() {}
  InstallFailedException([string]$message) : base($message) {}
  InstallFailedException([string]$message, [Exception]$innerException) : base($message, $innerException) {}
}

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
class Requirement {
  [string] $Name
  [version] $Version
  [string] $Description
  [string] $InstallScript
  hidden [PSDataCollection[PsObject]]$Result

  Requirement() {}
  Requirement([array]$arr) {
    $this.Name = $arr[0]
    $this.Version = $arr.Where({ $_ -is [version] })[0]
    $this.Description = $arr.Where({ $_ -is [string] -and $_ -ne $this.Name })[0]
    $__sc = $arr.Where({ $_ -is [scriptblock] })[0]
    $this.InstallScript = ($null -ne $__sc) ? $__sc.ToString() : $arr[-1]
  }
  Requirement([string]$Name, [scriptblock]$InstallScript) {
    $this.Name = $Name
    $this.InstallScript = $InstallScript.ToString()
  }
  Requirement([string]$Name, [string]$Description, [scriptblock]$InstallScript) {
    $this.Name = $Name
    $this.Description = $Description
    $this.InstallScript = $InstallScript.ToString()
  }

  [bool] IsInstalled() {
    try {
      Get-Command $this.Name -Type Application
      return $?
    } catch [CommandNotFoundException] {
      return $false
    } catch {
      throw [InstallException]::new("Failed to check if $($this.Name) is installed", $_.Exception)
    }
  }
  [bool] Resolve() {
    return $this.Resolve($false, $false)
  }
  [bool] Resolve([switch]$Force, [switch]$What_If) {
    $is_resolved = $true; $this.Result = [PSDataCollection[PsObject]]::new()
    $v = [ProgressUtil]::data.ShowProgress
    if (!$this.IsInstalled() -or $Force.IsPresent) {
      $v ? (Write-Console "`n[Resolve requrement] $($this.Name) " -f DarkKhaki -NoNewLine) : $null
      if ([string]::IsNullOrWhiteSpace($this.Description)) {
        $v ? (Write-Console "($($this.Description)) " -f Wheat -NoNewLine) : $null
      }
      $v ? (Write-Console "$($this.Version) " -f Green) : $null
      if ($What_If.IsPresent) {
        $v ? (Write-Console "Would install: $($this.Name)" -f Yellow) : $null
      } else {
        $this.Result += $this.InstallScript | Invoke-Expression
      }
      $is_resolved = $?
    }
    return $is_resolved
  }
}


#region    ErrorManager
# .DESCRIPTION
# classes for easy error managment.
class ErrorMetadata {
  [string]$Module
  [string]$Function
  [string]$ErrorCode
  [string]$StackTrace
  [string]$ErrorMessage
  [string]$AdditionalInfo
  [ErrorSeverity]$Severity
  [string]$User = $env:USER
  hidden [bool]$IsPrinted = $false
  [datetime]$Timestamp = [DateTime]::Now

  ErrorMetadata() {}
  ErrorMetadata([hashtable]$obj) {
    $obj.Keys.ForEach({
        if ($null -ne $obj.$_) {
          $this.$_ = $obj.$_
        }
      }
    )
  }
  ErrorMetadata([bool]$IsPrinted) { $this.IsPrinted = $IsPrinted }
  ErrorMetadata([bool]$IsPrinted, [datetime]$Timestamp, [string]$ErrorMessage) {
    $this.IsPrinted = $IsPrinted
    $this.Timestamp = $Timestamp
    $this.ErrorMessage = $ErrorMessage
  }
}

class ErrorLog : PSDataCollection[ErrorRecord] {
  ErrorLog() : base() {}
  [void] Export([string]$jsonPath) {
    $this | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
  }
  [string] ToString() {
    return ($this.count -ge 0) ? ('@()') : ''
  }
}

class ExceptionType {
  [string]$Name
  [string]$BaseType
  [string]$TypeName
  [string]$Description
  [string]$Assembly
  [bool]$IsLoaded
  [bool]$IsPublic
  ExceptionType() {}
  ExceptionType([hashtable]$obj) {
    $obj.Keys.ForEach({
        if ($null -ne $obj.$_) {
          $this.$_ = $obj.$_
        }
      }
    )
  }
}

class ErrorManager {
  # A Hashstable of common used exceptions and their descriptions:
  static [PSCustomObject] $CommonExceptions = (Get-ModuleData).CommonExceptions
  ErrorManager() {}
  static [ExceptionType[]] Get_ExceptionTypes() {
    $all = @()
    [appdomain]::currentdomain.GetAssemblies().GetTypes().Where({ $_.Name -like "*Exception" -and $null -ne $_.BaseType }).ForEach({
        [string]$FullName = $_.FullName
        $RuntimeType = $($FullName -as [type])
        $all += [ExceptionType][hashtable]@{
          Name        = $_.Name
          BaseType    = $_.BaseType
          TypeName    = $FullName
          Description = [ErrorManager]::CommonExceptions."$FullName"
          Assembly    = $_.Assembly
          IsLoaded    = [bool]$RuntimeType
          IsPublic    = $RuntimeType.IsPublic
        }
      }
    )
    return $all.Where({ $null -ne $_.IsPublic -and !$_.TypeName.Contains('<') -and !$_.TypeName.Contains('+') -and !$_.TypeName.Contains('>') })
  }
}
#endregion ErrorManager

#region    Config_classes
<#
.EXAMPLE
  $object = [PsRecord]@{
    Name        = "johndoe"
    Email       = "johndoe@domain.com"
    Currenttime = { return [datetime]::Now }
  }

#>
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
    $Keys = $table.Keys | Where-Object { !$this.HasProperty($_) -and ($_.GetType().FullName -eq 'System.String' -or $_.GetType().BaseType.FullName -eq 'System.ValueType') }
    foreach ($key in $Keys) {
      if ($key -notin ('File', 'Remote', 'LastWriteTime')) {
        $nval = $table[$key]; [string]$val_type_name = ($null -ne $nval) ? $nval.GetType().Name : [string]::Empty
        if ($val_type_name -eq 'ScriptBlock') {
          $this.PsObject.Properties.Add([PsScriptProperty]::new($key, $nval, [scriptblock]::Create("throw [SetValueException]::new('$key is read-only')")))
        } else {
          $this | Add-Member -MemberType NoteProperty -Name $key -Value $nval
        }
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
    if (!$this.HasProperty($key)) {
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
      $nval = $table[$key]; [string]$val_type_name = ($null -ne $nval) ? $nval.GetType().Name : [string]::Empty
      if ($val_type_name -eq 'ScriptBlock') {
        $this.PsObject.Properties.Add([PsScriptProperty]::new($key, $nval, [scriptblock]::Create("throw [SetValueException]::new('$key is read-only')") ))
      } else {
        $this | Add-Member -MemberType NoteProperty -Name $key -Value $nval -Force
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
  [bool] HasProperty([object]$Name) {
    [ValidateNotNullOrEmpty()][string]$Name = $($Name -as 'string')
    return $this.PsObject.Properties.Name -contains "$Name"
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
  [tuple[int, int, int]] ToHsv() {
    return $this.ToHsv($this.Red, $this.Green, $this.Blue)
  }
  [tuple[int, int, int]] ToHsv([rgb]$RGB) {
    return $this.ToHsv($RGB.Red, $RGB.Green, $RGB.Blue)
  }
  [tuple[int, int, int]] ToHsv([int]$Red, [int]$Green, [int]$Blue) {
    $null = [RGB]::new($Red, $Green, $Blue) # for validation
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
  [RGB] FromHsl([int]$Hue, [int]$Saturation, [int]$Lightness) {
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
  [int] GetLightness([int]$Red, [int]$Green, [int]$Blue) {
    $redPercent = $Red / 255.0
    $greenPercent = $Green / 255.0
    $bluePercent = $Blue / 255.0
    $max = [Math]::Max([Math]::Max($redPercent, $greenPercent), $bluePercent)
    $min = [Math]::Min([Math]::Min($redPercent, $greenPercent), $bluePercent)

    return ($max + $min) / 2
  }
  [string] GetCategory([int]$Hue, [int]$Saturation, [int]$Value) {
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
  [string] ToString() {
    return [color].GetProperties().Name.Where({ [color]::$_ -eq $this })
  }
}

class Color : Object {
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
  Color([string]$Name) {
    if ($null -eq [Color]::$Name) {
      throw [System.Management.Automation.ValidationMetadataException]::new("Please provide a valid color name. see [ConsoleWriter]::Colors for a list of valid colors")
    }
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
  [string]$path = [IO.Path]::Combine([Environment]::GetFolderPath('MyDocuments'), 'WindowsPowershell', 'Microsoft.PowerShell_profile.ps1')
  [bool]$AutoUpdate = $true
  [bool]$AutoLoad = $true
  [Microsoft.PowerShell.ExecutionPolicy]$ExecutionPolicy = "RemoteSigned"
  [bool]$CopyProfile = $true
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
  [InstallRequirements]$RequiredModules = @(
    ("pipenv", "Python virtualenv management tool", { Install-PipEnv } ),
    ("oh-my-posh", "A cross platform tool to render your prompt.", { Install-OMP } ),
    ("PSReadLine", "Provides gread command line editing in the PowerShell console host", { Install-Module PSReadLine } ),
    ("posh-git", "Provides prompt with Git status summary information and tab completion for Git commands, parameters, remotes and branch names.", { Install-Module posh-git } ),
    ("PowerType", "A module providing recommendations for common tools. For more information : https://github.com/AnderssonPeter/PowerType", { Install-Module PowerType } ),
    ("PSFzf", "A wrapper module around Fzf (https://github.com/junegunn/fzf).", { Install-Module PSFzf } ),
    ("Terminal-Icons", "A module to add file icons to terminal based on file extensions", { Install-Module Terminal-Icons } )
  )
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
  #.LINK
  # https://pastebin.com/raw/rdqSxHT8
  # usage: $Banner.Write(19, $false, $true)
  static [cliart]$Banner = [cliart]::Create("H4sIAAAAAAAAA61S0QrCMAz8IF8E+wdOmBQcE22lb0Mn1FUtgvj70s7ZtOvaID4cpDlyl9Ar6odUupTqfhlDnH1ueMd6mHkMP+WR00jusNosn5TLyoKpirKuh+vNXN21lA+APex8hvd6f/V4zSnRzboH3xLdfMAbonlNND85PgY7g+ShfpTfg/qA8zAzcMf4DYXJ7Pd/y3RexE4qUfSAM2g+ph/UAuyT87BYjPVGHkeTWXZ1ufWzU1F2a/GZzfBY/XCfSQ8AlryhtpmF/wthshDmN5JpNP+LfsIjxPQNb9ytVCVoBQAA", ("Build. Ship. Repeat."))
  static [ShellConfig]$config = @{}

  dotProfile() { }
  dotProfile([string]$Json) {
    $this.Import($Json)
  }
  dotProfile([System.IO.FileInfo]$JsonPath) {
    $this.Import((Get-Content $JsonPath.FullName))
  }
  [void] Install() {
    # Copies the profile Script to all ProfilePaths
    [dotProfile]::Install($(Get-Variable -Name PROFILE -Scope global).Value)
  }
  static [object] Install([string]$Path) {
    # Installs all necessary cli stuff as configured.
    if ($null -eq [dotProfile]::config) {
      throw [System.ArgumentNullException]::new('Config')
    }
    $IsSuccess = $true; $ErrorRecord = $Result = $Output = $null
    try {
      #region    Self_Update
      if ([dotProfile]::config.AutoUpdate) {
        # Make $profile Auto update itself to the latest version gist
        Invoke-Command -ScriptBlock {
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
      }
      #endregion Self_Update
      if ([dotProfile]::config.AutoLoad) {
        if (![dotProfile]::config.IsLoaded) {
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
      if (($IsSuccess -eq $true) -and [dotProfile]::config.IsLoaded) {
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
  static [bool] SetHostUI() {
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
    [dotProfile]::config.IsLoaded = $true
    return $true -and $([dotProfile]::Set_PowerlinePrompt())
  }
  [bool] static hidden Set_PowerlinePrompt() {
    # Sets Custom prompt if nothing goes wrong then shows a welcome Ascii Art
    $IsSuccess = $true
    try {
      $null = New-Item -Path function:prompt -Value $([dotProfile]::config.PSObject.Methods['ShowPrompt']) -Force
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
  [string] ShowPrompt() {
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
      $shortLoc = Get-ShortPath $location -TruncateChar $dt;
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
          $location = $(Get-ShortPath $location -TruncateChar $dt)
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

Class InstallRequirements {
  [Requirement[]] $list = @()
  [bool] $resolved = $false
  [string] $jsonPath = [IO.Path]::Combine($(Resolve-Path .).Path, 'requirements.json')

  InstallRequirements() {}
  InstallRequirements([array]$list) { $this.list = $list }
  InstallRequirements([List[array]]$list) { $this.list = $list.ToArray() }
  InstallRequirements([Hashtable]$Map) { $Map.Keys | ForEach-Object { $Map[$_] ? ($this.$_ = $Map[$_]) : $null } }
  InstallRequirements([Requirement]$req) { $this.list += $req }
  InstallRequirements([Requirement[]]$list) { $this.list += $list }

  [void] Resolve() {
    $this.Resolve($false, $false)
  }
  [void] Resolve([switch]$Force, [switch]$What_If) {
    $res = $true; $this.list.ForEach({ $res = $res -and $_.Resolve($Force, $What_If) })
    $this.resolved = $res
  }
  [void] Import() {
    $this.Import($this.JsonPath, $false)
  }
  [void] Import([switch]$throwOnFail) {
    $this.Import($this.JsonPath, $throwOnFail)
  }
  [void] Import([string]$JsonPath, [switch]$throwOnFail) {
    if ([IO.File]::Exists($JsonPath)) { $this.list = Get-Content $JsonPath | ConvertFrom-Json }; return
    if ($throwOnFail) {
      throw [FileNotFoundException]::new("Requirement json file not found: $JsonPath")
    }
  }
  [void] Export() {
    $this.Export($this.JsonPath)
  }
  [void] Export([string]$JsonPath) {
    $this.list | ConvertTo-Json -Depth 1 -Verbose:$false | Out-File $JsonPath
  }
  [string] ToString() {
    return $this | ConvertTo-Json
  }
}

# .SYNOPSIS
#   A console writeline helper
class cli {
  static [clistyle] $style = @{}
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
      ($s | xcrypt IsValidUrl) { Get-Item (Start-DownloadWithRetry -Uri $s -Message "download cliart" -Verbose:$use_verbose).FullName; break }
      ($s | xcrypt IsBase64String) { $s; break }
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
  [void] Replace([string]$oldValue, [string]$newValue) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($this.ToString().replace($oldValue, $newValue))
    $this.cstr = [convert]::ToBase64String($bytes) | xconvert ToCompressed;
  }
  [string] GetTagline() { return $this.taglines | Get-Random }

  [string] ToString() { return [cliart]::Print($this.cstr) }
}

#endregion console_art

# .SYNOPSIS
#     A PowerShell class to install and uninstall fonts on windows.
# .EXAMPLE
#     if (!(Get-Variable fontman_class_f1b973119b9e -ValueOnly -Scope global -ErrorAction Ignore)) { Set-Variable -Name fontman_class_f1b973119b9e -Scope global -Option ReadOnly -Value $([scriptblock]::Create("$(Invoke-RestMethod -Method Get https://gist.github.com/alainQtec/7d5465b60bf54b7590919e8707cc297a/raw/FontMan.ps1)")) }; . $(Get-Variable fontman_class_f1b973119b9e -ValueOnly -Scope global)
#     $fontMan = New-Object -TypeName FontMan
#     $fontMan::GetInstalledFonts()

class FontMan {
  static [string[]] $FontFolders = [FontMan]::Get_font_folders()
  static [hashtable] $FontFileTypes = @{
    ".fon" = ""
    ".fnt" = ""
    ".ttc" = " (TrueType)"
    ".ttf" = " (TrueType)"
    ".otf" = " (OpenType)"
  }
  static [string] $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
  FontMan() {
    [FontMan]::init()
  }
  static [int] InstallFont([string]$filePath) {
    return [FontMan]::InstallFont([IO.FileInfo]::new("$([FontMan]::GetUnResolvedPath($filePath))"));
  }
  static [int] InstallFont([System.IO.FileInfo]$fontFile) {
    $filePath = $fontFile.FullName; if (![IO.Path]::Exists($filePath)) {
      throw [System.IO.FileNotFoundException]::new("File Not found!", "$filePath")
    }
    $v = [ProgressUtil]::data.ShowProgress
    try {
      [string]$filePath = (Resolve-Path $filePath).path
      [string]$fileDir = Split-Path $filePath
      [string]$fileName = Split-Path $filePath -Leaf
      [string]$fileExt = (Get-Item $filePath).extension
      [string]$fileBaseName = $fileName -replace ($fileExt , "")

      $shell = New-Object -com shell.application
      $myFolder = $shell.Namespace($fileDir)
      $fileobj = $myFolder.Items().Item($fileName)
      $fontName = $myFolder.GetDetailsOf($fileobj, 21)
      if ([string]::IsNullOrWhiteSpace($fontName)) {
        $fontName = [FontMan]::GetFontName($fontFile)
      }
      if ([string]::IsNullOrWhiteSpace($fontName)) {
        $fontName = $fileBaseName
      }
      if ([IO.File]::Exists([IO.Path]::Combine($env:windir, 'Fonts', $fontFile.Name))) {
        $v ? (Write-Console "Font '$fontName' already exists!" -f Wheat) : $null
      }
      $v ? (Write-Console "Copying font: $fontName" -f DarkKhaki) : $null
      Copy-Item $filePath -Destination ([FontMan]::FontFolders[0]) -Force
      if (!(Get-ItemProperty -Name $fontName -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue)) {
        $v ? (Write-Console "Registering font: $fontName" -f DarkKhaki) : $null
        New-ItemProperty -Name $fontName -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -PropertyType string -Value $fontFile.Name -Force -ErrorAction SilentlyContinue | Out-Null
      } else {
        $v ? (Write-Console "Font already registered: $fontName" -f Wheat) : $null
      }
      [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
      $retVal = [FontMan].FontRes32::AddFont([IO.Path]::Combine([FontMan]::FontFolders[0], $fileName))
      if ($retVal -eq 0) {
        $v ? (Write-Console "Font `'$($filePath)`' installation failed" -f Red) : $null
        [console]::WriteLine()
        return 1
      } else {
        $v ? (Write-Console "Font `'$($filePath)`' installed successfully" -f Green) : $null
        [console]::WriteLine()
        Set-ItemProperty -Path "$([FontMan]::fontRegistryPath)" -Name "$($fontName)$([FontMan]::FontFileTypes.item($fileExt))" -Value "$($fileName)" -type STRING
        return 0
      }
    } catch {
      $v ? (Write-Console "An error occured installing `'$($filePath)`'" -f Red) : $null
      [console]::WriteLine()
      $v ? (Write-Console "$($error[0].ToString())" -f Red) : $null
      [console]::WriteLine()
      $error.clear()
      return 1
    }
  }
  static [int] RemoveFont([string]$filePath) {
    return [FontMan]::RemoveFont([IO.FileInfo]::new("$([FontMan]::GetUnResolvedPath($filePath))"));
  }
  static [int] RemoveFont([System.IO.FileInfo]$fontFile) {
    $filePath = $fontFile.FullName; if (![IO.Path]::Exists($filePath)) {
      throw [System.IO.FileNotFoundException]::new("File Not found!", "$filePath")
    }
    $v = [ProgressUtil]::data.ShowProgress
    $fontFinalPath = [IO.Path]::Combine([FontMan]::FontFolders[0], $filePath)
    try {
      $retVal = [FontMan].FontRes32::RemoveFont($fontFinalPath)
      $fontName = [FontMan]::GetFontName($fontFile)
      if ($retVal -eq 0) {
        $v ? (Write-Console "Font `'$filePath`' removal failed" -f Red) : $null
        [console]::WriteLine()
        return 1
      } else {
        # Get Registry StringName From Value :
        [string]$keyPath = [FontMan]::fontRegistryPath;
        $fontRegistryvaluename = Invoke-Command -ScriptBlock {
          $pattern = [Regex]::Escape($fullpath)
          foreach ($property in (Get-ItemProperty $keyPath).PsObject.Properties) {
            ## Skip the property if it was one PowerShell added
            if (($property.Name -eq "PSPath") -or ($property.Name -eq "PSChildName")) {
              continue
            }
            ## Search the text of the property
            $propertyText = "$($property.Value)"
            if ($propertyText -match $pattern) {
              "$($property.Name)"
            }
          }
        }
        $v ? (Write-Console "Font: $fontRegistryvaluename" -f DarkKhaki) : $null
        if ($fontRegistryvaluename -ne "") {
          Remove-ItemProperty -Path ([FontMan]::fontRegistryPath) -Name $fontRegistryvaluename
        } else {
          $v ? (Write-Console "Font $fontName not registered!" -f Red) : $null
        }

        if ([IO.Path]::Exists($fontFinalPath)) {
          $v ? (Write-Console "Removing font: $fontFile" -f DarkKhaki) : $null
          Remove-Item $fontFinalPath -Force
        } else {
          $v ? (Write-Console "Font does not exist: $fontFile" -f Wheat) : $null
        }

        if ($null -ne $error[0]) {
          $v ? (Write-Console "An error occured removing $`'$filePath`'" -f Red) : $null
          [console]::WriteLine()
          $v ? (Write-Console "$($error[0].ToString())" -f Red) : $null
          [console]::WriteLine()
          $error.clear()
        } else {
          $v ? (Write-Console "Font `'$filePath`' removed successfully" -f Green) : $null
          [console]::WriteLine()
        }
        return 0
      }
    } catch {
      $v ? (Write-Console "An error occured removing `'$filePath`'" -f Red) : $null
      [console]::WriteLine()
      $v ? (Write-Console "$($error[0].ToString())" -f Red) : $null
      [console]::WriteLine()
      $error.clear()
      return 1
    }
  }
  static [string] GetFontName([string]$fontFile) {
    return [FontMan]::GetFontName([System.IO.FileInfo]::new("$([FontMan]::GetUnResolvedPath($fontFile))"))
  }
  static [string] GetFontName([System.IO.FileInfo]$fontFile) {
    Add-Type -AssemblyName PresentationCore
    $fp = $fontFile.FullName; $gt = New-Object Windows.Media.GlyphTypeface("$fp")
    $family = $gt.Win32FamilyNames['en-us']; $ext = $fontFile.Extension
    if ($null -eq $family) { $family = $gt.Win32FamilyNames.Values.Item(0) }
    $face = $gt.Win32FaceNames['en-us']
    if ($null -eq $face) { $face = $gt.Win32FaceNames.Values.Item(0) }
    $fontName = ("$family $face").Trim()
    $fontName = $fontName + [FontMan]::FontFileTypes.$ext
    return $fontName
  }
  static [string[]] GetInstalledFonts() {
    Add-Type -AssemblyName System.Drawing
    $familyList = @(); $installedFontCollection = New-Object System.Drawing.Text.InstalledFontCollection
    $fontFamilies = $installedFontCollection.Families
    foreach ($fontFamily in $fontFamilies) { $familyList += $fontFamily.Name }
    return $familyList
  }
  # static [System.Drawing.Font] NewFont([string]$Name) {
  #     Add-Type -AssemblyName 'System.Drawing'
  #     $fontFamily = [System.Drawing.FontFamily]::New("$Name")
  #     return [System.Drawing.Font]::new($fontFamily, 8, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
  # }
  static [string] GetResolvedPath([string]$Path) {
    return [FontMan]::GetResolvedPath($((Get-Variable ExecutionContext).Value.SessionState), $Path)
  }
  static [string] GetResolvedPath([System.Management.Automation.SessionState]$session, [string]$Path) {
    $paths = $session.Path.GetResolvedPSPathFromPSPath($Path);
    if ($paths.Count -gt 1) {
      throw [System.IO.IOException]::new([string]::Format([cultureinfo]::InvariantCulture, "Path {0} is ambiguous", $Path))
    } elseif ($paths.Count -lt 1) {
      throw [System.IO.IOException]::new([string]::Format([cultureinfo]::InvariantCulture, "Path {0} not Found", $Path))
    }
    return $paths[0].Path
  }
  static [string] GetUnResolvedPath([string]$Path) {
    return [FontMan]::GetUnResolvedPath($((Get-Variable ExecutionContext).Value.SessionState), $Path)
  }
  static [string] GetUnResolvedPath([System.Management.Automation.SessionState]$session, [string]$Path) {
    return $session.Path.GetUnresolvedProviderPathFromPSPath($Path)
  }
  static [string[]] Get_font_folders() {
    return (xcrypt Get_Host_Os).Equals("Windows") ? $(New-Object -COM "Shell.Application").NameSpace(20).Self.Path : $(((fc-list).Split("`n") | Select-Object @{l = 'Fonts'; e = { ([IO.FileInfo]$_.Split(":")[0]).Directory } }).Fonts.Parent.FullName | Sort-Object -Unique)
  }
  static hidden [void] init() {
    if ($null -eq [FontMan].FontRes32) {
      Add-Type -TypeDefinition ([System.Text.Encoding]::UTF8.GetString([convert]::FromBase64String('dXNpbmcgU3lzdGVtOwp1c2luZyBTeXN0ZW0uSU87CnVzaW5nIFN5c3RlbS5UZXh0Owp1c2luZyBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYzsKdXNpbmcgU3lzdGVtLlJ1bnRpbWUuSW50ZXJvcFNlcnZpY2VzOwpwdWJsaWMgZW51bSBXTSA6IHVpbnQgeyBGT05UQ0hBTkdFID0gMHgwMDFEIH0KcHVibGljIGNsYXNzIEZvbnRSZXMzMiB7CiAgICBwcml2YXRlIHN0YXRpYyBJbnRQdHIgSFdORF9CUk9BRENBU1QgPSBuZXcgSW50UHRyKDB4ZmZmZik7CiAgICBwcml2YXRlIHN0YXRpYyBJbnRQdHIgSFdORF9UT1AgPSBuZXcgSW50UHRyKDApOwogICAgcHJpdmF0ZSBzdGF0aWMgSW50UHRyIEhXTkRfQk9UVE9NID0gbmV3IEludFB0cigxKTsKICAgIHByaXZhdGUgc3RhdGljIEludFB0ciBIV05EX1RPUE1PU1QgPSBuZXcgSW50UHRyKC0xKTsKICAgIHByaXZhdGUgc3RhdGljIEludFB0ciBIV05EX05PVE9QTU9TVCA9IG5ldyBJbnRQdHIoLTIpOwogICAgcHJpdmF0ZSBzdGF0aWMgSW50UHRyIEhXTkRfTUVTU0FHRSA9IG5ldyBJbnRQdHIoLTMpOwogICAgW0RsbEltcG9ydCgiZ2RpMzIuZGxsIiwgU2V0TGFzdEVycm9yID0gdHJ1ZSwgQ2hhclNldCA9IENoYXJTZXQuQXV0byldCiAgICBwdWJsaWMgc3RhdGljIGV4dGVybiBpbnQgQWRkRm9udFJlc291cmNlKHN0cmluZyBscEZpbGVuYW1lKTsKICAgIFtEbGxJbXBvcnQoImdkaTMyLmRsbCIsIFNldExhc3RFcnJvciA9IHRydWUsIENoYXJTZXQgPSBDaGFyU2V0LkF1dG8pXQogICAgcHVibGljIHN0YXRpYyBleHRlcm4gaW50IFJlbW92ZUZvbnRSZXNvdXJjZShzdHJpbmcgbHBGaWxlTmFtZSk7CiAgICBbRGxsSW1wb3J0KCJ1c2VyMzIuZGxsIiwgU2V0TGFzdEVycm9yID0gdHJ1ZSwgQ2hhclNldCA9IENoYXJTZXQuQXV0byldCiAgICBwdWJsaWMgc3RhdGljIGV4dGVybiBpbnQgU2VuZE1lc3NhZ2UoSW50UHRyIGhXbmQsIFdNIHdNc2csIEludFB0ciB3UGFyYW0sIEludFB0ciBsUGFyYW0pOwogICAgW3JldHVybjogTWFyc2hhbEFzKFVubWFuYWdlZFR5cGUuQm9vbCldCiAgICBbRGxsSW1wb3J0KCJ1c2VyMzIuZGxsIiwgU2V0TGFzdEVycm9yID0gdHJ1ZSwgQ2hhclNldCA9IENoYXJTZXQuQXV0byldCiAgICBwdWJsaWMgc3RhdGljIGV4dGVybiBib29sIFBvc3RNZXNzYWdlKEludFB0ciBoV25kLCBXTSBNc2csIEludFB0ciB3UGFyYW0sIEludFB0ciBsUGFyYW0pOwogICAgcHVibGljIHN0YXRpYyBpbnQgQWRkRm9udChzdHJpbmcgZm9udEZpbGVQYXRoKSB7CiAgICAgICAgRmlsZUluZm8gZm9udEZpbGUgPSBuZXcgRmlsZUluZm8oZm9udEZpbGVQYXRoKTsKICAgICAgICBpZiAoIWZvbnRGaWxlLkV4aXN0cykgeyByZXR1cm4gMDsgfQogICAgICAgIHRyeSAgewogICAgICAgICAgICBpbnQgcmV0VmFsID0gQWRkRm9udFJlc291cmNlKGZvbnRGaWxlUGF0aCk7CiAgICAgICAgICAgIGJvb2wgcG9zdGVkID0gUG9zdE1lc3NhZ2UoSFdORF9CUk9BRENBU1QsIFdNLkZPTlRDSEFOR0UsIEludFB0ci5aZXJvLCBJbnRQdHIuWmVybyk7CiAgICAgICAgICAgIHJldHVybiByZXRWYWw7CiAgICAgICAgfSBjYXRjaCB7CiAgICAgICAgICAgIHJldHVybiAwOwogICAgICAgIH0KICAgIH0KICAgIHB1YmxpYyBzdGF0aWMgaW50IFJlbW92ZUZvbnQoc3RyaW5nIGZvbnRGaWxlTmFtZSkgewogICAgICAgIHRyeSB7CiAgICAgICAgICAgIGludCByZXRWYWwgPSBSZW1vdmVGb250UmVzb3VyY2UoZm9udEZpbGVOYW1lKTsKICAgICAgICAgICAgYm9vbCBwb3N0ZWQgPSBQb3N0TWVzc2FnZShIV05EX0JST0FEQ0FTVCwgV00uRk9OVENIQU5HRSwgSW50UHRyLlplcm8sIEludFB0ci5aZXJvKTsKICAgICAgICAgICAgcmV0dXJuIHJldFZhbDsKICAgICAgICB9IGNhdGNoIHsKICAgICAgICAgICAgcmV0dXJuIDA7CiAgICAgICAgfQogICAgfQp9')));
      [FontMan].psobject.Properties.Add([PsScriptProperty]::new('FontRes32',
          { return (New-Object FontRes32) }
        )
      )
    }
  }
}

class ConsoleWriter : System.IO.TextWriter {
  static hidden [string] $leadPreffix
  static hidden [string[]] $Colors = [ConsoleWriter]::get_ColorNames()
  static hidden [ValidateNotNull()][scriptblock]$ValidateScript = { param($arg) if ([String]::IsNullOrEmpty($arg)) { throw [ArgumentNullException]::new('text', 'Cannot be Null Or Empty') } }

  static [string] write([string]$text) {
    return [ConsoleWriter]::Write($text, 20, 1200)
  }
  static [string] Write([string]$text, [bool]$AddPreffix) {
    return [ConsoleWriter]::Write($text, 20, 1200, $AddPreffix)
  }
  static [string] Write([string]$text, [int]$Speed, [int]$Duration) {
    return [ConsoleWriter]::Write($text, 20, 1200, $true)
  }
  static [string] write([string]$text, [ConsoleColor]$color) {
    return [ConsoleWriter]::Write($text, $color, $true)
  }
  static [string] write([string]$text, [ConsoleColor]$color, [bool]$Animate) {
    return [ConsoleWriter]::Write($text, [ConsoleWriter]::leadPreffix, 20, 1200, $color, $Animate, $true)
  }
  static [string] write([string]$text, [int]$Speed, [int]$Duration, [bool]$AddPreffix) {
    return [ConsoleWriter]::Write($text, [ConsoleWriter]::leadPreffix, $Speed, $Duration, [ConsoleColor]::White, $true, $AddPreffix)
  }
  static [string] write([string]$text, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix) {
    return [ConsoleWriter]::Write($text, [ConsoleWriter]::leadPreffix, 20, 1200, $color, $Animate, $AddPreffix)
  }
  static [string] write([string]$text, [string]$Preffix, [System.ConsoleColor]$color) {
    return [ConsoleWriter]::Write($text, $Preffix, $color, $true)
  }
  static [string] write([string]$text, [string]$Preffix, [System.ConsoleColor]$color, [bool]$Animate) {
    return [ConsoleWriter]::Write($text, $Preffix, 20, 1200, $color, $Animate, $true)
  }
  static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [bool]$AddPreffix) {
    return [ConsoleWriter]::Write($text, $Preffix, $Speed, $Duration, [ConsoleColor]::White, $true, $AddPreffix)
  }
  static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix) {
    return [ConsoleWriter]::Write($text, $Preffix, $Speed, $Duration, $color, $Animate, $AddPreffix, [ConsoleWriter]::ValidateScript)
  }
  static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix, [scriptblock]$ValidateScript) {
    if ($null -ne $ValidateScript) {
      [void]$ValidateScript.Invoke($text)
    } elseif ([string]::IsNullOrWhiteSpace($text)) {
      return $text
    }
    [int]$length = $text.Length; $delay = 0
    # Check if delay time is required:
    $delayIsRequired = if ($length -lt 50) { $false } else { $delay = $Duration - $length * $Speed; $delay -gt 0 }
    if ($AddPreffix -and ![string]::IsNullOrEmpty($Preffix)) {
      [void][ConsoleWriter]::Write($Preffix, [string]::Empty, 1, 100, [ConsoleColor]::Green, $false, $false);
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
  static [byte[]] Encode([string]$text) { return [System.Text.Encoding]::UTF8.GetBytes($text) }
  static [string[]] get_ColorNames() {
    return [color].GetMethods().Where({ $_.IsStatic -and $_.Name -like "Get_*" }).Name.Substring(4)
  }
  static [int] get_ConsoleWidth() {
    # Force a refresh of the console information
    [System.Console]::SetCursorPosition([System.Console]::CursorLeft, [System.Console]::CursorTop)
    return [System.Console]::WindowWidth
  }
  hidden [System.Text.Encoding] get_Encoding() { return [System.Text.Encoding]::UTF8 }
}

class ConsoleReader : System.IO.TextReader {
  ConsoleReader() : base() { }
  [int] Read() {
    $key = [Console]::ReadKey($true)
    return [int][char]$key.KeyChar
  }
  [int] Read([char[]]$buffer, [int]$index, [int]$count) {
    if ($null -eq $buffer) {
      throw [ArgumentNullException]::new("buffer")
    }
    if ($index -lt 0 -or $count -lt 0) {
      throw [ArgumentOutOfRangeException]::new("Index and count must be non-negative")
    }
    if ($buffer.Length - $index -lt $count) {
      throw [ArgumentException]::new("Buffer too small")
    }

    $charsRead = 0
    while ($charsRead -lt $count -and [Console]::KeyAvailable) {
      $key = [Console]::ReadKey($true)
      $buffer[$index + $charsRead] = $key.KeyChar
      $charsRead++
    }
    return $charsRead
  }
  [string] ReadLine() {
    return [Console]::ReadLine()
  }
}

class clistyle : PsRecord {
  [HostOs] $HostOS
  [PsObject] $PROFILE
  [string[]] $ompJson
  [char] $swiglyChar
  [Hashtable] $colors
  [PsObject] $PSVersn
  [bool] $CurrExitCode
  [char] $DirSeparator
  [string] $Home_Indic
  [string] $WindowTitle
  [string] $leadingChar
  [string] $trailngChar
  [IO.FileInfo] $LogFile
  [IO.FileInfo] $OmpJsonFile
  [string] $Default_Term_Ascii
  [string[]] $Default_Dependencies
  [string] $WINDOWS_TERMINAL_JSON_PATH
  [Int32] $realLASTEXITCODE = $LASTEXITCODE
  [PSCustomObject] $TERMINAL_Settings

  # brackets, dots, newline
  hidden [string] $b1
  hidden [string] $b2
  hidden [string] $dt
  hidden [string] $nl

  clistyle () {
    $this.Set_Defaults()
  }
  [void] Initialize() {
    $this.Initialize(@())
  }
  [void] Initialize([string[]]$DependencyModules) {
    $this.Initialize(@(), $false)
  }
  [void] Initialize([string[]]$DependencyModules, [bool]$force) {
    $v = [ProgressUtil]::data.ShowProgress
    $v ? (Write-Console '[clistyle] Set variable defaults' -f DarkKhaki) : $null
    $this.Set_Defaults()
    $v ? (Write-Console '[clistyle] Resolving Requirements ... (a one-time process)' -f DarkKhaki) : $null
    # Inspired by: https://dev.to/ansonh/customize-beautify-your-windows-terminal-2022-edition-541l
    if ($null -eq (Get-PSRepository -Name PSGallery -ErrorAction Ignore)) {
      throw 'PSRepository named PSGallery was Not found!'
    }
    Set-PSRepository PSGallery -InstallationPolicy Trusted;
    $PackageProviderNames = (Get-PackageProvider -ListAvailable).Name
    $requiredModules = $this.Default_Dependencies + $DependencyModules | Sort-Object -Unique
    foreach ($name in @("NuGet", "PowerShellGet")) {
      if ($force) {
        Install-PackageProvider $name -Force
      } elseif ($PackageProviderNames -notcontains $name) {
        Install-PackageProvider $name -Force
      } else {
        $v ? (Write-Console "PackageProvider '$name' is already Installed." -f Wheat) : $null
      }
    }
    # Install requied modules: # we could use Install-Module -Name $_ but it fails sometimes
    $requiredModules | Resolve-Module
    # BeautifyTerminal :
    if ($this.IsTerminalInstalled()) {
      $this.AddColorScheme()
    } else {
      Write-Warning "Windows terminal is not Installed!"
    }
    $this.InstallNerdFont()
    $this.InstallOhMyPosh() # instead of: winget install JanDeDobbeleer.OhMyPosh
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView # Optional
    # WinFetch
    Install-Script -Name winfetch -AcceptLicense

    if (!(Test-Path -Path $env:USERPROFILE/.config/winfetch/config.ps1)) {
      winfetch -genconf
    }
        (Get-Content $env:USERPROFILE/.config/winfetch/config.ps1).Replace('# $ShowDisks = @("*")', '$ShowDisks = @("*")') | Set-Content $env:USERPROFILE/.config/winfetch/config.ps1
        (Get-Content $env:USERPROFILE/.config/winfetch/config.ps1).Replace('# $memorystyle', '$memorystyle') | Set-Content $env:USERPROFILE/.config/winfetch/config.ps1
        (Get-Content $env:USERPROFILE/.config/winfetch/config.ps1).Replace('# $diskstyle', '$diskstyle') | Set-Content $env:USERPROFILE/.config/winfetch/config.ps1
    # RESET current exit code:
    $this.CurrExitCode = $true

    $v ? (Write-Console '[clistyle] Load configuration settings ...' -f DarkKhaki) : $null
    $this.LoadConfiguration()

    Set-Variable -Name Colors -Value $($this.colors) -Scope Global -Visibility Public -Option AllScope
    if ($force) {
      # Invoke-Command -ScriptBlock $Load_Profile_Functions
      $this.CurrExitCode = $? -and $($this.Create_Prompt_Function())
    } else {
      if (!$($this.IsInitialised())) {
        # Invoke-Command -ScriptBlock $Load_Profile_Functions
        $this.CurrExitCode = $? -and $($this.Create_Prompt_Function())
      } else {
        $v ? (Write-Console "[clistyle] is already Initialized, Skipping ..." -f Wheat) : $null
      }
    }
    [void]$this.GetPsProfile() # create the $profile file if it does not exist
    $this.Set_TerminalUI()
    $v ? (Write-Console "[clistyle] Displaying a welcome message/MOTD ..." -f DarkKhaki) : $null
    $this.Write_Term_Ascii()
  }
  [bool] IsInitialised() {
    return (Get-Variable -Name IsPromptInitialised -Scope Global).Value
  }
  [void] LoadConfiguration() {
    $this.TERMINAL_Settings = $this.GetTerminalSettings();
  }
  [PSCustomObject] GetTerminalSettings() {
    if ($this.IsTerminalInstalled()) {
      if ([IO.Directory]::Exists($this.WINDOWS_TERMINAL_JSON_PATH)) {
        return (Get-Content $($this.WINDOWS_TERMINAL_JSON_PATH) -Raw | ConvertFrom-Json)
      }
      Write-Warning "Could not find WINDOWS_TERMINAL_JSON_PATH!"
    } else {
      Write-Warning "Windows terminal is not installed!"
    }
    return $null
  }
  [void] SaveTerminalSettings([PSCustomObject]$settings) {
    # Save changes (Write Windows Terminal settings)
    $settings | ConvertTo-Json -Depth 32 | Set-Content $($this.WINDOWS_TERMINAL_JSON_PATH)
  }
  hidden [void] AddColorScheme() {
    $settings = $this.GetTerminalSettings();
    if ($null -ne $settings) {
      $sonokaiSchema = [PSCustomObject]@{
        name                = "Sonokai Shusia"
        background          = "#2D2A2E"
        black               = "#1A181A"
        blue                = "#1080D0"
        brightBlack         = "#707070"
        brightBlue          = "#22D5FF"
        brightCyan          = "#7ACCD7"
        brightGreen         = "#A4CD7C"
        brightPurple        = "#AB9DF2"
        brightRed           = "#F882A5"
        brightWhite         = "#E3E1E4"
        brightYellow        = "#E5D37E"
        cursorColor         = "#FFFFFF"
        cyan                = "#3AA5D0"
        foreground          = "#E3E1E4"
        green               = "#7FCD2B"
        purple              = "#7C63F2"
        red                 = "#F82F66"
        selectionBackground = "#FFFFFF"
        white               = "#E3E1E4"
        yellow              = "#E5DE2D"
      }
      # Check color schema added before or not?
      if ($settings.schemes | Where-Object -Property name -EQ $sonokaiSchema.name) {
        Write-Host "[clistyle] Terminal Color Theme was added before"
      } else {
        $settings.schemes += $sonokaiSchema
        # Check default profile has colorScheme or not
        if ($settings.profiles.defaults | Get-Member -Name 'colorScheme' -MemberType Properties) {
          $settings.profiles.defaults.colorScheme = $sonokaiSchema.name
        } else {
          $settings.profiles.defaults | Add-Member -MemberType NoteProperty -Name 'colorScheme' -Value $sonokaiSchema.name
        }
        $this.SaveTerminalSettings($settings);
      }
    } else {
      Write-Warning "[clistyle] Could not get TerminalSettings, please make sure windowsTerminal is installed."
    }
  }
  hidden [void] InstallNerdFont() {
    $this.InstallNerdFont('FiraCode')
  }
  hidden [void] InstallNerdFont([string]$FontName) {
    #Requires -Version 3.0
    [ValidateNotNullorEmpty()][string]$FontName = $FontName
    $v = [ProgressUtil]::data.ShowProgress
    if ([FontMan]::GetInstalledFonts().Contains("$FontName")) {
      $v ? (Write-Console "[clistyle] Font '$FontName' is already installed!" -f Wheat) : $null
      return
    }
    $v ? (Write-Console "Install required Font:  ($FontName)" -f Magenta) : $null
    [IO.DirectoryInfo]$FiraCodeExpand = [IO.Path]::Combine($env:temp, 'FiraCodeExpand')
    if (![System.IO.Directory]::Exists($FiraCodeExpand.FullName)) {
      $fczip = [IO.FileInfo][IO.Path]::Combine($env:temp, 'FiraCode.zip')
      if (![IO.File]::Exists($fczip.FullName)) {
        Invoke-WebRequest -Uri https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip -OutFile $fczip.FullName
      }
      Expand-Archive -Path $fczip.FullName -DestinationPath $FiraCodeExpand.FullName
      Remove-Item -Path $fczip.FullName -Recurse
    }
    # Install Fonts
    # the Install-Font function is found in PSWinGlue module
    "PSWinGlue" | Resolve-Module
    Import-Module -Name PSWinGlue -WarningAction silentlyContinue
    # Elevate to Administrative
    if (!$this.IsAdministrator()) {
      $command = "Install-Font -Path '{0}'" -f ([IO.Path]::Combine($env:temp, 'FiraCodeExpand'))
      Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command {$command}" -Verb RunAs -Wait -WindowStyle Minimized
    }
    $settings = $this.GetTerminalSettings()
    if ($null -ne $settings) {
      # Check default profile has font or not
      if ($settings.profiles.defaults | Get-Member -Name 'font' -MemberType Properties) {
        $settings.profiles.defaults.font.face = 'FiraCode Nerd Font'
      } else {
        $settings.profiles.defaults | Add-Member -MemberType NoteProperty -Name 'font' -Value $(
          [PSCustomObject]@{
            face = 'FiraCode Nerd Font'
          }
        ) | ConvertTo-Json
      }
      $this.SaveTerminalSettings($settings);
    } else {
      Write-Warning "Could update Terminal font settings!"
    }
  }
  hidden [void] InstallWinget() {
    Write-Host "Install winget" -ForegroundColor Magenta
    $wngt = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
    $deps = ('Microsoft.VCLibs.x64.14.00.Desktop.appx', 'Microsoft.UI.Xaml.x64.appx')
    $PPref = Get-Variable -Name progressPreference -Scope Global; $progressPreference = 'silentlyContinue'
    $IPref = Get-Variable -Name InformationPreference -Scope Global; $InformationPreference = "Continue"
    if ([bool](Get-Command winget -Type Application -ea Ignore) -and !$PSBoundParameters.ContainsKey('Force')) {
      Write-Host "Winget is already Installed." -ForegroundColor Green -NoNewline; Write-Host " Use -Force switch to Overide it."
      return
    }
    # Prevent Error code: 0x80131539
    # https://github.com/PowerShell/PowerShell/issues/13138
    Get-Command Add-AppxPackage -ErrorAction Ignore
    if ($Error[0]) {
      if ($Error[0].GetType().FullName -in ('System.Management.Automation.CmdletInvocationException', 'System.Management.Automation.CommandNotFoundException')) {
        Write-Host "Module Appx is not loaded by PowerShell Core! Importing ..." -ForegroundColor Yellow
        Import-Module -Name Appx -UseWindowsPowerShell -Verbose:$false -WarningAction SilentlyContinue
      }
    }
    Write-Host "[0/3] Downloading WinGet and its dependencies ..." -ForegroundColor Green
    Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile $wngt
    Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile $deps[0]
    Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx -OutFile $deps[1];

    Write-Host "[1/3] Installing $($deps[0]) ..." -ForegroundColor Green
    Add-AppxPackage -Path $deps[0]

    Write-Host "[2/3] Installing $($deps[1]) ..." -ForegroundColor Green
    Add-AppxPackage -Path $deps[1]

    Write-Host "[3/3] Installing $wngt ..." -ForegroundColor Green
    Add-AppxPackage -Path $wngt
    # cleanup
    $deps + $wngt | ForEach-Object { Remove-Item ($_ -as 'IO.FileInfo').FullName -Force -ErrorAction Ignore }
    # restore
    $progressPreference = $PPref
    $InformationPreference = $IPref
  }
  [void] InstallOhMyPosh() {
    $this.InstallOhMyPosh($true, $false)
  }
  [void] InstallOhMyPosh([bool]$AllUsers, [bool]$force) {
    $ompath = Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly -ErrorAction Ignore
    if ($null -eq $ompath) { $this.Set_Defaults() }; $v = [ProgressUtil]::data.ShowProgress
    $ompdir = [IO.DirectoryInfo]::new((Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly))
    if (!$ompdir.Exists) { [void]$this.Create_Directory($ompdir.FullName) }
    if (!$force -and [bool](Get-Command oh-my-posh -Type Application -ErrorAction Ignore)) {
      $v ? (Write-Console "oh-my-posh is already Installed; moing on ..." -f Wheat) : $null
      return
    }
    # begin installation
    $v ? (Write-Console "Install OhMyPosh" -f Magenta) : $null
    $installer = ''; $installInstructions = "`nHey friend`n`nThis installer is only available for Windows.`nIf you're looking for installation instructions for your operating system,`nplease visit the following link:`n"
    $Host_OS = $this.HostOS.ToString()
    if ($Host_OS -eq "MacOS") {
      $v ? (Write-Console "`n$installInstructions`n`nhttps://ohmyposh.dev/docs/installation/macos`n" -f Wheat) : $null
    } elseif ($Host_OS -eq "Linux") {
      $v ? (Write-Console "`n$installInstructions`n`nhttps://ohmyposh.dev/docs/installation/linux" -f Wheat) : $null
    } elseif ($Host_OS -eq "Windows") {
      $arch = (Get-CimInstance -Class Win32_Processor -Property Architecture).Architecture | Select-Object -First 1
      switch ($arch) {
        0 { $installer = "install-386.exe" }
        5 { $installer = "install-arm64.exe" }
        9 {
          if ([Environment]::Is64BitOperatingSystem) {
            $installer = "install-amd64.exe"
          } else {
            $installer = "install-386.exe"
          }
        }
        12 { $installer = "install-arm64.exe" }
      }
      if ([string]::IsNullOrEmpty($installer)) {
        throw "`nThe installer for system architecture ($(@{
                    0  = 'X86'
                    5  = 'ARM'
                    9  = 'AMD64/32'
                    12 = 'Surface'
                }.$arch)) is not available.`n"
      }
      $v ? (Write-Console "Downloading $installer..." -f DarkKhaki) : $null
      $omp_installer = [IO.FileInfo]::new("aux"); $ret_count = 0
      do {
        $omp_installer = [IO.FileInfo]::new([IO.Path]::Combine($env:TEMP, ([System.IO.Path]::GetRandomFileName() -replace '\.\w+$', '.exe'))); $ret_count++
      } while (![IO.File]::Exists($omp_installer.FullName) -and $ret_count -le 10)
      $url = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/$installer"
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      Invoke-WebRequest -OutFile $omp_installer.FullName -Uri $url
      $v ? (Write-Console 'Running installer...' -f DarkKhaki) : $null
      $installMode = "/CURRENTUSER"
      if ($AllUsers) {
        $installMode = "/ALLUSERS"
      }

      & "$omp_installer" /VERYSILENT $installMode | Out-Null
      $omp_installer | Remove-Item
      #todo: refresh the shell
    } else {
      throw "Error: Could not determine the Host operating system."
    }
  }
  [bool] IsTerminalInstalled() {
    $IsInstalled = $true
    # check in wt if added to %PATH%
    $defWtpath = (Get-Command wt.exe -Type Application -ErrorAction Ignore).Source
    if (![string]::IsNullOrWhiteSpace($defWtpath)) {
      return $IsInstalled
    }
    # check generic paths: https://stackoverflow.com/questions/62894666/path-and-name-of-exe-file-of-windows-terminal-preview
    $genericwt = [IO.FileInfo]::new("$env:LocalAppData/Microsoft/WindowsApps/wt.exe")
    $msstorewt = [IO.FileInfo]::new("$env:LocalAppData/Microsoft/WindowsApps/Microsoft.WindowsTerminal_8wekyb3d8bbwe/wt.exe")
    $IsInstalled = $IsInstalled -and ($genericwt.Exists -or $msstorewt.Exists)
    return $IsInstalled
  }
  [bool] IsAdministrator() {
    return [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
  }
  [IO.FileInfo] GetPsProfile() {
    # This method will return the profile file (CurrentUserCurrentHost) and creates a new one if it does not already exist.
    $Documents_Path = $this.GetDocumentsPath()
    if (!$Documents_Path.Exists) {
      New-Item -Path $Documents_Path -ItemType Directory
    }
    # Manually get CurrentUserCurrentHost profile file
    $prof = [IO.FileInfo]::new([IO.Path]::Combine($Documents_Path, 'PowerShell', 'Microsoft.PowerShell_profile.ps1'))
    if (!$prof.Exists) { $prof = $this.GetPsProfile($prof) }
    return $prof
  }
  [IO.FileInfo] GetPsProfile([IO.FileInfo]$file) {
    if (!$file.Directory.Exists) { [void]$this.Create_Directory($file.Directory.FullName) }
    $file = New-Item -ItemType File -Path $file.FullName
    $this.Add_OMP_To_Profile($file)
    return $file
  }
  [IO.DirectoryInfo] GetDocumentsPath() {
    $User_docs_Path = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)
    $Documents_Path = if (![IO.Path]::Exists($User_docs_Path)) {
      $UsrProfile = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
      $mydocsPath = if (![IO.Path]::Exists($UsrProfile)) {
        $commondocs = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonDocuments)
        if (![IO.Path]::Exists($commondocs)) {
          $all_spec_docs_paths = (0..61 | ForEach-Object { (New-Object –COM "Shell.Application").NameSpace($_).Self.Path }).Where({ $_ -like "*$([IO.Path]::DirectorySeparatorChar)Documents" }).Foreach({ $_ })
          if ($all_spec_docs_paths.count -eq 0) {
            throw [System.InvalidOperationException]::new("Could not find Documents Path")
          }
          $all_spec_docs_paths[0]
        }
        $commondocs
      } else {
        [IO.Path]::Combine($UsrProfile, 'Documents')
      }
      $mydocsPath
    } else {
      $User_docs_Path
    }
    return $Documents_Path -as [IO.DirectoryInfo]
  }
  [string] Get_omp_Json() {
    if ([string]::IsNullOrWhiteSpace("$([string]$this.ompJson) ".Trim())) {
      return $this.get_omp_Json('omp.json', [uri]::new('https://gist.github.com/chadnpc/b106f0e618bb9bbef86611824fc37825'))
    }
    return $this.ompJson
  }
  [string] Get_omp_Json([string]$fileName, [uri]$gisturi) {
    Write-Host "Fetching the latest $fileName" -ForegroundColor Green;
    $gistId = $gisturi.Segments[-1];
    $jsoncontent = Invoke-WebRequest "https://gist.githubusercontent.com/chadnpc/$gistId/raw/$fileName" -Verbose:$false | Select-Object -ExpandProperty Content
    if ([string]::IsNullOrWhiteSpace("$jsoncontent ".Trim())) {
      Throw [System.IO.InvalidDataException]::NEW('FAILED to get valid json string gtom github gist')
    }
    return $jsoncontent
  }
  [void] Set_omp_Json() {
    $this.set_omp_Json('omp.json', [uri]::new('https://gist.github.com/chadnpc/b106f0e618bb9bbef86611824fc37825'))
  }
  [void] Set_omp_Json([string]$fileName, [uri]$gisturi) {
    if ($null -eq $this.OmpJsonFile.FullName) { $this.Set_Defaults() }
    $this.OmpJsonFile = [IO.FileInfo]::New([IO.Path]::Combine($(Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly -ErrorAction Ignore), 'themes', 'p10k_classic.omp.json'))
    if (!$this.OmpJsonFile.Exists) {
      if (!$this.OmpJsonFile.Directory.Exists) { [void]$this.Create_Directory($this.OmpJsonFile.Directory.FullName) }
      $this.OmpJsonFile = New-Item -ItemType File -Path ([IO.Path]::Combine($this.OmpJsonFile.Directory.FullName, $this.OmpJsonFile.Name))
      $this.get_omp_Json($fileName, $gisturi) | Out-File ($this.OmpJsonFile.FullName) -Encoding utf8
    } else {
      Write-Host "Found $($this.OmpJsonFile)" -ForegroundColor Green
    }
    $this.ompJson = [IO.File]::ReadAllLines($this.OmpJsonFile.FullName)
  }
  [void] Set_Defaults() {
    Write-Verbose "Set defaults ..."
    $this.Default_Dependencies = @('Terminal-Icons', 'PSReadline', 'Pester', 'Posh-git', 'PSWinGlue', 'PowerShellForGitHub');
    $this.swiglyChar = [char]126;
    $this.DirSeparator = [System.IO.Path]::DirectorySeparatorChar;
    $this.nl = [Environment]::NewLine;
    # UTF8 Characters from https://www.w3schools.com/charsets/ref_utf_box.asp
    $this.dt = [string][char]8230;
    $this.b1 = [string][char]91;
    $this.b2 = [string][char]93;
    $this.Home_Indic = $this.swiglyChar + [IO.Path]::DirectorySeparatorChar;
    $this.PSVersn = (Get-Variable PSVersionTable).Value;
    $this.leadingChar = [char]9581 + [char]9592;
    $this.trailngChar = [char]9584 + [char]9588;
    $this.LogFile;
    $this.colors = $this.Get_Colors()
    # Prevent tsl errors
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    # Set the default launch ascii : chadnpc. but TODO: add a way to load it from a config instead of hardcoding it.
    $this.Default_Term_Ascii = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('bSUBJQElASVuJW0lbiUgACAAIAAgACAAIAAgAG0lASUBJQElbiVtJW4lCgADJW0lASVuJQMlAyUDJSAAIAAgAG0lbiUgACAAAyVtJQElbiUDJW8lcCVuJQoAAyUDJSAAAyUDJQMlbSUBJQElbiVtJW4lASVuJQMlAyUgAAMlAyVuJW0lbSUBJQElbiUBJQElbiUKAAMlcCUBJW8lAyUDJQMlbSUgAAMlfAADJW0lbiVuJQMlIAADJQMlAyUDJXwAbSVuJQMlbSUBJW8lCgADJW0lASVuJQMlAyVwJXAlbyVwJW4lAyUDJQMlAyVwJQElbyUDJQMlcCVuJQMlASUrJXAlASVuJQoAcCVvJSAAcCVvJXAlASVvJQElASVvJW8lbyVwJW8lASUBJW4lcCUBJQElbyUBJQElbyUBJQElbyUKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIABwJW8lCgAiAFEAdQBpAGMAawAgAHAAcgBvAGQAdQBjAHQAaQB2AGUAIAB0AGUAYwBoACIA'));
    $this.WINDOWS_TERMINAL_JSON_PATH = [IO.Path]::Combine($env:LocalAppdata, 'Packages', 'Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'LocalState', 'settings.json');
    # Initialize or Reload $PROFILE and the core functions necessary for displaying your custom prompt.
    $p = [PSObject]::new(); Get-Variable PROFILE -ValueOnly | Get-Member -Type NoteProperty | ForEach-Object {
      $p | Add-Member -Name $_.Name -MemberType NoteProperty -Value ($_.Definition.split('=')[1] -as [IO.FileInfo])
    }
    $this.PROFILE = $p
    # Set Host UI DEFAULS
    $this.WindowTitle = $this.GetWindowTitle()
    if (!(Get-Variable OH_MY_POSH_PATH -ValueOnly -ErrorAction Ignore)) {
      New-Variable -Name OH_MY_POSH_PATH -Scope Global -Option Constant -Value ([IO.Path]::Combine($env:LOCALAPPDATA, 'Programs', 'oh-my-posh')) -Force
    }
    $this.HostOS = $(if ($(Get-Variable PSVersionTable -Value).PSVersion.Major -le 5 -or $(Get-Variable IsWindows -Value)) { "Windows" }elseif ($(Get-Variable IsLinux -Value)) { "Linux" }elseif ($(Get-Variable IsMacOS -Value)) { "MacOS" }else { "UNKNOWN" });
    $this.OmpJsonFile = [IO.FileInfo]::New([IO.Path]::Combine($(Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly), 'themes', 'p10k_classic.omp.json'))
  }
  [void] Add_OMP_To_Profile() {
    $this.Add_OMP_To_Profile($this.GetPsProfile())
  }
  [void] Add_OMP_To_Profile([IO.FileInfo]$File) {
    Write-Host "Checking for OH_MY_POSH in Profile ... " -ForegroundColor Yellow
    if ([string]::IsNullOrWhiteSpace("$([string]$this.ompJson) ".Trim())) {
      try {
        $this.ompJson = $this.get_omp_Json()
      } catch [System.Net.Http.HttpRequestException], [System.Net.Sockets.SocketException] {
        throw [System.Exception]::New('gist.githubusercontent.com:443  Please check your internet')
      }
    }
    if (!$this.OmpJsonFile.Exists) {
      Set-Content -Path ($this.OmpJsonFile.FullName) -Value ($this.ompJson) -Force
    }
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Enable Oh My Posh Theme Engine')
    [void]$sb.AppendLine('oh-my-posh --init --shell pwsh --config ~/AppData/Local/Programs/oh-my-posh/themes/p10k_classic.omp.json | Invoke-Expression')
    if (!(Select-String -Path $File.FullName -Pattern "oh-my-posh" -SimpleMatch -Quiet)) {
      # TODO: #3 Move configuration to directory instead of manipulating original profile file
      Write-Host "Add OH_MY_POSH to Profile ... " -NoNewline -ForegroundColor DarkYellow
      Add-Content -Path $File.FullName -Value $sb.ToString()
      Write-Host "Done." -ForegroundColor Yellow
    } else {
      Write-Host "OH_MY_POSH is added to Profile." -ForegroundColor Green
    }
  }
  [void] Set_TerminalUI() {
        (Get-Variable -Name Host -ValueOnly).UI.RawUI.WindowTitle = $this.WindowTitle
        (Get-Variable -Name Host -ValueOnly).UI.RawUI.ForegroundColor = "White"
        (Get-Variable -Name Host -ValueOnly).PrivateData.ErrorForegroundColor = "DarkGray"
  }
  [string] GetWindowTitle() {
    $Title = ($this.GetCurrentProces().Path -as [IO.FileInfo]).BaseName
    try {
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
      if ($UserRole.IsPowerUser) {
        $Title += $($this.b1 + 'E' + $this.b2) # IsElevated
      }
      if ($UserRole.HasSysPriv) {
        $Title += $($this.b1 + 'S' + $this.b2) # IsSYSTEM
      }
      # Admin indicator not neded, since Windows11 build 22557.1
      if ($UserRole.HasAdminPriv) { $Title += ' (Admin)' }
      if ($UserRole.HasUserPriv -and !($UserRole.HasAdminPriv)) { $Title += ' (User)' }
    } catch [System.PlatformNotSupportedException] {
      $Title += $($this.b1 + $this.b2 + ' (User)')
    }
    return $Title
  }
  [void] Write_Term_Ascii() {
    if ($null -eq ($this.PSVersn)) { $this.Set_Defaults() }
    [double]$MinVern = 5.1
    [double]$CrVersn = ($this.PSVersn | Select-Object @{l = 'vern'; e = { "{0}.{1}" -f $_.PSVersion.Major, $_.PSVersion.Minor } }).vern
    if ($null -ne ($this.colors)) {
      Write-Host ''; # i.e: Writing to the console in 24-bit colors can only work with PowerShell versions lower than '5.1'
      if ($CrVersn -gt $MinVern) {
        # Write-ColorOutput -ForegroundColor DarkCyan $($this.Default_Term_Ascii)
        Write-Host "$($this.Default_Term_Ascii)" -ForegroundColor Green
      } else {
        $this.Write_RGB($this.Default_Term_Ascii, 'SlateBlue')
      }
      Write-Host ''
    }
  }
  [void] Resolve_Module([string[]]$names) {
    if (!$(Get-Variable Resolve_Module_fn -ValueOnly -Scope global -ErrorAction Ignore)) {
      # Write-Verbose "Fetching the Resolve_Module script (One-time/Session only)";
      Set-Variable -Name Resolve_Module_fn -Scope global -Option ReadOnly -Value ([scriptblock]::Create($((Invoke-RestMethod -Method Get https://api.github.com/gists/7629f35f93ae89a525204bfd9931b366).files.'Resolve-Module.ps1'.content)))
    }
    . $(Get-Variable Resolve_Module_fn -ValueOnly -Scope global)
    Resolve-Module -Name $Names
  }
  [void] Write_RGB([string]$Text, $ForegroundColor) {
    $this.Write_RGB($Text, $ForegroundColor, $true)
  }
  [void] Write_RGB([string]$Text, [string]$ForegroundColor, [bool]$NoNewLine) {
    $this.Write_RGB($Text, $ForegroundColor, 'Black')
  }
  [void] Write_RGB([string]$Text, [string]$ForegroundColor, [string]$BackgroundColor) {
    $this.Write_RGB($Text, $ForegroundColor, $BackgroundColor, $true)
  }
  [void] Write_RGB([string]$Text, [string]$ForegroundColor, [string]$BackgroundColor, [bool]$NoNewLine) {
    $escape = [char]27 + '['; $24bitcolors = $this.colors
    $resetAttributes = "$($escape)0m";
    $psBuild = $this.PSVersn.PSVersion.Build
    [double]$VersionNum = $($this.PSVersn.PSVersion.ToString().split('.')[0..1] -join '.')
    if ([bool]$($VersionNum -le [double]5.1)) {
      [rgb]$Background = [rgb]::new(1, 36, 86);
      [rgb]$Foreground = [rgb]::new(255, 255, 255);
      $f = "$($escape)38;2;$($Foreground.Red);$($Foreground.Green);$($Foreground.Blue)m"
      $b = "$($escape)48;2;$($Background.Red);$($Background.Green);$($Background.Blue)m"
      $f = "$($escape)38;2;$($24bitcolors.$ForegroundColor.Red);$($24bitcolors.$ForegroundColor.Green);$($24bitcolors.$ForegroundColor.Blue)m"
      $b = "$($escape)48;2;$($24bitcolors.$BackgroundColor.Red);$($24bitcolors.$BackgroundColor.Green);$($24bitcolors.$BackgroundColor.Blue)m"
      if ([bool](Get-Command Write-Info -ErrorAction SilentlyContinue)) {
        Write-Info ($f + $b + $Text + $resetAttributes) -NoNewLine:$NoNewLine
      } else {
        Write-Host ($f + $b + $Text + $resetAttributes) -NoNewline:$NoNewLine
      }
    } else {
      throw [System.Management.Automation.RuntimeException]::new("Writing to the console in 24-bit colors can only work with PowerShell versions lower than '5.1 build 14931' or above.`nBut yours is '$VersionNum' build '$psBuild'")
    }
  }
  [PsObject] GetCurrentProces() {
    $chost = Get-Variable Host -ValueOnly; $process = Get-Process -Id $(Get-Variable pid -ValueOnly) | Get-Item
    $versionTable = Get-Variable PSVersionTable -ValueOnly
    return [PsObject]@{
      Path           = $process.Fullname
      FileVersion    = $process.VersionInfo.FileVersion
      PSVersion      = $versionTable.PSVersion.ToString()
      ProductVersion = $process.VersionInfo.ProductVersion
      Edition        = $versionTable.PSEdition
      Host           = $chost.name
      Culture        = $chost.CurrentCulture
      Platform       = $versionTable.platform
    }
  }
  [void] SetConsoleTitle([string]$Title) {
    $chost = Get-Variable Host -ValueOnly
    $width = ($chost.UI.RawUI.MaxWindowSize.Width * 2)
    if ($chost.Name -ne "ConsoleHost") {
      Write-Warning "This command must be run from a PowerShell console session. Not the PowerShell ISE or Visual Studio Code or similar environments."
    } elseif (($title.length -ge $width)) {
      Write-Warning "Your title is too long. It needs to be less than $width to fit your current console."
    } else {
      $chost.ui.RawUI.WindowTitle = $Title
    }
  }
  [hashtable] Get_Colors() {
    $c = @{}; [Color].GetProperties().Name.ForEach({ $c[$_] = [color]::$_ })
    return $c
  }
  hidden [void] Create_Prompt_Function() {
    # Creates the Custom prompt function & if nothing goes wrong then shows a welcome Ascii Art
    $this.CurrExitCode = $true
    try {
      # Creates the prompt function
      $null = New-Item -Path function:prompt -Value $([scriptblock]::Create({
            if (!$this.IsInitialised()) {
              Write-Verbose "[clistyle] Initializing, Please wait ..."
              $this.Initialize()
            }
            try {
              if ($NestedPromptLevel -ge 1) {
                $this.trailngChar += [string][char]9588
                # $this.leadingChar += [string][char]9592
              }
              # Grab th current loaction
              $location = "$((Get-Variable ExecutionContext).Value.SessionState.Path.CurrentLocation.Path)";
              $shortLoc = $this.Get_Short_Path($location, $this.dt)
              $IsGitRepo = if ([bool]$(try { Test-Path .git -ErrorAction silentlyContinue }catch { $false })) { $true }else { $false }
              $(Get-Variable Host).Value.UI.Write(($this.leadingChar))
              Write-Host -NoNewline $($this.b1);
              Write-Host $([Environment]::UserName).ToLower() -NoNewline -ForegroundColor Magenta;
              Write-Host $([string][char]64) -NoNewline -ForegroundColor Gray;
              Write-Host $([System.Net.Dns]::GetHostName().ToLower()) -NoNewline -ForegroundColor DarkYellow;
              Write-Host -NoNewline "$($this.b2) ";
              if ($location -eq "$env:UserProfile") {
                Write-Host $($this.Home_Indic) -NoNewline -ForegroundColor DarkCyan;
              } elseif ($location.Contains("$env:UserProfile")) {
                $location = $($location.replace("$env:UserProfile", "$($this.swiglyChar)"));
                if ($location.Length -gt 25) {
                  $location = $this.Get_Short_Path($location, $this.dt)
                }
                Write-Host $location -NoNewline -ForegroundColor DarkCyan
              } else {
                Write-Host $shortLoc -NoNewline -ForegroundColor DarkCyan
              }
              # add a newline
              if ($IsGitRepo) {
                Write-Host $((Write-VcsStatus) + "`n")
              } else {
                Write-Host "`n"
              }
            } catch {
              #Do this if a terminating exception happens#
              # if ($_.Exception.WasThrownFromThrowStatement) {
              #     [System.Management.Automation.ErrorRecord]$_ | Write-Log $($this.LogFile.FullName)
              # }
              $(Get-Variable Host).Value.UI.WriteErrorLine("[PromptError] [$($_.FullyQualifiedErrorId)] $($_.Exception.Message) # see the Log File : $($this.LogFile.FullName) $($this.nl)")
            } finally {
              #Do this after the try block regardless of whether an exception occurred or not
              Set-Variable -Name LASTEXITCODE -Scope Global -Value $($this.realLASTEXITCODE)
            }
            Write-Host ($this.trailngChar)
          }
        )
      ) -Force
      $this.CurrExitCode = $this.CurrExitCode -and $?
    } catch {
      $this.CurrExitCode = $false
      # Write-Log -ErrorRecord $_
    } finally {
      Set-Variable -Name IsPromptInitialised -Value $($this.CurrExitCode) -Visibility Public -Scope Global;
    }
  }
  hidden [string] Get_Short_Path() {
    $curr_location = $(Get-Variable ExecutionContext).Value.SessionState.Path.CurrentLocation.Path
    return $this.get_short_Path($curr_location, 2, 2, $this.DirSeparator, [char]8230)
  }
  hidden [string] Get_Short_Path([string]$Path) {
    return $this.get_short_Path($Path, 2, 2, $this.DirSeparator, [char]8230)
  }
  hidden [string] Get_Short_Path([string]$Path, [char]$TruncateChar) {
    return $this.get_short_Path($Path, 2, 2, $this.DirSeparator, $TruncateChar)
  }
  hidden [string] Get_Short_Path([string]$Path, [int]$KeepBefore, [int]$KeepAfter, [Char]$Separator, [char]$TruncateChar) {
    # [int]$KeepBefore, # Number of parts to keep before truncating. Default value is 2.
    # [int]$KeepAfter, # Number of parts to keep after truncating. Default value is 1.
    # [Char]$Separator, # Path separator character.
    $Path = (Resolve-Path -Path $Path).Path;
    $Path = $Path.Replace(([System.IO.Path]::DirectorySeparatorChar), $this.DirSeparator)
    [ValidateRange(1, [int32]::MaxValue)][int]$KeepAfter = $KeepAfter
    $Separator = $Separator.ToString(); $TruncateChar = $TruncateChar.ToString()
    $splitPath = $Path.Split($Separator, [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($splitPath.Count -gt ($KeepBefore + $KeepAfter)) {
      $outPath = [string]::Empty
      for ($i = 0; $i -lt $KeepBefore; $i++) {
        $outPath += $splitPath[$i] + $Separator
      }
      $outPath += "$($TruncateChar)$($Separator)"
      for ($i = ($splitPath.Count - $KeepAfter); $i -lt $splitPath.Count; $i++) {
        if ($i -eq ($splitPath.Count - 1)) {
          $outPath += $splitPath[$i]
        } else {
          $outPath += $splitPath[$i] + $Separator
        }
      }
    } else {
      $outPath = $splitPath -join $Separator
      if ($splitPath.Count -eq 1) {
        $outPath += $Separator
      }
    }
    return $outPath
  }
  hidden [System.IO.DirectoryInfo] Create_Directory([string]$Path) {
    $nF = @(); $d = [System.IO.DirectoryInfo]::New((Get-Variable ExecutionContext).Value.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path))
    ([ProgressUtil]::data.ShowProgress) ? (Write-Console "Creating Directory '$($d.FullName)' ..." -f DarkKhaki) : $null
    while (!$d.Exists) { $nF += $d; $d = $d.Parent }
    [Array]::Reverse($nF); $nF | ForEach-Object { $_.Create() }
    return $d
  }
}

class NetworkManager {
  [string] $HostName
  static [System.Net.IPAddress[]] $IPAddresses
  static [PsRecord] $DownloadOptions = @{
    ShowProgress      = $true
    ProgressBarLength = { return [int]([ConsoleWriter]::get_ConsoleWidth() * 0.7) }
    ProgressMessage   = [string]::Empty
    RetryTimeout      = 1000 #(milliseconds)
    Headers           = @{}
    Proxy             = $null
    Force             = $false
  }
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
    $HostOs = Get-HostOs
    if ($HostOs -eq "Linux") {
      sudo iptables -P OUTPUT DROP
    } else {
      netsh advfirewall set allprofiles firewallpolicy blockinbound, blockoutbound
    }
  }
  static [void] UnblockAllOutbound() {
    $HostOs = Get-HostOs
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
    $outPath = $outFile | xcrypt GetUnResolvedPath
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

class AsyncHandle {
  [Object]$AsyncState
  [WaitHandle]$AsyncWaitHandle
  [bool]$CompletedSynchronously
  [bool]$IsCompleted
  hidden $value
  AsyncHandle() {}
  AsyncHandle($object) {
    $object.PsObject.Properties.Foreach({ $this.($_.Name) = $o.($_.Name) })
    $this.value = $object
  }
}

class AsyncResult {
  [PowerShell] $Instance
  [AsyncHandle] $Handle
  AsyncResult($object) {
    # $object is expected to be of type System.Management.Automation.PowerShellAsyncResult
    $this.Instance = $object.Instance
    $this.Handle = $object.AsyncHandle
  }
}

class Activity : System.Diagnostics.Activity {
  [string]$StatusDescription
  [string]$OperationName
  [string]$TraceId
  Activity() {}
  Activity([string]$Name)  : Base($Name) {
    $this.OperationName = $Name
    $this.TraceId = ($Name | xconvert ToGuid).Guid
  }
  Activity([object[]]$desc) : Base(($desc[0] ? [string]$desc[0] : [string]::Empty)) {
    if ($desc[0]) {
      $this.OperationName = $desc[0]
      $this.TraceId = ([string]$desc[0] | xconvert ToGuid).Guid
    }
  }
  [string] ToString() {
    return '[{0}] {1}' -f $this.Status, $this.DisplayName
  }
}


class ActivityLog : PsRecord {
  ActivityLog() {}
  [void] Add([guid]$Id, [Activity]$Activity) {
    $this.Add(@{
        $Id = $Activity
      }
    )
  }
}

<#
.SYNOPSIS
  A simple progress utility class
.EXAMPLE
  for ($i = 0; $i -le 100; $i++) { [ProgressUtil]::WriteProgressBar($i, "doing stuff") }
.EXAMPLE
  [ProgressUtil]::WaitJob("waiting", { Start-Sleep -Seconds 3 });
.EXAMPLE
  $j = [ProgressUtil]::WaitJob("Waiting", { Param($ob) Start-Sleep -Seconds 3; return $ob }, (Get-Process pwsh));
  $j | Receive-Job

  NPM(K)    PM(M)      WS(M)     CPU(s)      Id  SI ProcessName
  ------    -----      -----     ------      --  -- -----------
        0     0.00     559.55      94.22   53184 …84 pwsh
        0     0.00     253.84       6.91   55195 …23 pwsh
.EXAMPLE
  Wait-Task -ScriptBlock { Start-Sleep -Seconds 3; $input | Out-String } -InputObject (Get-Process pwsh)
.EXAMPLE
  $RequestParams = @{
    Uri    = 'https://jsonplaceholder.typicode.com/todos/1'
    Method = 'GET'
  }
  $result = [ProgressUtil]::WaitJob("Making a request", { Param($rp) Start-Sleep -Seconds 2; Invoke-RestMethod @rp }, $RequestParams) | Receive-Job
  echo $result

  userId id title              completed
  ------ -- -----              ---------
      1  1 delectus aut autem     False
#>
class ProgressUtil {
  static [PsRecord] $data = @{
    ShowProgress     = { return (Get-Variable 'VerbosePreference' -ValueOnly) -eq 'Continue' }
    ProgressBarColor = "LightSeaGreen"
    ProgressMsgColor = "LightGoldenrodYellow"
    ProgressBlock    = '■'
    TwirlFrames      = ''
    TwirlEmojis      = [string[]]@(
      "◰◳◲◱",
      "◇◈◆",
      "◐◓◑◒",
      "←↖↑↗→↘↓↙",
      "┤┘┴└├┌┬┐",
      "⣾⣽⣻⢿⡿⣟⣯⣷",
      "|/-\\",
      "-\\|/",
      "|/-\\"
    )
  }
  static [void] WriteProgressBar([int]$percent) {
    [ProgressUtil]::WriteProgressBar($percent, $true, "")
  }
  static [void] WriteProgressBar([int]$percent, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $true, $message)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $update, [int]([ConsoleWriter]::get_ConsoleWidth() * 0.7), $message)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [string]$message, [bool]$Completed) {
    [ProgressUtil]::WriteProgressBar($percent, $update, [int]([ConsoleWriter]::get_ConsoleWidth() * 0.7), $message, $Completed)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $update, $PBLength, $message, $false)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength, [string]$message, [bool]$Completed) {
    [ProgressUtil]::WriteProgressBar($percent, $update, $PBLength, $message, $Completed, [ProgressUtil]::data.ProgressBarcolor)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength, [string]$message, [bool]$Completed, [string]$PBcolor) {
    if ([ProgressUtil]::data.ShowProgress) {
      [ValidateNotNull()][int]$PBLength = $PBLength; [ValidateNotNull()][int]$percent = $percent; $PmsgColor = [ProgressUtil]::data.ProgressMsgcolor
      [ValidateNotNull()][bool]$update = $update; [ValidateNotNull()][string]$message = $message;
      [ValidateScript( { return [bool][color]$_ })][string]$PmsgColor = $PmsgColor;
      [ValidateScript( { return [bool][color]$_ })][string]$PBcolor = $PBcolor;
      if ($update) { [Console]::Write(("`b" * [ConsoleWriter]::get_ConsoleWidth())) }
      Write-Console $message -f $PmsgColor -NoNewLine
      Write-Console " [" -f $PBcolor -NoNewLine
      $p = [int](($percent / 100.0) * $PBLength + 0.5)
      for ($i = 0; $i -lt $PBLength; $i++) {
        if ($i -ge $p) {
          Write-Console ' ' -NoNewLine
        } else {
          Write-Console ([ProgressUtil]::data.ProgressBlock) -f $PBcolor -NoNewLine
        }
      }
      Write-Console "] " -f $PBcolor -NoNewLine
      Write-Console ("{0,3:##0}%" -f $percent) -f $PmsgColor -NoNewLine:(!$Completed)
    }
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [scriptblock]$sb) {
    return [ProgressUtil]::WaitJob($progressMsg, $sb, $null)
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [System.Management.Automation.Job]$Job) {
    return [ProgressUtil]::WaitJob($progressMsg, $Job, [ProgressUtil]::data.ProgressMsgcolor)
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [System.Management.Automation.Job]$Job, [string]$PmsgColor) {
    [Console]::CursorVisible = $false; [ValidateScript( { return [bool][color]$_ })][string]$PmsgColor = $PmsgColor
    [ProgressUtil]::data.TwirlFrames = [ProgressUtil]::data.TwirlEmojis[0]; $PBcolor = [ProgressUtil]::data.ProgressBarcolor
    [ValidateScript( { return [bool][color]$_ })][string]$PBcolor = $PBcolor
    [int]$length = [ProgressUtil]::data.TwirlFrames.Length;
    $originalY = [Console]::CursorTop
    while ($Job.JobStateInfo.State -notin ('Completed', 'failed')) {
      for ($i = 0; $i -lt $length; $i++) {
        [ProgressUtil]::data.TwirlFrames.Foreach({
            Write-Console "$progressMsg" -NoNewLine -f $PmsgColor
            Write-Console " $($_[$i])" -NoNewLine -f $PBcolor
          })
        [System.Threading.Thread]::Sleep(50)
        Write-Console ("`b" * ($length + $progressMsg.Length)) -NoNewLine -f $PmsgColor
        [Console]::CursorTop = $originalY
      }
    }
    Write-Console "`b$progressMsg ... " -NoNewLine -f $PmsgColor
    [System.Management.Automation.Runspaces.RemotingErrorRecord[]]$Errors = $Job.ChildJobs.Where({
        $null -ne $_.Error
      }
    ).Error;
    if ($Job.JobStateInfo.State -eq "Failed" -or $Errors.Count -gt 0) {
      $errormessages = [string]::Empty
      if ($null -ne $Errors) {
        $errormessages = $Errors.Exception.Message -join "`n"
      }
      Write-Console "Completed with errors.`n`t$errormessages" -f Salmon
    } else {
      Write-Console "Done" -f Green
    }
    [Console]::CursorVisible = $true;
    return $Job
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [scriptblock]$sb, [Object[]]$ArgumentList) {
    $Job = ($null -ne $ArgumentList) ? (Start-ThreadJob -ScriptBlock $sb -ArgumentList $ArgumentList ) : (Start-ThreadJob -ScriptBlock $sb)
    return [ProgressUtil]::WaitJob($progressMsg, $Job)
  }
  static [void] ToggleShowProgress() {
    # .DESCRIPTION
    # The ShowProgress option respects $verbosepreference, this method enables you to take control of that and set/toggle it manualy.
    [ProgressUtil]::data.Set("ShowProgress", [scriptblock]::Create(" return [bool]$([int]![ProgressUtil]::data.ShowProgress)"))
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

class ThreadRunner {
  static [string] $Module = "clihelper.core"
  static [ErrorLog] $ErrorLog = [ErrorLog]::New()

  static [PSDataCollection[PsObject]] Run([string]$progressmsg, [scriptblock]$command, [object[]]$argumentlist) {
    return [ThreadRunner]::Run($progressmsg, $command, [string]::Empty, $argumentlist, $false, ((Get-Variable 'VerbosePreference' -ValueOnly) -eq 'Continue'))
  }
  static [PSDataCollection[PsObject]] Run([string]$progressmsg, [scriptblock]$command, [string]$MoreInfo, [object[]]$argumentlist) {
    return [ThreadRunner]::Run($progressmsg, $command, $MoreInfo, $argumentlist, $false, ((Get-Variable 'VerbosePreference' -ValueOnly) -eq 'Continue'))
  }
  static [PSDataCollection[PsObject]] Run([string]$progressmsg, [scriptblock]$command, [string]$MoreInfo, [object[]]$argumentlist, [bool]$throwOnFail, [bool]$verbose) {
    # .EXAMPLE
    # $result = [ThreadRunner]::Run("Making guid & some background stuff", { param([string]$str) Start-Sleep 3; return ($str | xconvert ToGuid) }, "some text")
    $a = $argumentlist ? $argumentlist : @()
    $j = [ProgressUtil]::WaitJob($progressmsg, $command, $a)
    $e = [PSDataCollection[ErrorRecord]]::new(); $j.Error.ForEach({ $e.Add($_) })
    $r = $j | Receive-Job -ErrorVariable threadErrors; $j.Dispose()
    (Get-Variable threadErrors).Value.ForEach({ $e.Add($_) });
    [ThreadRunner]::LogErrors($e, [ThreadRunner]::GetErrorMetadata($e, $MoreInfo), $throwOnFail)
    if ($verbose) { ($r | Out-String) + ' ' | Write-Console -f DarkSlateGray }
    if ($throwOnFail -and $e.Count -gt 0) { throw $e }
    return $r
  }
  static [void] LogErrors([PSDataCollection[ErrorRecord]]$ErrorRecords) {
    [ThreadRunner]::LogErrors($ErrorRecords, [string]::Empty)
  }
  static [void] LogErrors([PSDataCollection[ErrorRecord]]$ErrorRecords, [string]$MoreInfo) {
    [ThreadRunner]::LogErrors($ErrorRecords, [ThreadRunner]::GetErrorMetadata($ErrorRecords, $MoreInfo))
  }
  static [void] LogErrors([PSDataCollection[ErrorRecord]]$ErrorRecords, [ErrorMetadata]$metadata) {
    [ThreadRunner]::LogErrors($ErrorRecords, $metadata, $false)
  }
  static [void] LogErrors([PSDataCollection[ErrorRecord]]$ErrorRecords, [ErrorMetadata]$metadata, [bool]$throw) {
    if ($ErrorRecords.count -eq 0) { return } # log/record the error
    ![ThreadRunner]::ErrorLog ? ([ThreadRunner]::ErrorLog = [ErrorLog]::New()) : $null;
    $ErrorRecords.ForEach({
        $metadata.IsPrinted = !$throw
        $_.PsObject.Properties.Add([PSNoteProperty]::New("Metadata", $metadata))
        [void][ThreadRunner]::ErrorLog.Add($_)
      }
    )
    # "simple printf" or Write-TerminatingError
    $throw ? (throw $ErrorRecords) : $($ErrorRecords | Out-String | Write-Console -f LightCoral)
  }
  static [ErrorMetadata] GetErrorMetadata([PSDataCollection[ErrorRecord]]$ErrorRecords) {
    return [ThreadRunner]::GetErrorMetadata($ErrorRecords, [string]::Empty)
  }
  static [ErrorMetadata] GetErrorMetadata([PSDataCollection[ErrorRecord]]$ErrorRecords, [string]$MoreInfo) {
    return [ErrorMetadata]@{
      Timestamp      = [DateTime]::Now
      User           = $env:USER
      Module         = [ThreadRunner]::Module
      Severity       = 1
      StackTrace     = (($ErrorRecords.ScriptStackTrace | Out-String) + ' ').TrimEnd()
      AdditionalInfo = $MoreInfo + (($ErrorRecords.InvocationInfo.PositionMessage | Out-String) + ' ').TrimEnd()
    }
  }
}

<#
.SYNOPSIS
  PsRunner : Main class of the module
.DESCRIPTION
  Provides simple powerhsell multithreading implementation to run multible jobs in parallel.
.NOTES
  Author  : Alain Herve
  Created : <release_date>
  Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action ([PsRunner]::GetOnRemovalScript())

 .EXAMPLE
  $jobs = (
    { $res = "worker running on thread $([Threading.Thread]::CurrentThread.ManagedThreadId)"; Start-Sleep -Seconds 5; return $res },
    { return (Get-Variable PsRunner_* -ValueOnly) },
    { $res = "worker running on thread $([Threading.Thread]::CurrentThread.ManagedThreadId)"; 10..20 | Get-Random | ForEach-Object {  Start-Sleep -Milliseconds ($_ * 100) }; return $res }
  )
  # sync:
  # $res = [PsRunner]::Run($jobs)

  # Async:
  $handle = [PsRunner]::RunAsync($jobs);
  # do other stuff that you want
  $result = [PsRunner]::EndInvoke()

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
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
class PsRunner : ThreadRunner {
  hidden [int] $_MinThreads = 2
  hidden [int] $_MaxThreads = [PsRunner]::GetThreadCount()
  static [AsyncResult] $AsyncResult = @()
  static [Activity] $CurrentActivity = @()
  static [ActivityLog] $Log = @{}
  static [string] $SyncId = { [void][PsRunner]::SetSyncHash(); return [PsRunner].SyncId }.Invoke() # Unique ID for each runner instance

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
          if (![PsRunner]::GetSyncHash()["Instance"]) { [PsRunner].SyncHash["Instance"] = [PsRunner]::Create_runspace_manager() };
          return [PsRunner].SyncHash["Instance"]
        }, {
          throw [SetValueException]::new('Instance is read-only')
        }
      )
    )
    "PsRunner" | Update-TypeData -MemberName GetOutput -MemberType ScriptMethod -Value {
      $o = [PsRunner]::GetSyncHash()["Output"]; [PsRunner].SyncHash["Output"] = [System.Management.Automation.PSDataCollection[PsObject]]::new()
      [PsRunner].SyncHash["Runspaces"] = [ConcurrentDictionary[int, PowerShell]]::new()
      return $o
    } -Force;
  }
  static [PSDataCollection[PsObject]] Run() {
    $o = [PsRunner]::Run([PsRunner]::GetSyncHash()["Runspaces"]);
    [PsRunner].SyncHash["Output"] += $o;
    return $o
  }
  static [PSDataCollection[PsObject]] Run([scriptblock[]]$Jobs) {
    return [PsRunner]::Run("Running", "In Progress", $Jobs)
  }
  static [PSDataCollection[PsObject]] Run([string]$ActivityName, [string]$Description, [scriptblock[]]$Jobs) {
    if ([PsRunner]::HasPendingJobs()) { throw 'PsRunner has pending Jobs; run them or run [PsRunner]::CleanUp()' }
    [PsRunner]::CleanUp(); $Jobs.ForEach({ [PsRunner]::Add_BGWorker($_) })
    $o = [PsRunner]::Run($ActivityName, $Description, [PsRunner]::GetSyncHash()["Runspaces"]); [PsRunner].SyncHash["Output"] += $o; return $o
  }
  static [PSDataCollection[PsObject]] Run([ConcurrentDictionary[int, PowerShell]]$Runspaces) {
    return [PsRunner]::Run([PsRunner]::CurrentActivity.DisplayName, [PsRunner]::CurrentActivity.StatusDescription, $Runspaces)
  }
  static [PSDataCollection[PsObject]] Run([string]$ActivityName, [string]$Description, [ConcurrentDictionary[int, PowerShell]]$Runspaces) {
    if (![PsRunner]::HasPendingJobs()) {
      Write-Warning "There are no pending jobs. Please run GetOutput(); and Add_BGWorker(); then try again."
      return $null
    }
    [ValidateNotNullOrWhiteSpace()][string]$Description = $Description
    [ValidateNotNullOrWhiteSpace()][string]$ActivityName = $ActivityName
    [PsRunner].SyncHash["Runspaces"] = $Runspaces
    [PsRunner]::CurrentActivity.DisplayName = $ActivityName
    [void][PsRunner]::CurrentActivity.SetStartTime([datetime]::Now)
    [void][PsRunner]::CurrentActivity.SetStatus("Ok")
    [PsRunner]::CurrentActivity.StatusDescription = $Description
    $i = 0; $Handle = [PsRunner].Instance.BeginInvoke()
    while ($Handle.IsCompleted -eq $false) {
      Start-Sleep -Milliseconds 500
      Write-Progress -Activity ([PsRunner]::CurrentActivity.DisplayName) -Status ([PsRunner]::CurrentActivity.StatusDescription) -PercentComplete $($i % 100)
      $i += 5
    }
    [void][PsRunner]::CurrentActivity.SetEndTime([datetime]::Now)
    [void][PsRunner]::Log.Add(($ActivityName | xconvert ToGuid), [PsRunner]::CurrentActivity)
    [void][PsRunner]::CurrentActivity.SetStatus("Unset")
    [PsRunner]::CurrentActivity.DisplayName = $null
    [PsRunner]::CurrentActivity.StatusDescription = $null
    return [PsRunner].Instance.EndInvoke($Handle)
  }
  static [AsyncResult] RunAsync() {
    return [PsRunner]::RunAsync([PsRunner]::GetSyncHash()["Runspaces"])
  }
  static [AsyncResult] RunAsync([scriptblock[]]$Jobs) {
    if ([PsRunner]::HasPendingJobs()) {
      throw 'PsRunner has pending Jobs; run them or run [PsRunner]::CleanUp()'
    }
    [PsRunner]::CleanUp(); $Jobs.ForEach({ [PsRunner]::Add_BGWorker($_) })
    return [PsRunner]::RunAsync([PsRunner]::GetSyncHash()["Runspaces"])
  }
  static [AsyncResult] RunAsync([ConcurrentDictionary[int, PowerShell]]$Runspaces) {
    if (![PsRunner]::HasPendingJobs()) {
      Write-Warning "There are no pending jobs. Please run GetOutput(); and Add_BGWorker(); then try again.";
      return $null
    }
    [PsRunner]::GetSyncHash()["Runspaces"] = $Runspaces
    [PsRunner]::AsyncResult.Handle = [IAsyncResult][PsRunner].Instance.BeginInvoke()
    [PsRunner]::AsyncResult.Instance = [PsRunner].Instance
    return [PsRunner]::AsyncResult
  }
  static [PSDataCollection[PsObject]] EndInvoke() {
    if (![PsRunner]::AsyncResult) {
      throw "No AsyncResult result found"
    }
    if ($null -eq [PsRunner]::AsyncResult.Instance) {
      throw 'No Async instance found! ::RunAsync($Jobs) and try again.'
    }
    return [PsRunner].Instance.EndInvoke([PsRunner]::AsyncResult.Handle.value)
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
  static [void] Add_BGWorker([ScriptBlock]$Worker) {
    [PsRunner]::Add_BGWorker([PsRunner]::GetWorkerId(), $Worker, @())
  }
  static [void] Add_BGWorker([int]$Id, [ScriptBlock]$Worker, [object[]]$Arguments) {
    [void][PsRunner]::Isvalid_NewRunspaceId($Id)
    $ps = [powershell]::Create([PsRunner]::CreateRunspace())
    $ps = $ps.AddScript($Worker)
    if ($Arguments.Count -gt 0) { $Arguments.ForEach({ [void]$ps.AddArgument($_) }) }
    # $ps.RunspacePool = [PsRunner].SyncHash["RunspacePool"] # https://github.com/PowerShell/PowerShell/issues/18934
    # Save each Worker in a dictionary, ie: {Int_Id, PowerShell_instance_on_different_thread}
    if (![PsRunner]::GetSyncHash()["Runspaces"].TryAdd($Id, $ps)) { throw [System.InvalidOperationException]::new("worker $Id already exists.") }
    [PsRunner].SyncHash["Jobs"][$Id] = @{
      __PS   = ([ref]$ps).Value
      Status = ([ref]$ps).Value.Runspace.RunspaceStateInfo.State
      Result = $null
    }
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
              Runspaces   = [ConcurrentDictionary[int, PowerShell]]::new()
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
  static [PowerShell] Create_runspace_manager() {
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
    $j = [PsRunner]::GetSyncHash()["Jobs"]
    return (($j.count -gt 0) ? $j.Values.Keys.Contains("__PS") : $false)
  }
  static [void] CleanUp() {
    [PsRunner].SyncHash.Jobs.Clear()
    # [PsRunner].SyncHash["Instance"] = [PsRunner]::Create_runspace_manager()
    $rs = [PsRunner]::GetSyncHash()["Runspaces"]
    [PsRunner].SyncHash.Runspaces = [ConcurrentDictionary[int, PowerShell]]::new();
    $rs.keys.Where({ $rs[$_].InvocationStateInfo.State -ne "Completed" }).Foreach({ [PsRunner].SyncHash.Runspaces[$_] = $rs[$_] })
    if ([PsRunner].SyncHash.Results) { [PsRunner].SyncHash.Results = @() }
    if ([PsRunner].SyncHash.Output) { [PsRunner].SyncHash.Output = [PSDataCollection[PsObject]]::new() }
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
  [NetworkManager], [InstallRequirements], [clistyle], [HostOS],
  [Requirement], [RGB], [color], [ProgressUtil], [ConsoleReader],
  [InstallException], [InstallFailedException], [Activity], [AsyncResult], [FontMan],
  [ErrorMetadata], [ExceptionType], [ErrorSeverity], [ErrorLog], [ErrorManager], [ConsoleWriter],
  [StackTracer], [ShellConfig], [dotProfile], [PsRunner], [ThreadRunner], [PsRecord], [cli], [cliart], [ActivityLog]
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