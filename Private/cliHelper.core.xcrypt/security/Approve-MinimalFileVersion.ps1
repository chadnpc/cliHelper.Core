function Approve-MinimalFileVersion {
  <#
    .SYNOPSIS
        A short one-line action-based description, e.g. 'Tests if a function is valid'
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        -LDRGDR switch:
           Adds a logic to work with fixes (like Security hotfixes), which both LDR and GDR versions of a binary is deployed as part of the hotfix
        -ForceMajorCheck switch:
           Usually if a fix applies to a specific OS version, the script returns $true. You can force checking the Major version by using this switch
        -ForceMinorCheck switch:
           Usually if a fix applies to a specific Service Pack version, we just return $true. You can ignore always returning $true and making the actual binary check by using this switch
        -ForceBuildCheck switch:
           Usually if a fix applies to a specific OS version, we just return $true. You can ignore always returning $true and making the actual binary check by using this switch.
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        Approve-MinimalFileVersion "$env:windir\system32\Bfe.dll" 6 2 9200 16451 -LDRGDR
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    #>
  [CmdletBinding()]
  param (
    [Parameter(Position = 0)]
    [string]$Binary,

    [Parameter(Position = 1)]
    $RequiredMajor,

    [Parameter(Position = 2)]
    $RequiredMinor,

    [Parameter(Position = 3)]
    $RequiredBuild,

    [Parameter(Position = 4)]

    [Parameter(Position = 5)]
    $RequiredFileBuild,

    [switch]$LDRGDR,
    [switch]$ForceMajorCheck,
    [switch]$ForceMinorCheck,
    [switch]$ForceBuildCheck,
    [switch]$CheckFileExists
  )

  process {
    if (Test-Path -Path $Binary) {
      $StdoutDisplay = ''
      $FileVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Binary)
      # If the version numbers from the binary is different than the OS version - it means the file is probably not a inbox component.
      # In this case, set the $ForceMajorCheck, $ForceBuildCheck and $ForceBuildCheck to $true automatically
      if (($FileVersionInfo.FileMajorPart -ne $OSVersion.Major) -and ($FileVersionInfo.FileMinorPart -ne $OSVersion.Minor) -and ($FileVersionInfo.FileBuildPart -ne $OSVersion.Build)) {
        $ForceBuildCheck = $true
        $ForceMinorCheck = $true
        $ForceMajorCheck = $true
      }
      if ($ForceMajorCheck) {
        $StdoutDisplay = '(Force Major Check)'
      }
      if ($ForceMinorCheck) {
        $ForceMajorCheck = $true
        $StdoutDisplay = '(Force Minor Check)'
      }
      if ($ForceBuildCheck) {
        $ForceMajorCheck = $true
        $ForceMinorCheck = $true
        $StdoutDisplay = '(Force Build Check)'
      }
      if ((($ForceMajorCheck.IsPresent) -and ($FileVersionInfo.FileMajorPart -eq $RequiredMajor)) -or (($ForceMajorCheck.IsPresent -eq $false) -and ($FileVersionInfo.FileMajorPart -eq $RequiredMajor))) {
        if ((($ForceMinorCheck.IsPresent) -and ($FileVersionInfo.FileMinorPart -eq $RequiredMinor)) -or (($ForceMinorCheck.IsPresent -eq $false) -and ($FileVersionInfo.FileMinorPart -eq $RequiredMinor))) {
          if (($ForceBuildCheck.IsPresent) -and ($FileVersionInfo.FileBuildPart -eq $RequiredBuild) -or (($ForceBuildCheck.IsPresent -eq $false) -and ($FileVersionInfo.FileBuildPart -eq $RequiredBuild))) {
            #Check if -LDRGDR was specified - in this case run the LDR/GDR logic
            #For Windows Binaries, we need to check if current binary is LDR or GDR for fixes:
            if (($LDRGDR.IsPresent) -and ($FileVersionInfo.FileMajorPart -ge 6) -and ($FileVersionInfo.FileBuildPart -ge 6000)) {
              #Check if the current version of the file is GDR or LDR:
              if ((($FileVersionInfo.FilePrivatePart.ToString().StartsWith(16)) -and (($RequiredFileBuild.ToString().StartsWith(16)) -or ($RequiredFileBuild.ToString().StartsWith(17)))) -or
							(($FileVersionInfo.FilePrivatePart.ToString().StartsWith(17)) -and ($RequiredFileBuild.ToString().StartsWith(17))) -or
							(($FileVersionInfo.FilePrivatePart.ToString().StartsWith(18)) -and ($RequiredFileBuild.ToString().StartsWith(18))) -or
							(($FileVersionInfo.FilePrivatePart.ToString().StartsWith(20)) -and ($RequiredFileBuild.ToString().StartsWith(20))) -or
							(($FileVersionInfo.FilePrivatePart.ToString().StartsWith(21)) -and ($RequiredFileBuild.ToString().StartsWith(21))) -or
							(($FileVersionInfo.FilePrivatePart.ToString().StartsWith(22)) -and ($RequiredFileBuild.ToString().StartsWith(22)))
              ) {
                #File and requests are both GDR or LDR - check the version in this case:
                if ($FileVersionInfo.FilePrivatePart -ge $RequiredFileBuild) {
                  $VersionBelowRequired = $false
                } else {
                  $VersionBelowRequired = $true
                }
              } else {
                #File is either LDR and Request is GDR - Return true always:
                $VersionBelowRequired = $false
                return $true
              }
            } elseif ($FileVersionInfo.FilePrivatePart -ge $RequiredFileBuild) {
              #All other cases, perform the actual check
              $VersionBelowRequired = $false
            } else {
              $VersionBelowRequired = $true
            }
          } else {
            if ($ForceBuildCheck.IsPresent) {
              $VersionBelowRequired = ($FileVersionInfo.FileBuildPart -lt $RequiredBuild)
            } else {
              "[CheckFileVersion] $StdoutDisplay $Binary version is " + (Get-FileVersionString($Binary)) + " - Required version (" + $RequiredMajor + "." + $RequiredMinor + "." + $RequiredBuild + "." + $RequiredFileBuild + ") applies to a newer Service Pack - OK" | writeto-stdout -shortformat
              return $true
            }
          }
        } else {
          if ($ForceMinorCheck.IsPresent) {
            $VersionBelowRequired = ($FileVersionInfo.FileMinorPart -lt $RequiredMinor)
          } else {
            "[CheckFileVersion] $StdoutDisplay $Binary version is " + (Get-FileVersionString($Binary)) + " - and required version (" + $RequiredMajor + "." + $RequiredMinor + "." + $RequiredBuild + "." + $RequiredFileBuild + ") applies to a different Operating System Version - OK" | writeto-stdout -shortformat
            return $true
          }
        }
      } else {
        if ($ForceMajorCheck.IsPresent -eq $false) {
          "[CheckFileVersion] $StdoutDisplay $Binary version is " + (Get-FileVersionString($Binary)) + " - and required version (" + $RequiredMajor + "." + $RequiredMinor + "." + $RequiredBuild + "." + $RequiredFileBuild + ") applies to a different Operating System Version - OK" | writeto-stdout -shortformat
          return $true
        } else {
          $VersionBelowRequired = ($FileVersionInfo.FileMajorPart -lt $RequiredMajor)
        }
      }
      if ($VersionBelowRequired) {
        "[CheckFileVersion] $StdoutDisplay $Binary version is " + (Get-FileVersionString($Binary)) + " and required version is $RequiredMajor" + "." + $RequiredMinor + "." + $RequiredBuild + "." + $RequiredFileBuild | writeto-stdout -shortformat
        return $false
      } else {
        "[CheckFileVersion] $StdoutDisplay $Binary version is " + $FileVersionInfo.FileMajorPart + "." + $FileVersionInfo.FileMinorPart + "." + $FileVersionInfo.FileBuildPart + "." + $FileVersionInfo.FilePrivatePart + " and required version is " + $RequiredMajor + "." + $RequiredMinor + "." + $RequiredBuild + "." + $RequiredFileBuild + " - OK" | writeto-stdout -shortformat
        return $true
      }
    } else {
      if ($CheckFileExists.IsPresent) {
        "[CheckFileVersion] $Binary does not exist. Returning 'false' as  -CheckFileExists switch was used" | writeto-stdout -shortformat
        return $false
      }
      return $true
    }
  }

  end {

  }
}
