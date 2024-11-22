function Get-DecryptedObject {
  <#
    .SYNOPSIS
        Decryts Objects or files.
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Caveats about the function: 'This function is not fully supported in Linux'
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        $msg = "My email: alain.1337dev@outlook.com"
        $enc = Encrypt $msg -Password $([ArgonCage]::GetPassword()) -KeyOutFile .\PublicKee.txt
        $dec = Decrypt $enc -Password $([ArgonCage]::GetPassword()) -PublicKey $(cat .\PublicKee.txt)
    #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'Prefer verb usage')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertSecurestringWithPlainText", '')]
  [CmdletBinding(ConfirmImpact = "Medium", DefaultParameterSetName = 'WithSecureKey')]
  [Alias('Decrypt', 'Decrypt-Object')]
  [OutputType([byte[]])]
  param (
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrEmpty()]
    [Alias('Bytes')]
    [byte[]]$InputBytes,

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'WithSecureKey')]
    [ValidateNotNullOrEmpty()]
    [Alias('Password')]
    [SecureString]$PrivateKey = [ArgonCage]::GetPassword(),

    [Parameter(Mandatory = $true, Position = 2, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrEmpty()]
    [string]$PublicKey,

    # Source or the Encryption Key. Full/Path of the keyfile you already have. It will be used to lock your keys. (ConvertTo-SecureString -String "Message" -Key [Byte[]])
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'WithKey')]
    [ValidateNotNullOrEmpty()]
    [Byte[]]$Key,

    # Path OF the KeyFile (Containing You saved key base64String Key)
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'WithKeyFile')]
    [ValidateNotNullOrEmpty()]
    [string]$KeyFile,

    [Parameter(Mandatory = $false, Position = 4, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrEmpty()]
    [int]$Iterations = 2,

    [Parameter(Mandatory = $false, Position = 5, ParameterSetName = '__AllParameterSets')]
    [ValidateScript({
        if ([Enum]::GetNames([CryptoAlgorithm]).Contains($_)) {
          return $true
        }
        throw 'Invalid CryptoAlgorithm'
      }
    )][Alias('CryptoAlgorithm')]
    [ValidateNotNullOrEmpty()]
    [string]$Algorithm
  )

  begin {
    $eap = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    $fxn = ('[' + $MyInvocation.MyCommand.Name + ']');
    # Write-Invocation $MyInvocation
  }

  process {
    Write-Verbose "[+] $fxn $($PsCmdlet.ParameterSetName) ..."
    $PsW = switch ($PsCmdlet.ParameterSetName) {
      'WithKey' {  }
      'WithVault' {  }
      'WithSecureKey' { $PrivateKey }
      Default {
        [xcrypt]::new()
      }
    }
    $salt = [byte[]]::new()
    $decryptor = [Decryptor]::new($InputBytes, [securestring]$PsW, [byte[]]$salt, [CryptoAlgorithm]$Algorithm);
    $decrypted = $Decryptor.encrypt($Iterations);
    $bytes = $decrypted
    if ($PsCmdlet.ParameterSetName -ne 'WithKey' -and $PsCmdlet.MyInvocation.BoundParameters.ContainsKey('KeyOutFile')) {
      if (![string]::IsNullOrEmpty($KeyOutFile)) {
        Write-Verbose "[i] Export PublicKey (PNK) to $KeyOutFile ..."
        $nc.key.Export($KeyOutFile, $true)
      }
    }
    $bytes = $(if ($bytes.Equals($nc.Object.Bytes)) { $null }else { $nc.Object.Bytes })
  }

  end {
    $ErrorActionPreference = $eap
    return $bytes
  }
}
