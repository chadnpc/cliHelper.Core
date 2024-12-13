function Get-CimUri {
  [CmdletBinding()]
  param(
    [Microsoft.Management.Infrastructure.CimClass]$Type,
    [String]$Method,
    [String]$Property
  )

  $Culture = $Host.CurrentCulture.Name
  $TypeName = $Type.CimClassName -replace "_", "-"
  if ($Method) {
    # $Page = "$TypeName#methods"
    $Page = "$Method-method-in-class-$TypeName"
  } elseif ($Property) {
    $Page = "$TypeName#properties"
  } else {
    $Page = $TypeName
  }
  New-Object System.Uri "https://docs.microsoft.com/$Culture/windows/desktop/CIMWin32Prov/$Page"
}
