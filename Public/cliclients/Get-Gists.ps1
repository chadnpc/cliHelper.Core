function Get-Gists {
  # .SYNOPSIS
  #     Gets all gists for a user
  # .DESCRIPTION
  #     A longer description of the function, its purpose, common use cases, etc.
  # .LINK
  #     Specify a URI to a help page, this will show when Get-Help -Online is used.
  # .EXAMPLE
  #     Get-Gists -UserName 'chadnpc' -SecureToken (Read-Host -Prompt "Github Api Token" -AsSecureString)
  #     Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
  [OutputType([Gist[]])]
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
    [string]$GitHubToken
  )

  begin {
    $Gists = $null; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  }

  process {
    if ($PSCmdlet.ParameterSetName -eq 'ClearT') {
      $SecureToken = $GitHubToken | xconvert ToSecurestring
    }
    if ($null -eq [GitHub]::webSession) { [void][GitHub]::createSession($ownerID, $SecureToken) }
    $auth = Invoke-RestMethod -Method Get -Uri "https://api.github.com/user" -WebSession ([GitHub]::webSession)
    if ($auth) {
      $Gists = $(Invoke-RestMethod -Method Get -Uri "https://api.github.com/users/$ownerID/gists" -WebSession $([GitHub]::webSession)) | Select-Object -Property @(
        @{l = 'Id'; e = { $_.Id } }
        @{l = 'Uri'; e = { "https://gist.github.com/$($_.owner.login)/$($_.Id)" -as [uri] } }
        @{l = 'FLOB'; e = { $_.files } }
        @{l = 'IsPublic'; e = { $_.public } }
        @{l = 'Owner'; e = { $_.owner.login } }
        @{l = 'Description'; e = { $_.description } }
      ) | Select-Object *, @{l = 'Files'; e = {
          $flob = [psobject[]]::new(0); $Names = $_.FLOB | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
          foreach ($n in $Names) { if (($_.FLOB."$n".raw_url -as [uri]).Segments[2] -eq $_.Id + '/') { $flob += $_.FLOB."$n" } }
          $flob
        }
      } -ExcludeProperty FLOB
      Write-Verbose "Found $($Gists.Count) gists"
      $Gists = foreach ($g in $Gists) {
        $_g = [Gist]::new()
        $_f = $g.Files | Select-Object *, @{l = 'Id'; e = { $g.Id } }, @{l = 'Owner'; e = { $g.Owner } }, @{l = 'IsPublic'; e = { $g.IsPublic } }
        $_f.Foreach({ $_g.AddFile([GistFile]::new($_)) });
        $_g.Description = $g.Description
        $_g.IsPublic = $g.IsPublic
        $_g.Owner = $g.Owner
        $_g.Uri = $g.Uri
        $_g.Id = $g.Id
        $_g
      }
    } else {
      throw $Error[0]
    }
  }

  end {
    return $Gists
  }
}
