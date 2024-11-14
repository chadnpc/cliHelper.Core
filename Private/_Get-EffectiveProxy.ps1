function Get-EffectiveProxy {
    <#
    .SYNOPSIS
        Get the current proxy using several methods

    .DESCRIPTION
        Function tries to find the current proxy using several methods, in the given order:
            - $env:dotfilesProxyLocation variable
            - $env:http_proxy environment variable
            - IE proxy
            - Chocolatey config
            - Winhttp proxy
            - WebClient proxy

        Use Verbose parameter to see which of the above locations was used for the result, if any.
        The function currently doesn't handle the proxy username and password.

    .OUTPUTS
        [String] in the form of http://<proxy>:<port>
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$ParameterName
    )

    begin {

    }

    process {
        # Try chocolatey proxy environment vars
        if ($env:dotfilesProxyLocation) {
            Out-Verbose "Using `$env:dotfilesProxyLocation"
            return $env:dotfilesProxyLocation
        }

        # Try standard Linux variable
        if ($env:http_proxy) {
            Out-Verbose "Using `$Env:http_proxy"
            return $env:http_proxy
        }

        # Try to get IE proxy
        $r = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        if ($r.ProxyEnable -and $r.ProxyServer) {
            Out-Verbose "Using IE proxy settings"
            return $("http://" + $r.ProxyServer)
        }

        # Try chocolatey config file
        [xml] $cfg = Get-Content $env:dotfilesInstall\config\chocolatey.config
        $p = $cfg.chocolatey.config | ForEach-Object { $_.add } | Where-Object { $_.key -eq 'proxy' } | Select-Object -Expand value
        if ($p) {
            Out-Verbose "Using choco config proxy"
            return $p
        }

        # Try winhttp proxy
        $(netsh.exe winhttp show proxy) -match 'Proxy Server\(s\)' | Set-Variable proxy
        $proxy = $proxy -split ' :' | Select-Object -Last 1
        $proxy = $proxy.Trim()
        if ($proxy) {
            Out-Verbose "Using winhttp proxy server"
            return "http://" + $proxy
        }

        # Try using WebClient
        $url = "http://chocolatey.org"
        $client = New-Object System.Net.WebClient
        if ($client.Proxy.IsBypassed($url)) { return $null }

        Out-Verbose "Using WebClient proxy"
        return "http://" + $client.Proxy.GetProxy($url).Authority
    }

    end {

    }
}