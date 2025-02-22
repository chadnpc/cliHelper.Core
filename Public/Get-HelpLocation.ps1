function Get-HelpLocation {
  [CmdletBinding()]
  param(
    [System.Type]$Type
  )

  # get documentation filename, assembly location and assembly codebase
  $DocFilename = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetFileName($Type.Assembly.Location), ".xml")
  $Location = [System.IO.Path]::GetDirectoryName($Type.Assembly.Location)
  $CodeBase = (New-Object System.Uri $Type.Assembly.CodeBase).LocalPath

  $PSCmdlet.WriteVerbose("Documentation file is '$DocFilename.'")

  ## try localized location (typically newer than base framework dir)
  $FrameworkDir = "${env:windir}\Microsoft.NET\framework\v2.0.50727"
  $Language = [System.Globalization.CultureInfo]::CurrentUICulture.Parent.Name

  foreach ($Path in "$FrameworkDir\$Language\$DocFilename",
    "$FrameworkDir\$DocFilename",
    "$Location\$DocFilename",
    "$CodeBase\$DocFilename") {
    if (Test-Path $Path) {
      return $Path
    }
  }

  # if (!$Online.IsPresent)
  # {
  #     # try localized location (typically newer than base framework dir)
  #     $frameworkDir = "${env:windir}\Microsoft.NET\framework\v2.0.50727"
  #     $lang = [system.globalization.cultureinfo]::CurrentUICulture.parent.name

  #     # I love looking at this. A Duff's Device for PowerShell.. well, maybe not.
  #     switch
  #         (
  #         "${frameworkdir}\${lang}\$docFilename",
  #         "${frameworkdir}\$docFilename",
  #         "$location\$docFilename",
  #         "$codebase\$docFilename"
  #         )
  #     {
  #         { test-path $_ } { $_; return; }

  #         default
  #         {
  #             # try next path
  #             continue;
  #         }
  #     }
  # }

  # # failed to find local docs, is it from MS?
  # if ((Get-ObjectVendor $type) -like "*Microsoft*")
  # {
  #     # drop locale - site will redirect to correct variation based on browser accept-lang
  #     $suffix = ""
  #     if ($Members.IsPresent)
  #     {
  #         $suffix = "_members"
  #     }

  #     new-object uri ("http://msdn.microsoft.com/library/{0}{1}.aspx" -f $type.fullname,$suffix)

  #     return
  # }
}
