function Get-SavedCredential {
  <#
    .SYNOPSIS
        Get SavedCredential
    .DESCRIPTION
        Gets Saved Credential from credential vault
    .NOTES
        This function is not supported on Linux
    .LINK
        https://github.com/alainQtec/cliHelper.Core
    .EXAMPLE
        Get-SavedCredential 'My App'
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    #>
  [CmdletBinding(DefaultParameterSetName = 'default')]
  [OutputType([CredManaged])]
  param (
    # Target /title /name of the saved credential
    [Parameter(Position = 0, Mandatory = $false, ParameterSetName = '__AllParameterSets')]
    [Alias('Name', 'TargetName')][ValidateNotNullOrEmpty()]
    [string]$Target,

    # Username / Owner
    [Parameter(Position = 1, Mandatory = $false, ParameterSetName = 'default')]
    [Parameter(Position = 2, Mandatory = $false, ParameterSetName = 'byCrtyp')]
    [Alias('usrnm')][ValidateNotNullOrEmpty()]
    [string]$UserName,

    # Credential type.
    [Parameter(Position = 1, Mandatory = $false, ParameterSetName = 'byCrtyp')]
    [ValidateSet('Generic', 'DomainPassword', 'DomainCertificate', 'DomainVisiblePassword', 'GenericCertificate', 'DomainExtended', 'Maximum', 'MaximumEx')]
    [Alias('CredType')][ValidateNotNullOrEmpty()]
    [string]$Type = 'Generic'
  )

  begin {
    $CredentialManager = [CredentialManager]::new(); $Savd_Cred = $null
    $params = $PSCmdlet.MyInvocation.BoundParameters;
    $GetTargetName = [scriptblock]::Create({
        if ([Environment]::UserInteractive -and [Environment]::GetCommandLineArgs().Where({ $_ -like '-NonI*' }).Count -eq 0) {
          $t = Read-Host -Prompt "TargetName"
          if ([string]::IsNullOrWhiteSpace($t)) {
            throw 'Null Or WhiteSpace targetName is not valid'
          }
          $t
        } else {
          throw 'Please Input valid Name'
        }
      }
    )
  }

  process {
    $_Target = $(if ($params.ContainsKey('Target') -and [string]::IsNullOrWhiteSpace($Target)) {
        Invoke-Command -ScriptBlock $GetTargetName
      } elseif (!$params.ContainsKey('Target')) {
        Invoke-Command -ScriptBlock $GetTargetName
      } else {
        $Target
      }
    )
    $Savd_Cred = $(if ($PSCmdlet.ParameterSetName -eq 'default') {
        $CredentialManager.GetCredential($_Target, $UserName)
      } elseif ($PSCmdlet.ParameterSetName -eq 'byCrtyp') {
        if ($params.ContainsKey('type')) {
          $CredentialManager.GetCredential($_Target, $Type, $UserName)
        } else {
          $CredentialManager.GetCredential($_Target, $Type, $UserName)
        }
      }
    )
    if ([CredentialManager]::LastErrorCode.Equals([CredentialManager]::ERROR_NOT_FOUND)) {
      throw [CredentialNotFoundException]::new("$_Target not found.", [System.Exception]::new("Exception of type 'ERROR_NOT_FOUND' was thrown."))
    }
    if ([string]::IsNullOrWhiteSpace($Savd_Cred.target)) {
      Write-Warning "Could not resolve the target Name for: $_Target"
    }
  }

  end {
    return $Savd_Cred
  }
}
