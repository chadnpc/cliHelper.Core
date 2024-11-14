function Set-DynamicPort {
    <#
    .SYNOPSIS
        Short description
    .DESCRIPTION
        https://support.microsoft.com/en-us/help/929851/the-default-dynamic-port-range-for-tcp-ip-has-changed-in-windows-vista
        The new default start port is 49152, and the new default end port is 65535.
        Default port configuration was changed during image generation by Visual Studio Enterprise Installer to:
        #   Protocol tcp Dynamic Port Range
        #   ---------------------------------
        #   Start Port      : 1024
        #   Number of Ports : 64511
    .EXAMPLE
        PS C:\> <example usage>
        Explanation of what the example does
    .INPUTS
        Inputs (if any)
    .OUTPUTS
        Output (if any)
    .NOTES
        General notes
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $false)]
        [string]$StartPort,
        [Parameter(Mandatory = $false)]
        [string]$EndPort
    )
    begin {}

    process {
        Out-Verbose "Set the dynamic port range to start at port 49152 and to end at the 65536 (16384 ports)"
        $null = netsh int ipv4 set dynamicport tcp start=49152 num=16384
        $null = netsh int ipv4 set dynamicport udp start=49152 num=16384
        $null = netsh int ipv6 set dynamicport tcp start=49152 num=16384
        $null = netsh int ipv6 set dynamicport udp start=49152 num=16384
    }

    end {
        # Invoke-PesterTests -TestFile "WindowsFeatures" -TestName "DynamicPorts"
    }
}