function New-K3Y {
  <#
    .SYNOPSIS
        Creates a new [K3Y] object
    .DESCRIPTION
        Creates a custom k3y object for encryption/decryption.
        The K3Y can only be used to Once, and its 'UID' [ see .SetK3YUID() method ] is a fancy way of storing the version, user/owner credentials, Compression alg~tm used and Other Info
        about the most recent use and the person who used it; so it can be analyzed later to verify some rules before being used again. this allows to create complex expiring encryptions.
    .EXAMPLE
        $K = New-K3Y (Get-Credential -UserName 'Alain Herve' -Message 'New-K3Y')
    .NOTES
        This is a private function, its not meant to be exported, or used alone
    #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = '')]
  [CmdletBinding(DefaultParameterSetName = 'default')]
  [OutputType([Object], [string])]
  param (
    # Parameter help description
    [Parameter(Position = 0, Mandatory = $false, ParameterSetName = 'byPscredential')]
    [Alias('Owner')][ValidateNotNull()]
    [pscredential]$User,

    # Parameter help description
    [Parameter(Position = 0, Mandatory = $false, ParameterSetName = 'default')]
    [string]$UserName,

    # Parameter help description
    [Parameter(Position = 1, Mandatory = $false, ParameterSetName = 'default')]
    [securestring]$Password,

    # Expiration date
    [Parameter(Position = 2, Mandatory = $false, ParameterSetName = 'default')]
    [Parameter(Position = 1, Mandatory = $false, ParameterSetName = 'byPscredential')]
    [datetime]$Expiration,

    # Convert to string (sharable)
    [Parameter(Mandatory = $false, ParameterSetName = '__AllParameterSets')]
    [switch]$AsString,

    [Parameter(Mandatory = $false, ParameterSetName = '__AllParameterSets')]
    [switch]$Protect
  )

  begin {
    $k3y = $null
    $params = $PSCmdlet.MyInvocation.BoundParameters
    $IsInteractive = [Environment]::UserInteractive -and [Environment]::GetCommandLineArgs().Where({ $_ -like '-NonI*' }).Count -eq 0
  }
  process {
    $k3y = $(if ($PSCmdlet.ParameterSetName -eq 'byPscredential') {
        if ($params.ContainsKey('User') -and $params.ContainsKey('Expiration')) {
          [K3Y]::New($User, $Expiration);
        } else {
          # It means: $params.ContainsKey('User') -and !$params.ContainsKey('Expiration')
          [datetime]$ExpiresOn = if ($IsInteractive) {
            [int]$days = Read-Host -Prompt "Expires In (replie num of days)"
            [datetime]::Now + [Timespan]::new($days, 0, 0, 0);
          } else {
            [datetime]::Now + [Timespan]::new(30, 0, 0, 0); # ie: expires in 30days
          }
          [K3Y]::New($User, $ExpiresOn);
        }
      } elseif ($PSCmdlet.ParameterSetName -eq 'default') {
        if ($params.ContainsKey('UserName') -and $params.ContainsKey('Password') -and $params.ContainsKey('Expiration')) {
          [K3Y]::New($UserName, $Password, $Expiration);
        } elseif ($params.ContainsKey('UserName') -and $params.ContainsKey('Password') -and !$params.ContainsKey('Expiration')) {
          [K3Y]::New($UserName, $Password);
        } elseif ($params.ContainsKey('UserName') -and !$params.ContainsKey('Password') -and !$params.ContainsKey('Expiration')) {
          $passwd = if ($IsInteractive) { Read-Host -AsSecureString -Prompt "Password" } else { [securestring]::new() }
          [K3Y]::New($UserName, $passwd);
        } elseif (!$params.ContainsKey('UserName') -and $params.ContainsKey('Password') -and !$params.ContainsKey('Expiration')) {
          $usrName = if ($IsInteractive) { Read-Host -Prompt "UserName" } else { [System.Environment]::GetEnvironmentVariable('UserName') }
          [K3Y]::New($usrName, $Password);
        } elseif (!$params.ContainsKey('UserName') -and !$params.ContainsKey('Password') -and $params.ContainsKey('Expiration')) {
          if ($IsInteractive) {
            $usrName = Read-Host -Prompt "UserName"; $passwd = Read-Host -AsSecureString -Prompt "Password";
            [K3Y]::New($usrName, $passwd);
          } else {
            [K3Y]::New($Expiration);
          }
        } elseif (!$params.ContainsKey('UserName') -and $params.ContainsKey('Password') -and $params.ContainsKey('Expiration')) {
          $usrName = if ($IsInteractive) { Read-Host -Prompt "UserName" } else { [System.Environment]::GetEnvironmentVariable('UserName') }
          [K3Y]::New($usrName, $Password, $Expiration);
        } else {
          [K3Y]::New();
        }
      } else {
        Write-Verbose "System.Management.Automation.ParameterBindingException: Could Not Resolve ParameterSetname."
        [K3Y]::New();
      }
    )
    if ($Protect.IsPresent) { $k3y.User.Protect() };
  }

  end {
    if ($AsString.IsPresent) {
      return ($k3y | xconvert ToString)
    }
    return $k3y
  }
}
