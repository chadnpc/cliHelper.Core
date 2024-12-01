function Get-WebContent {
  [CmdletBinding()]
  Param(
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 0)]
    [String]$Url,
    [Management.Automation.PSCredential]$Credential,
    $Encoding
  )
  process {
    $client = (New-Object Net.WebClient)
    if ($Credential) {
      $ntwCred = $Credential.GetNetworkCredential()
      $client.Credentials = $ntwCred
      $auth = "Basic " + [Convert]::ToBase64String([Text.Encoding]::Default.GetBytes($ntwCred.UserName + ":" + $ntwCred.Password))
      $client.Headers.Add("Authorization", $auth)
    }
    if ($Encoding) {
      if ($Encoding -is [string]) {
        $Encoding = [Text.Encoding]::GetEncoding($Encoding)
      }
      $client.Encoding = $Encoding
    }

    try {
      $client.DownloadString($Url)
    } catch [System.Net.WebException] {
      throw "Request failed: ""$($_.Exception.Message)"""
    }
  }
}
