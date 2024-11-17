function Set-NetAdapterNetbiosOptions {
  <#
    .SYNOPSIS
        Configures Netbios on a Network Adapter.

    .DESCRIPTION
        Uses two methods for configuring Netbios on a Network Adapter.
        If an interface is IPEnabled, the CIMMethod will be invoked.
        Otherwise the registry key is configured as this will satisfy
        network adapters being in alternative states such as disabled
        or disconnected.

    .PARAMETER NetworkAdapterObject
        Network Adapter Win32_NetworkAdapterConfiguration Object

    .PARAMETER InterfaceAlias
        Name of the network adapter being configured. Example: Ethernet

    .PARAMETER Setting
        Setting value for this resource which should be one of
        the following: Default, Enable, Disable
    #>
  [CmdletBinding()]
  param
  (
    [Parameter(Mandatory = $true)]
    [System.Object]
    $NetworkAdapterObject,

    [Parameter(Mandatory = $true)]
    [System.String]
    $InterfaceAlias,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Default', 'Enable', 'Disable')]
    [System.String]
    $Setting
  )

  Write-Verbose -Message ($script:localizedData.SetNetBiosMessage -f $InterfaceAlias, $Setting)

  # Only IPEnabled interfaces can be configured via SetTcpipNetbios method.
  if ($NetworkAdapterObject.IPEnabled) {
    $result = $NetworkAdapterObject |
      Invoke-CimMethod `
        -MethodName SetTcpipNetbios `
        -ErrorAction Stop `
        -Arguments @{
        TcpipNetbiosOptions = [uint32][NetBiosSetting]::$Setting.value__
      }

    if ($result.ReturnValue -ne 0) {
      New-InvalidOperationException `
        -Message ($script:localizedData.FailedUpdatingNetBiosError -f $InterfaceAlias, $result.ReturnValue, $Setting)
    }
  } else {
    <#
            IPEnabled=$false can only be configured via registry
            this satisfies disabled and disconnected states
        #>
    $setItemPropertyParameters = @{
      Path  = "$($script:hklmInterfacesPath)\Tcpip_$($NetworkAdapterObject.SettingID)"
      Name  = 'NetbiosOptions'
      Value = [NetBiosSetting]::$Setting.value__
    }
    $null = Set-ItemProperty @setItemPropertyParameters
  }
}