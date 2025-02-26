function Get-ModuleData {
  [CmdletBinding()][OutputType([hashtable])]
  param ()
  begin {
    $d = @{};
  }
  process {
    Get-ChildItem -Path "$((Get-Module cliHelper.core).ModuleBase)/en-US" -File data*.csv | ForEach-Object { $d[$_.Name.Replace('data.', '').Replace('.csv', '')] = [IO.File]::ReadAllText($_.FullName) | ConvertFrom-Csv }
  }
  end {
    return $d
  }
}