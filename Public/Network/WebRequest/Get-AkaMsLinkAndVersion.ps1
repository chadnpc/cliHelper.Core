function Get-AkaMsLinkAndVersion([string] $NormalizedChannel, [string] $NormalizedQuality, [bool] $Internal, [string] $ProductName, [string] $Architecture) {
  $AkaMsDownloadLink = Get-AkaMSDownloadLink -Channel $NormalizedChannel -Quality $NormalizedQuality -Internal $Internal -Product $ProductName -Architecture $Architecture
  if ([string]::IsNullOrEmpty($AkaMsDownloadLink)) {
    if (![string]::IsNullOrEmpty($NormalizedQuality)) {
      # if quality is specified - exit with error - there is no fallback approach
      Out-Verbose $fxn "Failed to locate the latest version in the channel '$NormalizedChannel' with '$NormalizedQuality' quality for '$ProductName', os: 'win', architecture: '$Architecture'."
      Out-Verbose $fxn "Refer to: https://aka.ms/dotnet-os-lifecycle for information on .NET Core support."
      throw "aka.ms link resolution failure"
    }
    Out-Verbose "Falling back to latest.version file approach."
    return ($null, $null, $null)
  } else {
    Out-Verbose "Retrieved primary named payload URL from aka.ms link: '$AkaMsDownloadLink'."
    Out-Verbose "Downloading using legacy url will not be attempted."

    #get version from the path
    $pathParts = $AkaMsDownloadLink.Split('/')
    if ($pathParts.Length -ge 2) {
      $SpecificVersion = $pathParts[$pathParts.Length - 2]
      Out-Verbose "Version: '$SpecificVersion'."
    } else {
      Out-Verbose $fxn "Failed to extract the version from download link '$AkaMsDownloadLink'."
      return ($null, $null, $null)
    }

    #retrieve effective (product) version
    $EffectiveVersion = Get-Product-Version -SpecificVersion $SpecificVersion -PackageDownloadLink $AkaMsDownloadLink
    Out-Verbose "Product version: '$EffectiveVersion'."

    return ($AkaMsDownloadLink, $SpecificVersion, $EffectiveVersion);
  }
}