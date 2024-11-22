function Remove-Credential {
  <#
    .SYNOPSIS
        Deletes credential from Windows Credential Mandger
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        This function is supported on windows only
    .LINK
        https://github.com/alainQtec/cliHelper.Core/blob/main/Private/cliHelper.core.xcrypt/cliHelper.core.xcrypt.psm1
    .EXAMPLE
        Remove-Credential -Verbose
    #>
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # TargetName
    [Parameter(Mandatory = $true)][ValidateLength(1, 32767)]
    [ValidateScript({
        if (![string]::IsNullOrWhiteSpace($_)) {
          return $true
        }
        throw 'Null or WhiteSpace Inputs are not allowed.'
      }
    )][Alias('Title')]
    [String]$Target,
    [Parameter(Mandatory = $false)]
    [ValidateSet('Generic', 'DomainPassword', 'DomainCertificate', 'DomainVisiblePassword', 'GenericCertificate', 'DomainExtended', 'Maximum', 'MaximumEx')]
    [String]$Type = "GENERIC"
  )

  begin {
    $CredentialManager = [CredentialManager]::new();
  }

  process {
    $CredType = [CredType]"$Type"
    if ($PSCmdlet.ShouldProcess("Removing Credential, target: $Target", '', '')) {
      $IsRemoved = $CredentialManager.Remove($Target, $CredType);
      if (!$IsRemoved) {
        throw 'Remove-Credential Failed. ErrorCode: 0x' + [CredentialManager]::LastErrorCode
      }
    }
  }
}
