function New-Password {
  <#
    .SYNOPSIS
        Creates a password string
    .DESCRIPTION
        Creates a password containing minimum of 9 characters, 1 lowercase, 1 uppercase, 1 numeric, and 1 special character.
        Can not exceed 999 characters
    .LINK
        https://github.com/alainQtec/cliHelper.Core/blob/main/Private/cliHelper.core.xcrypt/cliHelper.core.xcrypt.psm1
    .EXAMPLE
        New-Password
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'No system state is being changed')]
  [CmdletBinding(DefaultParameterSetName = 'asSecureString')]
  param (
    # Exact password Length. Note: The minimum length is 14 characters, Otherwise it nearly impossible to create a password under 14 characters. Youll'd be better off use a random text generator!
    [Parameter(Position = 0, Mandatory = $false, ParameterSetName = '__AllParameterSets')]
    [Alias('l')][ValidateRange(14, 999)]
    [int]$Length = 19,

    [Parameter(Mandatory = $false, ParameterSetName = '__AllParameterSets')]
    [switch]$StartWithLetter,

    [Parameter(Mandatory = $false, ParameterSetName = '__AllParameterSets')]
    [switch]$NoSymbols,

    [Parameter(Mandatory = $false, ParameterSetName = '__AllParameterSets')]
    [switch]$UseAmbiguousCharacters,

    [Parameter(Mandatory = $false, ParameterSetName = '__AllParameterSets')]
    [switch]$UseExtendedAscii,

    [Parameter(Mandatory = $false, ParameterSetName = 'PlainText')]
    [switch]$AsPlainText
  )

  begin {
    $Pass = [string]::Empty
    # $params = $PSCmdlet.MyInvocation.BoundParameters
  }

  process {
    $Pass = [xcrypt]::GeneratePassword($Length, $StartWithLetter, $NoSymbols, $UseAmbiguousCharacters, $UseExtendedAscii);
    if ($PSCmdlet.ParameterSetName -eq 'asSecureString') {
      $pass = $Pass | xconvert ToSecurestring
    }
  }
  end {
    return $Pass
  }
}
