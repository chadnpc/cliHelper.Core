function Get-WifiProfile {
  [CmdletBinding()]
  param (
  )

  process {
    # wifi passwords
    # $WifiPasswords = (netsh wlan show profiles) | Select-String "\:(.+)$" | ForEach-Object { $name = $_.Matches.Groups[1].Value.Trim(); $_ } | ForEach-Object { (netsh wlan show profile name="$name" key=clear) } | Select-String "Key Content\W+\:(.+)$" | ForEach-Object { $pass = $_.Matches.Groups[1].Value.Trim(); $_ } | ForEach-Object { [PSObject]@{ PROFILE_NAME = $name; PASSWORD = $pass } } | Format-Table -AutoSize
    # $WifiPasswords | Out-File $env:USERPROFILE\Desktop\WifiPasswrds_Backup.txt

    $temFile = New-TempFile
    $netusrRes = $(netsh wlan show profile HUAWEI-E8231-77ce) | Out-File $temFile
    for ($i = 0; $i -lt $netusrRes.Count; $i++) {
      if ($Line -like "------*") { $title = $netusrRes[($i - 1)] }
      $title
    }
  }
}