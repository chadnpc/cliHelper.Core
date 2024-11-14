function Get-AkaMSDownloadLink([string]$Channel, [string]$Quality, [bool]$Internal, [string]$Product, [string]$Architecture) {
    # Get-AkaMSDownloadLink -Channel $NormalizedChannel -Quality $NormalizedQuality -Internal $Internal -Product $ProductName -Architecture $Architecture
    Write-Invocation $MyInvocation

    #quality is not supported for LTS or current channel
    if (![string]::IsNullOrEmpty($Quality) -and (@("LTS", "current") -contains $Channel)) {
        $Quality = ""
        Out-Warning "Specifying quality for current or LTS channel is not supported, the quality will be ignored."
    }
    Out-Verbose "Retrieving primary payload URL from aka.ms link for channel: '$Channel', quality: '$Quality' product: '$Product', os: 'win', architecture: '$Architecture'."
    #construct aka.ms link
    $akaMsLink = "https://aka.ms/dotnet"
    if ($Internal) {
        $akaMsLink += "/internal"
    }
    $akaMsLink += "/$Channel"
    if (-not [string]::IsNullOrEmpty($Quality)) {
        $akaMsLink += "/$Quality"
    }
    $akaMsLink += "/$Product-win-$Architecture.zip"
    Out-Verbose "Constructed aka.ms link: '$akaMsLink'."
    $akaMsDownloadLink = $null

    for ($maxRedirections = 9; $maxRedirections -ge 0; $maxRedirections--) {
        #get HTTP response
        #do not pass credentials as a part of the $akaMsLink and do not apply credentials in the GetHTTPResponse function
        #otherwise the redirect link would have credentials as well
        #it would result in applying credentials twice to the resulting link and thus breaking it, and in echoing credentials to the output as a part of redirect link
        $Response = GetHTTPResponse -Uri $akaMsLink -HeaderOnly $true -DisableRedirect $true -DisableFeedCredential $true
        Out-Verbose "Received response:`n$Response"

        if ([string]::IsNullOrEmpty($Response)) {
            Out-Verbose "The link '$akaMsLink' is not valid: failed to get redirect location. The resource is not available."
            return $null
        }

        #if HTTP code is 301 (Moved Permanently), the redirect link exists
        if ($Response.StatusCode -eq 301) {
            try {
                $akaMsDownloadLink = $Response.Headers.GetValues("Location")[0]

                if ([string]::IsNullOrEmpty($akaMsDownloadLink)) {
                    Out-Verbose "The link '$akaMsLink' is not valid: server returned 301 (Moved Permanently), but the headers do not contain the redirect location."
                    return $null
                }

                Out-Verbose "The redirect location retrieved: '$akaMsDownloadLink'."
                # This may yet be a link to another redirection. Attempt to retrieve the page again.
                $akaMsLink = $akaMsDownloadLink
                continue
            } catch {
                Out-Verbose "The link '$akaMsLink' is not valid: failed to get redirect location."
                return $null
            }
        } elseif ((($Response.StatusCode -lt 300) -or ($Response.StatusCode -ge 400)) -and (-not [string]::IsNullOrEmpty($akaMsDownloadLink))) {
            # Redirections have ended.
            return $akaMsDownloadLink
        }

        Out-Verbose "The link '$akaMsLink' is not valid: failed to retrieve the redirection location."
        return $null
    }

    Out-Verbose "Aka.ms links have redirected more than the maximum allowed redirections. This may be caused by a cyclic redirection of aka.ms links."
    return $null
}

# ($DownloadLink, $SpecificVersion, $EffectiveVersion) = Get-AkaMsLink-And-Version $NormalizedChannel $NormalizedQuality $Internal $NormalizedProduct $CLIArchitecture




function Get-NormalizedProduct([string]$Runtime) {
    Write-Invocation $MyInvocation
    switch ($Runtime) {
        { $_ -eq "dotnet" } { return "dotnet-runtime" }
        { $_ -eq "aspnetcore" } { return "aspnetcore-runtime" }
        { $_ -eq "windowsdesktop" } { return "windowsdesktop-runtime" }
        { [string]::IsNullOrEmpty($_) } { return "dotnet-sdk" }
        default { throw "'$Runtime' is not a supported value for -Runtime option, supported values are: dotnet, aspnetcore, windowsdesktop. If you think this is a bug, report it at https://github.com/dotnet/install-scripts/issues." }
    }
}


$CLIArchitecture = amd64
$NormalizedQuality = Get-NormalizedQuality $Quality
Out-Verbose "Normalized quality: '$NormalizedQuality'"
$NormalizedChannel = Get-NormalizedChannel $Channel
Out-Verbose "Normalized channel: '$NormalizedChannel'"
$NormalizedProduct = Get-NormalizedProduct $Runtime
Out-Verbose "Normalized product: '$NormalizedProduct'"
$FeedCredential = ValidateFeedCredential $FeedCredential

$InstallRoot = Resolve-Installation-Path $InstallDir
Out-Verbose "InstallRoot: $InstallRoot"
$ScriptName = $MyInvocation.MyCommand.Name
$dotnetPackageRelativePath = Resolve-AssetName $assetName -And -RelativePath -Runtime $Runtime

$feeds = Get-Feeds-To-Use
$DownloadLinks = @()

function Get-AkaMsLink-And-Version([string] $NormalizedChannel, [string] $NormalizedQuality, [bool] $Internal, [string] $ProductName, [string] $Architecture) {
    $AkaMsDownloadLink = Get-AkaMSDownloadLink -Channel $NormalizedChannel -Quality $NormalizedQuality -Internal $Internal -Product $ProductName -Architecture $Architecture
    if ([string]::IsNullOrEmpty($AkaMsDownloadLink)) {
        if (-not [string]::IsNullOrEmpty($NormalizedQuality)) {
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