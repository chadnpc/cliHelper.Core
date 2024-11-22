function Get-NetHelp {
  [CmdletBinding(DefaultParameterSetName = "Class")]
  param(
    [Parameter(Position = 0)]
    [ValidateNotNull()]
    [System.Type]$Type,

    [Parameter(ParameterSetName = "Class")]
    [switch]$Detailed,

    [Parameter(ParameterSetName = "Property")]
    [string]$Property,

    [Parameter(ParameterSetName = "Method")]
    [string]$Method
  )

  # if ($Docs = Get-HelpLocation $Type) {
  #     $PSCmdlet.WriteVerbose("Found '$Docs'.")

  #     $TypeName = $Type.FullName
  #     if ($Method) {
  #         $Selector = "M:$TypeName.$Method"
  #     } else {  ## TODO:  Property?
  #         $Selector = "T:$TypeName"
  #     }

  #     ## get summary, if possible
  #     $Help = Import-LocalNetHelp $Docs $Selector

  #     if ($Help) {
  #         $Help #| Format-AssemblyHelp
  #     } else {
  #         Write-Warning "While some local documentation was found, it was incomplete."
  #     }
  # }

  $HelpUrl = Get-HelpUri $Type
  $HelpObject = New-Object PSObject -Property @{
    Details      = New-Object PSObject -Property @{
      Name       = $Type.Name
      Namespace  = $Type.Namespace
      SuperClass = $Type.BaseType
    }
    Properties   = @{}
    Constructors = @()
    Methods      = @{}
    RelatedLinks = @(
      New-Object PSObject -Property @{Title = "Online Version"; Link = $HelpUrl }
    )
  }
  $HelpObject.Details.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Details")
  $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo")
  if ($Detailed) {
    $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#DetailedView")
    # Write-Error "Local detailed help not available for type '$Type'."
  } else {
    $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net")
  }

  foreach ($NetProperty in $Type.DeclaredProperties) {
    $PropertyObject = New-Object PSObject -Property @{
      Name = $NetProperty.Name
      Type = $NetProperty.PropertyType
    }
    $PropertyObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#Property")
    $HelpObject.Properties.Add($NetProperty.Name, $PropertyObject)
  }

  foreach ($NetConstructor in $Type.DeclaredConstructors | Where-Object { $_.IsPublic }) {
    $ConstructorObject = New-Object PSObject -Property @{
      Name       = $Type.Name
      Namespace  = $Type.Namespace
      Parameters = $NetConstructor.GetParameters()
    }
    $ConstructorObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#Constructor")

    $HelpObject.Constructors += $ConstructorObject
  }

  foreach ($NetMethod in $Type.DeclaredMethods | Where-Object { $_.IsPublic -and (!$_.IsSpecialName) } | Group-Object Name) {
    $MethodObject = New-Object PSObject -Property @{
      Name        = $NetMethod.Name
      Static      = $NetMethod.Group[0].IsStatic
      Constructor = $NetMethod.Group[0].IsConstructor
      ReturnType  = $NetMethod.Group[0].ReturnType
      Overloads   = @(
        $NetMethod.Group | ForEach-Object {
          $MethodOverload = New-Object PSObject -Property @{
            Name       = $NetMethod.Name
            Static     = $_.IsStatic
            ReturnType = $_.ReturnType
            Parameters = @(
              $_.GetParameters() | ForEach-Object {
                New-Object PSObject -Property @{
                  Name          = $_.Name
                  ParameterType = $_.ParameterType
                }
              }
            )
            Class      = $HelpObject.Details.Name
            Namespace  = $HelpObject.Details.Namespace
          }
          $MethodOverload.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#MethodOverload")
          $MethodOverload
        }
      )
    }
    $MethodObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#Method")

    $HelpObject.Methods.Add($NetMethod.Name, $MethodObject)
  }

  $DownloadOnlineHelp = $true
  if ($Property) {
    $PropertyObject = $HelpObject.Properties[$Property]

    if ($PropertyObject) {
      $PropertyHelpUrl = Get-HelpUri $Type -Member $Property
      Add-Member -InputObject $PropertyObject -Name Class -Value $HelpObject.Details.Name -MemberType NoteProperty
      Add-Member -InputObject $PropertyObject -Name Namespace -Value $HelpObject.Details.Namespace -MemberType NoteProperty
      Add-Member -InputObject $PropertyObject -Name SuperClass -Value $HelpObject.Details.SuperClass -MemberType NoteProperty
      Add-Member -InputObject $PropertyObject -Name RelatedLinks -Value @(New-Object PSObject -Property @{Title = "Online Version"; Link = $PropertyHelpUrl }) -MemberType NoteProperty
      $PropertyObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#PropertyDetail")

      if ($DownloadOnlineHelp) {
        $OnlineHelp = Import-OnlineHelp $PropertyHelpUrl
        if ($OnlineHelp) {
          Add-Member -InputObject $PropertyObject -Name Summary -Value $OnlineHelp.Summary -MemberType NoteProperty
        }
      }

      return $PropertyObject
    } else {
      throw "Property named '$Property' not found."
    }
  } elseif ($Method) {
    $MethodObject = $HelpObject.Methods[$Method]

    if ($MethodObject) {
      $MethodHelpUrl = Get-HelpUri $Type -Member $Method
      Add-Member -InputObject $MethodObject -Name Class -Value $HelpObject.Details.Name -MemberType NoteProperty
      Add-Member -InputObject $MethodObject -Name Namespace -Value $HelpObject.Details.Namespace -MemberType NoteProperty
      Add-Member -InputObject $MethodObject -Name SuperClass -Value $HelpObject.Details.SuperClass -MemberType NoteProperty
      Add-Member -InputObject $MethodObject -Name RelatedLinks -Value @(New-Object PSObject -Property @{Title = "Online Version"; Link = $MethodHelpUrl }) -MemberType NoteProperty
      $MethodObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#MethodDetail")

      if ($DownloadOnlineHelp) {
        $OnlineHelp = Import-OnlineHelp $MethodHelpUrl
        if ($OnlineHelp) {
          Add-Member -InputObject $MethodObject -Name Summary -Value $OnlineHelp.Summary -MemberType NoteProperty
        }
      }

      return $MethodObject
    } else {
      throw "Method named '$Method' not found."
    }
  } else {
    if ($DownloadOnlineHelp) {
      $OnlineHelp = Import-OnlineHelp $HelpUrl
      if ($OnlineHelp) {
        Add-Member -InputObject $HelpObject.Details -Name Summary -Value $OnlineHelp.Summary -MemberType NoteProperty
      }
    }
    return $HelpObject
  }
}
function Get-CimHelp {
  [CmdletBinding(DefaultParameterSetName = "Class")]
  param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$Class
    ,
    [string]$Namespace = "ROOT\cimv2"
    ,
    [Parameter(ParameterSetName = "Class")]
    [switch]$Detailed
    ,
    [Parameter(ParameterSetName = "Property")]
    [string]$Property
    ,
    [Parameter(ParameterSetName = "Method")]
    [string]$Method
  )

  $HelpUrl = Get-CimUri -Type $Type -Method $Method -Property $Property

  $CimClass = Get-CimClass $Class -Namespace $Namespace
  $LocalizedClass = Get-WmiClassInfo $Class -Namespace $Namespace

  $HelpObject = New-Object PSObject -Property @{
    Details      = New-Object PSObject -Property @{
      Name        = $CimClass.CimClassName
      Namespace   = $CimClass.CimSystemProperties.Namespace
      SuperClass  = $CimClass.CimSuperClass.ToString()
      Description = @($LocalizedClass.Qualifiers["Description"].Value -split "`n" | ForEach-Object {
          $Paragraph = New-Object PSObject -Property @{Text = $_.Trim() }
          $Paragraph.PSObject.TypeNames.Insert(0, "CimParaTextItem")
          $Paragraph
        })
    }
    Properties   = @{}
    Methods      = @{}
    RelatedLinks = @(
      New-Object PSObject -Property @{Title = "Online Version"; Link = $HelpUrl }
    )
  }
  $HelpObject.Details.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Details")
  $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo")
  $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim")
  if ($Detailed) {
    $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim#DetailedView")
  }

  foreach ($CimProperty in $LocalizedClass.Properties) {
    $PropertyObject = New-Object PSObject -Property @{
      Name         = $CimProperty.Name
      Type         = $CimProperty.Type
      Description  = @($CimProperty.Qualifiers["Description"].Value -split "`n" | ForEach-Object {
          $Paragraph = New-Object PSObject -Property @{Text = $_.Trim() }
          $Paragraph.PSObject.TypeNames.Insert(0, "CimParaTextItem")
          $Paragraph
        })
      RelatedLinks = @(
        New-Object PSObject -Property @{Title = "Online Version"; Link = $HelpUrl }
      )
    }
    $PropertyObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim#Property")
    $HelpObject.Properties.Add($CimProperty.Name, $PropertyObject)
  }

  foreach ($CimMethod in $CimClass.CimClassMethods) {
    $MethodHelp = $LocalizedClass.Methods[$CimMethod.Name]

    $MethodObject = New-Object PSObject -Property @{
      Name         = $CimMethod.Name
      Static       = $CimMethod.Qualifiers["Static"].Value
      Constructor  = $CimMethod.Qualifiers["Constructor"].Value
      Description  = $null
      Parameters   = @{}
      RelatedLinks = @(
        New-Object PSObject -Property @{Title = "Online Version"; Link = $HelpUrl }
      )
    }
    $MethodObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim#Method")

    $MethodObject.Description = @($MethodHelp.Qualifiers["Description"].Value -split "`n" | ForEach-Object {
        $Paragraph = New-Object PSObject -Property @{Text = $_.Trim() }
        $Paragraph.PSObject.TypeNames.Insert(0, "CimParaTextItem")
        $Paragraph
      })

    $CimMethod.Parameters | ForEach-Object {
      if ($_.Qualifiers["In"]) {
        $MethodObject.Parameters[$_.Name] = New-Object PSObject -Property @{
          Name        = $_.Name
          Type        = $_.CimType
          ID          = [int]$_.Qualifiers["ID"].Value
          Description = $null
          In          = $true
        }
      }
      if ($_.Qualifiers["Out"]) {
        $MethodObject.Parameters[$_.Name] = New-Object PSObject -Property @{
          Name        = $_.Name
          Type        = $_.CimType
          ID          = [int]$_.Qualifiers["ID"].Value
          Description = $null
          In          = $false
        }
      }
    }
    $HelpObject.Methods.Add($CimMethod.Name, $MethodObject)
  }

  if ($Property) {
    $PropertyObject = $HelpObject.Properties[$Property]

    if ($PropertyObject) {
      Add-Member -InputObject $PropertyObject -Name Class -Value $HelpObject.Details.Name -MemberType NoteProperty
      Add-Member -InputObject $PropertyObject -Name Namespace -Value $HelpObject.Details.Namespace -MemberType NoteProperty
      Add-Member -InputObject $PropertyObject -Name SuperClass -Value $HelpObject.Details.SuperClass -MemberType NoteProperty
      $PropertyObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim#PropertyDetail")
      return $PropertyObject
    } else {
      throw "Property named '$Property' not found."
    }
  } elseif ($Method) {
    $MethodObject = $HelpObject.Methods[$Method]

    if ($MethodObject) {
      Write-Progress "Retrieving Parameter Descriptions"
      $i, $total = 0, $MethodObject.Parameters.Values.Count

      $MethodHelp = $LocalizedClass.Methods[$Method]
      $MethodObject.Parameters.Values | Where-Object { $_.In } | ForEach-Object {
        Write-Progress "Retrieving Parameter Descriptions" -PercentComplete ($i / $total * 100); $i++

        $ParameterHelp = $MethodHelp.InParameters.Properties | Where-Object Name -EQ $_.Name
        $_.Description = @($ParameterHelp.Qualifiers["Description"].Value -split "`n" | ForEach-Object {
            $Paragraph = New-Object PSObject -Property @{Text = $_.Trim() }
            $Paragraph.PSObject.TypeNames.Insert(0, "CimParaTextItem")
            if ($Paragraph.Text) { $Paragraph }
          })
      }
      $MethodObject.Parameters.Values | Where-Object { !$_.In } | ForEach-Object {
        Write-Progress "Retrieving Parameter Descriptions" -PercentComplete ($i / $total * 100); $i++

        $ParameterHelp = $MethodHelp.OutParameters.Properties | Where-Object Name -EQ $_.Name
        $_.Description = @($ParameterHelp.Qualifiers["Description"].Value -split "`n" | ForEach-Object {
            $Paragraph = New-Object PSObject -Property @{Text = $_.Trim() }
            $Paragraph.PSObject.TypeNames.Insert(0, "CimParaTextItem")
            if ($Paragraph.Text) { $Paragraph }
          })
      }
      Add-Member -InputObject $MethodObject -Name Class -Value $HelpObject.Details.Name -MemberType NoteProperty
      Add-Member -InputObject $MethodObject -Name Namespace -Value $HelpObject.Details.Namespace -MemberType NoteProperty
      Add-Member -InputObject $PropertyObject -Name SuperClass -Value $HelpObject.Details.SuperClass -MemberType NoteProperty
      $MethodObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim#MethodDetail")

      Write-Progress "Retrieving Parameter Descriptions" -Completed

      return $MethodObject
    } else {
      throw "Method named '$Method' not found."
    }
  } else {
    return $HelpObject
  }
}
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