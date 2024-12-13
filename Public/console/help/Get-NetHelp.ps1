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
