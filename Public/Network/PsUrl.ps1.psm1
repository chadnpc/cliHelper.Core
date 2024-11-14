function Get-Url {
  [CmdletBinding()]
  Param(
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 0)]
    [String]$Url,
    [String]$ToFile,
    [Management.Automation.PSCredential]$Credential
  )
  process {
    Write-Verbose "Get-Url is considered obsolete. Please use Get-WebContent instead"

    $client = (New-Object Net.WebClient)
    if ($Credential) {
      $ntwCred = $Credential.GetNetworkCredential()
      $client.Credentials = $ntwCred
      $auth = "Basic " + [Convert]::ToBase64String([Text.Encoding]::Default.GetBytes($ntwCred.UserName + ":" + $ntwCred.Password))
      $client.Headers.Add("Authorization", $auth)
    }

    if ($ToFile -ne "") {
      $client.DownloadFile($Url, $ToFile)
    } else {
      $client.DownloadString($Url)
    }
  }
}

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

function Write-Url {
  [CmdletBinding()]
  Param(
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true, Position = 0)]
    [String]$Url,
    [HashTable]$Data,
    [String]$Content,
    [TimeSpan]$Timeout = [TimeSpan]::FromMinutes(1),
    [Management.Automation.PSCredential]$Credential,
    [String]$ContentType
  )
  process {
    Write-Verbose "Write-Url is considered obsolete. Please use Send-WebContent instead"
    if ($Content -ne "") {
      Send-WebContent -Url:$Url -Content:$Content -Timeout:$Timeout -Credential:$Credential -ContentType:$ContentType
    } else {
      Send-WebContent -Url:$Url -Data:$Data -Timeout:$Timeout -Credential:$Credential -ContentType:$ContentType
    }
  }
}


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