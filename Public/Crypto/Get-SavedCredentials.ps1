function Get-SavedCredentials {
  <#
    .SYNOPSIS
        Retreives All strored credentials from credential Manager
    .DESCRIPTION
        Retreives All strored credentials and returns an [System.Collections.ObjectModel.Collection[CredManaged]] object
    .NOTES
        This function is supported on windows only
    .LINK
        https://github.com/alainQtec/cliHelper.core
    .EXAMPLE
        Get-SavedCredentials
        Enumerates all SavedCredentials
    #>
  [CmdletBinding()]
  [outputType([System.Collections.ObjectModel.Collection[CredManaged]])]
  param ()

  begin {
    $Credentials = $null
    $CredentialManager = [CredentialManager]::new();
  }

  process {
    $Credentials = $CredentialManager.RetreiveAll();
  }
  end {
    return $Credentials;
  }
}
