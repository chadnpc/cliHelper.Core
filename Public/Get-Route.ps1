function Get-Route {
    [CmdletBinding()]
    param ()

    process {
        $adapters = @{}
        $netroute = @()
        Get-WmiObject Win32_NetworkAdapterConfiguration | ForEach-Object{ $adapters[[int]($_.InterfaceIndex)] = $_.IPAddress }
        Get-WmiObject win32_IP4RouteTable | ForEach-Object{
            $out = New-Object psobject
            $out | Add-Member Noteproperty 'Destination' $_.Destination
            $out | Add-Member Noteproperty 'Netmask' $_.Mask
            if ($_.NextHop -eq "0.0.0.0"){
                $out | Add-Member Noteproperty 'NextHop' "On-link"
            }
            else{
                $out | Add-Member Noteproperty 'NextHop' $_.NextHop
            }
            if($adapters[$_.InterfaceIndex] -and ($adapters[$_.InterfaceIndex] -ne "")){
                $out | Add-Member Noteproperty 'Interface' $($adapters[$_.InterfaceIndex] -join ",")
            }
            else {
                $out | Add-Member Noteproperty 'Interface' '127.0.0.1'
            }
            $out | Add-Member Noteproperty 'Metric' $_.Metric1
            $netroute += $out
        }
    }

    end {
        # $netroute | Format-Table -autosize
        return $netroute
    }
}