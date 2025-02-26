function Get-GistFiles {
  # .SYNOPSIS
  #     Get gist Files
  # .DESCRIPTION
  #     A longer description of the function, its purpose, common use cases, etc.
  # .EXAMPLE
  #     $Name   = "P0t4t0_ex.ps1"
  #     $params = @{
  #         UserName    = '6r1mh04x'
  #         SecureToken = Read-Host -Prompt "Github Api Token" -AsSecureString
  #         GistId      = '995856aa97ac3120cd8d92d2a6eac212'
  #     }
  #     $rawUrl = (Get-GistFiles @$params).Where({ $_.Name -eq $Name }).raw_url

  #     Fetching the raw_url of a private gist
  [OutputType([GistFile[]])]
  [CmdletBinding(DefaultParameterSetName = 'ClearT')]
  param (
    [Parameter(Position = 0, Mandatory = $true, ParameterSetName = '__AllParameterSets')]
    [Alias('UserName')]
    [string]$ownerID,

    [Parameter(Position = 1, Mandatory = $true, ParameterSetName = 'SecureT')]
    [ValidateNotNullOrEmpty()]
    [securestring]$SecureToken,

    [Parameter(Position = 1, Mandatory = $true, ParameterSetName = 'ClearT')]
    [ValidateNotNullOrEmpty()]
    [string]$GitHubToken,

    [Parameter(Position = 2, Mandatory = $true, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrEmpty()]
    [string]$GistId
  )

  begin {
    $gistFiles = $null;
  }

  process {
    $gistFiles = if ($PSCmdlet.ParameterSetName -eq 'ClearT') {
      Get-Gists -UserName $ownerID -GitHubToken $GitHubToken
    } else {
      Get-Gists -UserName $ownerID -SecureToken $SecureToken
    }
    $gistFiles = $gistFiles.Files.Where({
        $_.Id -eq $GistId
      }
    )
  }

  end {
    return $gistFiles
  }
}
