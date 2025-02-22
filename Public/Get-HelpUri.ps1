function Get-HelpUri {
  [CmdletBinding()]
  param(
    [System.Type]$Type,

    [String]$Member
  )

  ## Needed for UrlEncode()
  Add-Type -AssemblyName System.Web

  $Vendor = Get-ObjectVendor $Type
  if ($Vendor -like "*Microsoft*") {
    ## drop locale - site will redirect to correct variation based on browser accept-lang
    $Suffix = ""
    if ($Member -eq "_members") {
      $Suffix = "_members"
    } elseif ($Member) {
      $Suffix = ".$Member"
    }

    $Query = [System.Web.HttpUtility]::UrlEncode(("{0}{1}" -f $Type.FullName, $Suffix))
    New-Object System.Uri "http://msdn.microsoft.com/library/$Query.aspx"
  } else {
    $Suffix = ""
    if ($Member -eq "_members") {
      $Suffix = " members"
    } elseif ($Member) {
      $Suffix = ".$Member"
    }

    if ($Vendor) {
      $Query = [System.Web.HttpUtility]::UrlEncode(("`"{0}`" {1}{2}" -f $Vendor, $Type.FullName, $Suffix))
    } else {
      $Query = [System.Web.HttpUtility]::UrlEncode(("{0}{1}" -f $Type.FullName, $Suffix))
    }
    New-Object System.Uri "http://www.bing.com/results.aspx?q=$Query"
  }
}