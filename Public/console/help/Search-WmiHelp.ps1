function Search-WmiHelp {
  param(
    [ScriptBlock]$DescriptionExpression = {},

    [ScriptBlock]$MethodExpression = {},

    [ScriptBlock]$PropertyExpression = {},

    $Namespaces = "root\cimv2",

    $CultureID = (Get-Culture).LCID,

    [switch]$List
  )

  $resultWmiClasses = @{}

  foreach ($namespace in $Namespaces) {
    #First, get a list of all localized namespaces under the current namespace

    $localizedNamespace = Get-LocalizedNamespace $namespace
    if ($null -eq $localizedNamespace) {
      Write-Verbose "Could not get a list of localized namespaces"
      return
    }

    $localizedClasses = Get-CimInstance -NameSpace $localizedNamespace -Query "select * from meta_class"
    $count = 0
    foreach ($WmiClass in $localizedClasses) {
      $count++
      Write-Progress "Searching Wmi Classes" "$count of $($localizedClasses.Count)" -PercentComplete ($count * 100 / $localizedClasses.Count)
      $classLocation = $localizedNamespace + ':' + $WmiClass.__Class
      $classInfo = Get-WmiClassInfo $classLocation
      [bool]$found = $false
      if ($null -ne $classInfo) {
        if (! $resultWmiClasses.ContainsKey($classLocation)) {
          $resultWmiClasses.Add($wmiClass.__Class, $classInfo)
        }

        $descriptionMatch = [bool]($classInfo.Description | Where-Object $DescriptionExpression)
        $methodMatch = [bool]($classInfo.Methods.GetEnumerator() | Where-Object $MethodExpression)
        $propertyMatch = [bool]($classInfo.Properties.GetEnumerator() | Where-Object $PropertyExpression)

        $found = $descriptionMatch -or $methodMatch -or $propertyMatch

        if (! $found) {
          $resultWmiClasses.Remove($WmiClass.__Class)
        }
      }
    }
  }

  if ($List) {
    $resultWmiClasses.Keys | Sort-Object
  } else {
    $resultWmiClasses.GetEnumerator() | Sort-Object Key
  }
}