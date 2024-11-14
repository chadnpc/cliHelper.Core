function Get-WebServerInfo {
    <#
    .SYNOPSIS
        Check HTTP header for serverinfo.
    .PARAMETER Uri
        Uri to retrieve HTTP server information for.
    .EXAMPLE
        !webserverinfo http://uri
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [Alias('WebServer')]
        [string]$Uri
    )

    try {
        $httpResponse = Invoke-WebRequest -UseBasicParsing -Uri $Uri
        if ($httpResponse.Headers.server.count -gt 0) {
            $response = $httpResponse.Headers.server -join ' '
        } else {
            $errorMessage = 'No Server Info'
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
        $errorMessage = "Received a general error: $($_.Exception)"
    } finally {
        if ($errorMessage) {
            Write-Error "$errorMessage`n:("
        }
        if ($response) {
            $response
        }
    }
}
