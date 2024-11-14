<#
 
.RESOURCES
    Microsoft Docs
    Get-PackageProvider         https://docs.microsoft.com/en-us/powershell/module/packagemanagement/get-packageprovider
    Install-PackageProvider     https://docs.microsoft.com/en-us/powershell/module/packagemanagement/install-packageprovider
#>
 
 
# Settings - PowerShell Preferences - Interaction
$ConfirmPreference = 'None'
$ProgressPreference = 'SilentlyContinue'
# Settings - PowerShell Preferences - Output Streams
$DebugPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
$InformationPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
 
 
 
 
#region Functions
function Get-PublishedModuleVersion {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Name
  )
 
  # access the main module page, and add a random number to trick proxies
  $url = ('https://www.powershellgallery.com/packages/{0}/?dummy={1}' -f ($Name, (Get-Random -Maximum 9999)))
  $request = [System.Net.WebRequest]::Create($url)
  # do not allow to redirect. The result is a "MovedPermanently"
  $request.AllowAutoRedirect = $false
  try {
    # send the request
    $response = $request.GetResponse()
    # get back the URL of the true destination page, and split off the version
    $response.GetResponseHeader('Location').Split('/')[-1] -as [System.Version]
    # make sure to clean up
    $response.Close()
    $response.Dispose()
  }
  catch {
    Write-Warning -Message ($_.Exception.Message)
  }
}
#endregion Functions
 
 
#region Main
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# NuGet
# If the network connection is stable.
try {
  $NuGetMinimumVersion = [System.Version](Find-PackageProvider -Name 'NuGet' -Force | Select-Object -ExpandProperty 'Version')
}
catch [System.Management.Automation.NoMatchFoundForCriteria] {
  Write-Warning "No match was found for the specified search criteria"; 
  Write-Debug "Exception: NoMatchFoundForCriteria. Trying Get-PackageSource";
}
[System.Version]$NuGetMinimumVersion = [System.Version](Find-PackageProvider -Name 'NuGet' -Force | Select-Object -ExpandProperty 'Version')
[System.Version]$NuGetInstalledVersion = [System.Version](Get-PackageProvider -ListAvailable -Name 'NuGet' -ErrorAction 'SilentlyContinue' | Select-Object -ExpandProperty 'Version')
if ( !$NuGetInstalledVersion -or $NuGetInstalledVersion -lt $NuGetMinimumVersion) {
  Install-PackageProvider 'NuGet' –Force
}
 
 
# Wanted Module
[string[]] $NameWantedModules = @('PowerShellGet', 'AudioDeviceCmdlets')
foreach ($NameModule in $NameWantedModules) {
  [System.Version]$VersionWantedModuleAvailable = [System.Version](Get-PublishedModuleVersion -Name $NameWantedModule | Select-Object -ExpandProperty 'Version')
  [System.Version]$VersionWantedModuleInstalled = [System.Version](Get-InstalledModule -Name $NameWantedModule -ErrorAction 'SilentlyContinue' | Select-Object -ExpandProperty Version)
  if ( (-not($VersionWantedModuleInstalled)) -or $VersionWantedModuleInstalled -lt $VersionWantedModuleAvailable) {
    Install-Module -Name $NameWantedModule -Repository 'PSGallery' -Scope 'AllUsers' -Force
  }
}
#endregion Main