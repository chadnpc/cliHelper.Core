function Test-ProxySettings {
    <#
    .SYNOPSIS
        Checks if the current proxy setting values are in the desired
        state. Returns $true if in the desired state.

    .PARAMETER CurrentValues
        An object containing the current values of the Proxy Settings.

    .PARAMETER DesiredValues
        An object containing the desired values of the Proxy Settings.
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable]
        $CurrentValues,

        [Parameter(Mandatory = $true)]
        [System.Object]
        $DesiredValues
    )

    $inState = $true

    $proxySettingsToCompare = @(
        'EnableManualProxy'
        'EnableAutoConfiguration'
        'EnableAutoDetection'
        'ProxyServer'
        'ProxyServerBypassLocal'
        'AutoConfigURL'
    )

    # Test the string and boolean values
    foreach ($proxySetting in $proxySettingsToCompare) {
        if ($DesiredValues.ContainsKey($proxySetting) -and ($DesiredValues.$proxySetting -ne $CurrentValues.$proxySetting)) {
            Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
                    $($script:localizedData.ProxySettingMismatchMessage -f $proxySetting, $CurrentValues.$proxySetting, $DesiredValues.$proxySetting)
                ) -join '')

            $inState = $false
        }
    }

    # Test the array value
    if ($DesiredValues.ContainsKey('ProxyServerExceptions') `
            -and $CurrentValues.ProxyServerExceptions `
            -and @(Compare-Object `
                -ReferenceObject $DesiredValues.ProxyServerExceptions `
                -DifferenceObject $CurrentValues.ProxyServerExceptions).Count -gt 0) {
        Write-Verbose -Message ( @("$($MyInvocation.MyCommand): "
                $($script:localizedData.ProxySettingMismatchMessage -f 'ProxyServerExceptions', ($CurrentValues.ProxyServerExceptions -join ';'), ($DesiredValues.ProxyServerExceptions -join ';'))
            ) -join '')

        $inState = $false
    }
    return $inState
}