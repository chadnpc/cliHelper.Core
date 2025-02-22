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
