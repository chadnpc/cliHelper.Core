using namespace System.Text
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Text.Json.Serialization
using namespace System.Collections.Specialized

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
  RGB($r, $g, $b) {
    $this.Red = $r
    $this.Green = $g
    $this.Blue = $b
  }
  [string] ToString() {
    return "$($this.Red),$($this.Green),$($this.Blue)"
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
  static [ValidateNotNullOrEmpty()][string]$Banner
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
  static [ValidateNotNullOrEmpty()][ShellConfig]$Config = [ShellConfig]::new()
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
  [xcResult] static Install([string]$Path) {
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
      $Result = [xcResult]::New(
        $Output,
        $IsSuccess,
        $ErrorRecord
      )
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
    [dotProfile]::Banner = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('bSUBJQElASVuJW0lbiUgACAAIAAgACAAIAAgAG0lASUBJQElbiVtJW4lCgADJW0lASVuJQMlAyUDJSAAIAAgAG0lbiUgACAAAyVtJQElbiUDJW8lcCVuJQoAAyUDJSAAAyUDJQMlbSUBJQElbiVtJW4lASVuJQMlAyUgAAMlAyVuJW0lbSUBJQElbiUBJQElbiUKAAMlcCUBJW8lAyUDJQMlbSUgAAMlfAADJW0lbiVuJQMlIAADJQMlAyUDJXwAbSVuJQMlbSUBJW8lCgADJW0lASVuJQMlAyVwJXAlbyVwJW4lAyUDJQMlAyVwJQElbyUDJQMlcCVuJQMlASUrJXAlASVuJQoAcCVvJSAAcCVvJXAlASVvJQElASVvJW8lbyVwJW8lASUBJW4lcCUBJQElbyUBJQElbyUBJQElbyUKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIABwJW8lCgAiAFEAdQBpAGMAawAgAHAAcgBvAGQAdQBjAHQAaQB2AGUAIAB0AGUAYwBoACIA'));
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

class xcResult : PsObject {
  xcResult(
    $Output,
    [bool]$IsSuccess,
    [System.Management.Automation.ErrorRecord]$ErrorRecord
  ) {
    $this.Output = $Output
    $this.IsSuccess = $IsSuccess
    $this.ErrorRecord = $ErrorRecord
  }
}