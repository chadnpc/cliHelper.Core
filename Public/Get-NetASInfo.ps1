function Get-NetASInfo {
    <#
    .SYNOPSIS
        Check HTTP header for server information.
    .PARAMETER IPAddress
        IP address to retrieve network AS information for.
    .EXAMPLE
        !netasinfo IPAddress
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [Alias('IP')]
        [string]$IPAddress
    )

    try {
        $httpResponse = Invoke-WebRequest -UseBasicParsing -Uri "https://stat.ripe.net/data/searchcomplete/data.json?resource=$($IPAddress)"
        if ($httpResponse) {
            $jsonResponse = $httpResponse | ConvertFrom-Json
            if ($null -ne $jsonResponse.data.categories) {
                if ($jsonResponse.data.categories.suggestions.count -gt 0) {
                    foreach ($row in  $jsonResponse.data.categories.suggestions) {
                        if ($row.value -like 'AS*') {
                            $asCode = $row.value
                        }
                    }
                } else {
                    $asCode = $jsonResponse.data.categories.suggestions.value
                }

                if ($asCode) {
                    $asInfoResponse = Invoke-WebRequest -UseBasicParsing -Uri "https://stat.ripe.net/data/as-overview/data.json?resource=$($asCode)"
                    $jsonAsInfo = $asInfoResponse | ConvertFrom-Json
                    $response = "$asCode $($jsonAsInfo.data.holder)"
                } else {
                    $errorMessage = 'Not Data Found'
                }
            } else {
                $errorMessage = 'Not Data Found'
            }
        }
    } catch [System.Net.WebException] {
        switch ($_.Exception.Response.StatusCode) {
            'BadRequest' {
                $errorMessage = 'Server Error'
            }
            'InternalServerError' {
                $errorMessage = 'Server Error 500'
            }
            default {
                $errorMessage = "Server Error: $($_.Exception)"
            }
        }
    } catch {
        Write-Debug $_.Exception
        $errorMessage = "Receive a general error: $($_.Exception)"
    } finally {
        if ($errorMessage) {
            Write-Error "$errorMessage`n:("
        }
        if ($response) {
            $response
        }
    }
}