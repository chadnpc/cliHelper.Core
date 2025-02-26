function Format-SizeBytes {
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [double]$size
  )
  end {
    foreach ($unit in @('B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB')) {
      if ($size -lt 1024) {
        return [string]::Format("{0:0.##} {1}", $size, $unit).Trim();
      }
      $size /= 1024
    }
    return [string]::Format("{0:0.##} YB", $size).Trim();
  }
}
