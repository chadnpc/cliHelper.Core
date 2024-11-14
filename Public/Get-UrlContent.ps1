function Get-UrlContent {
<#
.SYNOPSIS
    To get the HTML content of a specified URL
.DESCRIPTION
    To get the HTML content of a specified URL
.PARAMETER URL
    The URL string, which should begin with "https://" or "http://"
.PARAMETER IgnoreSslError
    To ignore any SSL errors that are generated
.NOTES
    This function only exists for PowerShell versions prior to the inclusion of Invoke-WebRequest
.EXAMPLE
    Get-UrlContent -URL "http://www.google.com"
    Would return:
    The HTML content that is found on Google's homepage
.EXAMPLE
    Get-UrlContent -URL "https://secureServer"
    Assuming the computer does not have a valid certificate for secureServer then this would return:
    $Null
.EXAMPLE
    Get-UrlContent -URL "https://secureServer" -IgnoreSslError
    Assuming the computer does not have a valid certificate for secureServer and you wish to override the SSL error then this would return:
    The HTML content that is found on secureServer's homepage
.OUTPUTS
    Either $Null if any errors exist or a [string] if successful
#>

    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseProcessBlockForPipelineCommand', '')]
    Param (
        [parameter(ValueFromPipeLine, HelpMessage = 'Add help message for user', ValueFromPipeLineByPropertyName, Mandatory)]
        [string] $URL,

        [parameter()]
        [switch] $IgnoreSslError
    )

    begin {
        Write-Invocation $MyInvocation
        $oldEA = $ErrorActionPreference
        $ErrorActionPreference = 'continue'
        Out-Verbose "Saving current value of `$ErrorActionPreference [$($oldEa)] and setting it to 'Stop'"
    }

    process {
        if ($IgnoreSslError) {
            Out-Verbose  'Turning on IgoreSslError'
            [System.Net.ServicePointManager]::ServerCertificateValidationCallBack = { $true }
        }
        $htmlContent = $null
        Out-Verbose  'Creating a webclient'
        $webClient = New-Object -TypeName System.Net.WebClient
        Out-Verbose "Requesting content from [$($URL)]"
        try {
            $htmlContent = $webClient.downloadstring($URL)
        } catch {
            Write-Error -Message "Could not connect to [$($URL)]"
        } finally {
            if ($IgnoreSslError) {
                Out-Verbose  'Turning off IgoreSslError'
                [System.Net.ServicePointManager]::ServerCertificateValidationCallBack = { $false }
            }
        }

        Out-Verbose  'Disposing of webClient connection'
        $webClient.Dispose()
        Remove-Variable -Name webClient
        if ($htmlContent) {
            Out-Verbose  'Successful download of HTML content'
            Write-Output -InputObject $htmlContent
        } else {
            Out-Verbose  'Unsuccessful download of HTML content'
            break
        }
    }

    end {
        Out-Verbose "Resetting value of `$ErrorActionPreference back to [$($oldEa)]"
        $ErrorActionPreference = $oldEA
        Out-Verbose $fxn "Complete."
    }
}
