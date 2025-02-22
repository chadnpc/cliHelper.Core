function Get-ObjectVendor {
  [CmdletBinding()]
  param(
    [System.Type]$Type
    ,
    [switch]$CompanyOnly
  )

  $Assembly = $Type.Assembly
  $attrib = $Assembly.GetCustomAttributes([Reflection.AssemblyCompanyAttribute], $false) | Select-Object -First 1

  if ($attrib.Company) {
    return $attrib.Company
  } else {
    if ($CompanyOnly) { return }

    # try copyright
    $attrib = $Assembly.GetCustomAttributes([Reflection.AssemblyCopyrightAttribute], $false) | Select-Object -First 1

    if ($attrib.Copyright) {
      return $attrib.Copyright
    }
  }
  $PSCmdlet.WriteVerbose("Assembly has no [AssemblyCompany] or [AssemblyCopyright] attributes.")
}
