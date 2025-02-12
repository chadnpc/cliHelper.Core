function Protect-Data {
  <#
    .SYNOPSIS
        Protects Data so that it won't be decipherd unless by on that same PC
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not fully supported in Linux'
    .LINK
        https://github.com/chadnpc/cliHelper.core/blob/main/Private/cliHelper.core.xcrypt/cliHelper.core.xcrypt.psm1
    .EXAMPLE
        [securestring]$sec = Protect-Data $(Read-Host -AsSecurestring -Prompt 'Secret msg')
    #>
  [CmdletBinding(ConfirmImpact = "Medium", DefaultParameterSetName = 'String', SupportsShouldProcess = $true)]
  [Alias('Protect')]
  [OutputType([Object[]])]
  param (
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'String')]
    [ValidateNotNullOrEmpty()]
    [string]$MSG,

    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SecureString')]
    [ValidateNotNullOrEmpty()]
    [securestring]$SecureMSG,

    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Bytes')]
    [ValidateNotNullOrEmpty()]
    [byte[]]$Bytes,

    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Xml')]
    [ValidateNotNullOrEmpty()]
    [Alias('XmlDoc')]
    [xml]$InputXml,

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = '__AllParameterSets')]
    [ValidateSet('User', 'Machine')]
    [ValidateNotNullOrEmpty()]
    [Alias('ProtectionScope')]
    [string]$Scope = 'User',

    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrEmpty()]
    [byte[]]$Entropy
  )

  begin {
    #Load The Assemblies
    if (!("System.Security.Cryptography.ProtectedData" -is 'Type')) { Add-Type -AssemblyName System.Security }
    [bool]$UseCustomEntropy = $null -ne $Entropy -and $PsCmdlet.MyInvocation.BoundParameters.ContainsKey('Entropy')
  }

  process {
    $ProtectedD = switch ($PsCmdlet.ParameterSetName) {
      'Xml' {
        if ($PSCmdlet.ShouldProcess("Xml", "Protect")) {
          if ($UseCustomEntropy) {
            Protect-Data -Bytes $($InputXml | xconvert ToBytes) -Scope $Scope -Entropy $Entropy
          } else {
            Protect-Data -Bytes $($InputXml | xconvert ToBytes) -Scope $Scope
          }
        }
      }
      'string' {
        if ($PSCmdlet.ShouldProcess("String", "Protect")) {
          if ($UseCustomEntropy) {
            Protect-Data -MSG $Msg -Scope $Scope -Entropy $Entropy
          } else {
            Protect-Data -MSG $Msg -Scope $Scope
          }
        }
      }
      'Bytes' {
        if ($PSCmdlet.ShouldProcess("Bytes", "Protect")) {
          if ($UseCustomEntropy) {
            Protect-Data -Bytes $Bytes -Scope $Scope -Entropy $Entropy
          } else {
            Protect-Data -Bytes $Bytes -Scope $Scope
          }
        }
      }
      'SecureString' { throw 'Yeet!' }
      Default {
        throw 'Error!'
      }
    }
  }

  end {
    return $ProtectedD
  }
}
