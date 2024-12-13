function Send-WebContent {
  [CmdletBinding()]
  Param(
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 0)]
    [String]$Url,
    [Parameter(ParameterSetName = 'Data')]
    [HashTable]$Data,
    [Parameter(ParameterSetName = 'Content')]
    [String]$Content,
    [TimeSpan]$Timeout = [TimeSpan]::FromMinutes(1),
    [Management.Automation.PSCredential]$Credential,
    [String]$ContentType,
    [HashTable]$Headers
  )
  process {
    try {
      $req = [Net.WebRequest]::Create($Url)
      $req.Method = "POST"
      $req.Timeout = $Timeout.TotalMilliseconds
      if ($Credential) {
        $ntwCred = $Credential.GetNetworkCredential()
        $auth = "Basic " + [Convert]::ToBase64String([Text.Encoding]::Default.GetBytes($ntwCred.UserName + ":" + $ntwCred.Password))
        $req.Headers.Add("Authorization", $auth)
        $req.Credentials = $ntwCred
        $req.PreAuthenticate = $true
      }

      if ($ContentType -ne "") {
        $req.ContentType = $ContentType
      }

      if ($Headers -ne $Null) {
        foreach ($headerName in $Headers.Keys) {
          $req.Headers.Add($headerName, $Headers[$headerName])
        }
      }

      switch ($PSCmdlet.ParameterSetName) {
        Content {
          $reqStream = $req.GetRequestStream()
          $reqBody = [Text.Encoding]::Default.GetBytes($Content)
          $reqStream.Write($reqBody, 0, $reqBody.Length)
        }
        Data {
          Add-Type -AssemblyName System.Web
          $formData = [Web.HttpUtility]::ParseQueryString("")
          foreach ($key in $Data.Keys) {
            $formData.Add($key, $Data[$key])
          }
          $reqBody = [Text.Encoding]::Default.GetBytes($formData.ToString())

          $req.ContentType = "application/x-www-form-urlencoded"
          $reqStream = $req.GetRequestStream()
          $reqStream.Write($reqBody, 0, $reqBody.Length)
        }
      }

      $reqStream.Close()

      $Method = $req.Method
      Write-Verbose "Execute $Method request"
      foreach ($header in $req.Headers.Keys) {
        Write-Verbose ("$header : " + $req.Headers[$header])
      }

      $resp = $req.GetResponse()
      $respStream = $resp.GetResponseStream()
      $respReader = (New-Object IO.StreamReader($respStream))
      $respReader.ReadToEnd()
    } catch [Net.WebException] {
      if ($null -ne $_.Exception -and $null -ne $_.Exception.Response) {
        $errorResult = $_.Exception.Response.GetResponseStream()
        $errorText = (New-Object IO.StreamReader($errorResult)).ReadToEnd()
        Write-Error "The remote server response: $errorText"
      }
      throw $_
    }
  }
}