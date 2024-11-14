function Write-TitleCase {
  [cmdletbinding()]
  [OutputType([string])]
  param(
    [parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$String,
    [switch]$ToLowerFirst,
    [switch]$IncludeInput
  )

  process {
    $TextInfo = (Get-Culture).TextInfo
    foreach ($curString in $String) {
      if ($ToLowerFirst) {
        $ReturnVal = $TextInfo.ToTitleCase($curString.ToLower())
      } else {
        $ReturnVal = $TextInfo.ToTitleCase($curString)
      }
      Write-Output -InputObject $ReturnVal
    }
  }
}
