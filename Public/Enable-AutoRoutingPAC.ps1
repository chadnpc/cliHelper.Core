function Enable-AutoRoutingPAC {
    <#
    .SYNOPSIS
        A short one-line action-based description, e.g. 'Tests if a function is valid'
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        http://v65ngaoj2nyaiq2ltf4uzota254gnasarrkuj4aqndi2bb5lw6frt3ad.onion/entry/proxy-pac-i2p-onion.html
    .EXAMPLE
        Test-MyTestFunction -Verbose
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    #>
    [CmdletBinding()]
    param (

    )

    begin {
        class shExpMatch {
            shExpMatch() {}
            shExpMatch($h0st, $url) {
                # do sruff here
            }
        }
        function FindProxyForURL($url, $h0st) {
            if ([shExpMatch]::New((Get-Host), "*.i2p")) {
                return "SOCKS5 127.0.0.1:4447";
            }
            if ([shExpMatch]::New((Get-Host), "*.onion")) {
                return "SOCKS5 127.0.0.1:9050";
            }
            return "DIRECT";
        }
    }

    process {

    }

    end {

    }
}