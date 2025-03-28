function Get-WebConfigurationSetting {
  <#
    .Synopsis
        Gets settings from web configuration
    .Description
        Gets appSettings from web configuration file
    .Example
        Get-WebConfigurationSetting "MySetting"
    .Link
        ConvertTo-ModuleService
    #>
  [OutputType([Object])]
  param(
    # The name of the setting
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $true)]
    [Alias('Name')]
    [string]$Setting
  )

  process {
    #region Load Config Store
    # If the $request variable and Path_Info variable are found, use the nearby web.config
    if ($Request -and $request.Params -and $request.Params['Path_Info']) {
      $path = "$((Split-Path $request['Path_Info']))"

      $webConfigStore = [Web.Configuration.WebConfigurationManager]::OpenWebConfiguration($path)
    } else {
      # Otherwise, try the one at the local path
      try {
        $webConfigStore = [Web.Configuration.WebConfigurationManager]::OpenWebConfiguration($pwd)
      } catch {
        $null
      }
    }
    #endregion Load Config Store

    if (!$webConfigStore) { return }

    #region Get the custom setting
    $customSetting = $webConfigStore.AppSettings.Settings["$Setting"];

    # If there is a value, return it.
    if ($CustomSetting) {
      $CustomSetting.Value
    }
    #endregion Get the custom setting

  }
}
