function Get-EncryptionAlgorithm {
  <#
    .SYNOPSIS
        Used to set the encryption algorithm that will be used by other functions in the module to encrypt and decrypt data.
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        https://github.com/alainQtec/cliHelper.Core/blob/main/Public/xcrypt/Get-EncryptionAlgorithm.ps1
    .EXAMPLE
        Get-EncryptionAlgorithm -key "dsfjkmsjkfnsdkcnmdimsidfcsdcmsdlkxiddsdcmsdlcdlilsdldd "
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    #>
  [CmdletBinding(DefaultParameterSetName = 'default')]
  [OutputType([string])]
  param (
    [Parameter(Mandatory = $true, ParameterSetName = 'default')]
    [string]$key,

    [Parameter(Mandatory = $true, ParameterSetName = 'k')]
    [K3Y]$k3y
  )

  begin {
    $algorthm = [String]::Empty
  }

  process {
    # Parse the Object to return the Name of encryption Algorithm
  }

  end {
    return $algorthm
  }
}
