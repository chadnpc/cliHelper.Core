function UnProtect-Data {
  <#
    .SYNOPSIS
        Unprotects data
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not fully supported in Linux'
    .LINK
        https://github.com/alainQtec/cliHelper.Core/blob/main/Private/cliHelper.Core.xcrypt/cliHelper.Core.xcrypt.psm1
    .EXAMPLE
        UnProtect-Data $secretMsg
    #>
  [CmdletBinding(ConfirmImpact = "Medium", DefaultParameterSetName = 'string', SupportsShouldProcess = $true)]
  [Alias('UnProtect')]
  [OutputType([byte[]])]
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

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = '__A llParameterSets')]
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
    $UnProtected = switch ($PsCmdlet.ParameterSetName) {
      'Xml' {
        if ($PSCmdlet.ShouldProcess("Xml", "Protect")) {
          if ($UseCustomEntropy) {
            UnProtect-Data -Bytes $($InputXml | xconvert ToBytes) -Entropy $Entropy -Scope $Scope
          } else {
            UnProtect-Data -Bytes $($InputXml | xconvert ToBytes) -Scope $Scope
          }
        }
      }
      'string' {
        if ($PSCmdlet.ShouldProcess("String", "Protect")) {
          if ($UseCustomEntropy) {
            UnProtect-Data -MSG $Msg -Scope $Scope -Entropy $Entropy
          } else {
            UnProtect-Data -MSG $Msg -Scope $Scope
          }
        }
      }
      'Bytes' {
        if ($PSCmdlet.ShouldProcess("Bytes", "Protect")) {
          if ($UseCustomEntropy) {
            UnProtect-Data -Bytes $Bytes -Scope $Scope -Entropy $Entropy
          } else {
            UnProtect-Data -Bytes $Bytes -Scope $Scope
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
    return $UnProtected
  }
}
