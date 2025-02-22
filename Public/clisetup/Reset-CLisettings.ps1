#!/usr/bin/env pwsh
function Reset-CLIsettings {
    <#
    .SYNOPSIS
        Reset everything to default values
    #>
    [CmdletBinding()]
    param ()
    process {
        [CliStyler]::Create()
    }
}