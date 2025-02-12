function Save-Credential {
  <#
    .SYNOPSIS
        Saves credential to windows credential Manager
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        This function is supported on windows only
    .LINK
        https://github.com/chadnpc/cliHelper.core
    .EXAMPLE
        Save-Credential youtube.com/@memeL0rd memeL0rd $(Read-Host -AsSecureString -Prompt "memeLord's youtube password")
    #>
  [CmdletBinding(DefaultParameterSetName = 'uts')]
  param (
    # title aka TargetName of the credential you want to save
    [Parameter(Position = 0, Mandatory = $true, ParameterSetName = 'uts')]
    [ValidateScript({
        if (![string]::IsNullOrWhiteSpace($_)) {
          return $true
        }
        throw 'Null or WhiteSpace targetName is not allowed.'
      }
    )][Alias('target')]
    [string]$Title,
    # UserName
    [Parameter(Position = 1, Mandatory = $false, ParameterSetName = 'uts')]
    [Alias('UserName')]
    [string]$User,

    # Securestring / Password
    [Parameter(Position = 2, Mandatory = $true, ParameterSetName = 'uts')]
    [ValidateNotNull()]
    [securestring]$SecureString,

    # ManagedCredential Object you want to save
    [Parameter(Mandatory = $true, ParameterSetName = 'MC')]
    [Alias('Credential')][ValidateNotNull()]
    [CredManaged]$Obj

  )

  process {
    if ($PSCmdlet.ParameterSetName -eq 'uts') {
      $CredentialManager = [CredentialManager]::new();
      if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('User')) {
        [void]$CredentialManager.SaveCredential($Title, $User, $SecureString);
      } else {
        [void]$CredentialManager.SaveCredential($Title, $SecureString);
      }
    } elseif ($PSCmdlet.ParameterSetName -eq 'MC') {
      $CredentialManager = [CredentialManager]::new();
      [void]$CredentialManager.SaveCredential($Obj);
    }
  }
}
