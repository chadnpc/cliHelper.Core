#
# Module manifest for module 'cliHelper.core'
#
# Generated by: Alain Herve
#
# Generated on: 10/16/2024
#

@{
  # Script module or binary module file associated with this manifest.
  RootModule            = 'cliHelper.core.psm1'
  ModuleVersion         = '<ModuleVersion>'

  # Supported PSEditions
  # CompatiblePSEditions = @()

  # ID used to uniquely identify this module
  GUID                  = '476e31f9-5acc-433e-9fb4-17b2c584f01b'

  # Author of this module
  Author                = 'Alain Herve'

  # Company or vendor of this module
  CompanyName           = 'alainQtec'

  # Copyright statement for this module
  Copyright             = 'Copyright © <Year> Alain Herve. All rights reserved.'

  # Description of the functionality provided by this module
  Description           = '🔥 A collections of essential PowerShell functions to improve devx'

  # Minimum version of the PowerShell engine required by this module
  PowerShellVersion     = '7.0'

  # Name of the PowerShell host required by this module
  # PowerShellHostName = ''

  # Minimum version of the PowerShell host required by this module
  # PowerShellHostVersion = ''

  # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  # DotNetFrameworkVersion = ''

  # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
  ClrVersion            = '1.1.0'

  # Processor architecture (None, X86, Amd64) required by this module
  ProcessorArchitecture = 'None'
  RequiredAssemblies    = @()
  ScriptsToProcess      = @()
  TypesToProcess        = @()
  FormatsToProcess      = @()
  RequiredModules       = @(
    'cliHelper.xconvert'
    # Twilio
  )
  CmdletsToExport       = '*'
  VariablesToExport     = '*'
  AliasesToExport       = '*'
  # DscResourcesToExport = @()

  # List of all modules packaged with this module
  # ModuleList = @()

  # List of all files packaged with this module
  # FileList = @()

  # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
  PrivateData           = @{
    PSData = @{
      # Tags applied to this module. These help with module discovery in online galleries.
      Tags         = 'convert', 'xconvert'
      LicenseUri   = 'https://alain.mit-license.org/'
      ProjectUri   = 'https://github.com/alainQtec/cliHelper.core'
      IconUri      = 'https://github.com/user-attachments/assets/160c2204-4a29-47a0-a8fc-a2f441317e58'
      ReleaseNotes = "
<ReleaseNotes>
"
    } # End of PSData hashtable
  } # End of PrivateData hashtable
  # HelpInfo URI of this module
  # HelpInfoURI = ''

  # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
  # DefaultCommandPrefix = ''
}

