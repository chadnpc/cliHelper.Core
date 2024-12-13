function Get-LocalizedNamespace {
  param(
    $NameSpace
    ,
    [int]$cultureID = (Get-Culture).LCID
  )

  #First, get a list of all localized namespaces under the current namespace
  $localizedNamespaces = Get-CimInstance -NameSpace $NameSpace -Class "__Namespace" | Where-Object { $_.Name -like "ms_*" }
  if ($null -eq $localizedNamespaces) {
    if (!$quiet) {
      Write-Warning "Could not get a  list of localized namespaces"
    }
    return
  }

  return ("$namespace\ms_{0:x}" -f $cultureID)
}