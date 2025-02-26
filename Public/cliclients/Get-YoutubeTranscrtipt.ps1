function Get-YoutubeTranscrtipt {
  [CmdletBinding()]
  param (
   [Parameter(Mandatory = $true)]
   [IO.FileInfo]$File
  )

  process {
    $t = Get-Content $File.FullName | Split-Line | % { $_.Substring(13) };
    $s = [System.Text.StringBuilder]::new();
    $t.ForEach({ [void]$s.Append("$_`n") });
    return $s.ToString()
  }
}
