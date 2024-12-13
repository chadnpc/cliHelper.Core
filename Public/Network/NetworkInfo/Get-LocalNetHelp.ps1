function Get-LocalNetHelp {
  [CmdletBinding()]
  param(
    [string]$File,
    [string]$Selector
  )

  try {
    $FileStream = New-Object System.IO.FileStream $File, ([System.IO.FileMode]::Open), ([System.IO.FileAccess]::Read)
    $Reader = New-Object System.Xml.XmlTextReader $FileStream
    $Reader.EntityHandling = [System.Xml.EntityHandling]"ExpandEntities"
    $Document = New-Object System.Xml.XPath.XPathDocument $Reader
    $Navigator = $Document.CreateNavigator()

    # TODO: support overloads
    $Navigator.Select("//member[@name='$Selector' or starts-with(@name,'$Selector(')]") | ForEach-Object { [Xml]$_.OuterXml }
  } finally {
    if ($Reader) {
      $Reader.Close()
    }
  }
}