function Start-CimSession {
    <#
.SYNOPSIS
    Creates CimSessions to remote computer(s), automatically determining if the WSMAN
    or Dcom protocol should be used.
.DESCRIPTION
    Start-CimSession is a function that is designed to create CimSessions to one or more
    computers, automatically determining if the default WSMAN protocol or the backwards
    compatible Dcom protocol should be used. PowerShell version 3 is required on the
    computer that this function is being run on, but PowerShell does not need to be
    installed at all on the remote computer.
.PARAMETER ComputerName
    The name of the remote computer(s). This parameter accepts pipeline input. The local
    computer is the default.
.PARAMETER Credential
    Specifies a user account that has permission to perform this action. The default is
    the current user.
.EXAMPLE
    Start-CimSession -ComputerName Server01, Server02
.EXAMPLE
    Start-CimSession -ComputerName Server01, Server02 -Credential (Get-Credential)
.EXAMPLE
    Get-Content -Path C:\Servers.txt | Start-CimSession
.INPUTS
    String
.OUTPUTS
    Microsoft.Management.Infrastructure.CimSession
.NOTES
    Author:  Mike F Robbins
    Website: http://mikefrobbins.com
    Twitter: @mikefrobbins
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateNotNullorEmpty()]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [System.Management.Automation.Credential()]
        [PSCredential]$Credential = [System.Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        ## Requires -Version 3.0
        $Opt = New-CimSessionOption -Protocol Dcom

        $SessionParams = @{
            ErrorAction = 'Stop'
        }

        If ($PSBoundParameters['Credential']) {
            $SessionParams.Credential = $Credential
        }
    }

    PROCESS {
        foreach ($Computer in $ComputerName) {
            $SessionParams.ComputerName = $Computer

            if ((Test-WSMan -ComputerName $Computer -ErrorAction SilentlyContinue).productversion -match 'Stack: ([3-9]|[1-9][0-9]+)\.[0-9]+') {
                try {
                    Write-Verbose -Message "Attempting to connect to $Computer using the WSMAN protocol."
                    New-CimSession @SessionParams
                } catch {
                    Write-Warning -Message "Unable to connect to $Computer using the WSMAN protocol. Verify your credentials and try again."
                }
            }

            else {
                $SessionParams.SessionOption = $Opt

                try {
                    Write-Verbose -Message "Attempting to connect to $Computer using the DCOM protocol."
                    New-CimSession @SessionParams
                } catch {
                    Write-Warning -Message "Unable to connect to $Computer using the WSMAN or DCOM protocol. Verify $Computer is online and try again."
                }

                $SessionParams.Remove('SessionOption')
            }
        }
    }
}