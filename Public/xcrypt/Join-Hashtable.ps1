function Join-Hashtable {
  [cmdletbinding()]
  [OutputType([System.Collections.Hashtable])]
  Param (
    [hashtable]$First,
    [hashtable]$Second,
    [switch]$Force
  )

  #create clones of hashtables so originals are not modified
  $Primary = $First.Clone()
  $Secondary = $Second.Clone()

  #check for any duplicate keys
  $duplicates = $Primary.keys | Where-Object { $Secondary.ContainsKey($_) }
  if ($duplicates) {
    foreach ($item in $duplicates) {
      if ($force) {
        #force primary key, so remove secondary conflict
        $Secondary.Remove($item)
      } else {
        Write-Host "Duplicate key $item" -ForegroundColor Yellow
        Write-Host "A $($Primary.Item($item))" -ForegroundColor Yellow
        Write-Host "B $($Secondary.Item($item))" -ForegroundColor Yellow
        $r = Read-Host "Which key do you want to KEEP [AB]?"
        if ($r -eq "A") {
          $Secondary.Remove($item)
        } elseif ($r -eq "B") {
          $Primary.Remove($item)
        } Else {
          Write-Warning "Aborting operation"
          Return
        }
      } #else prompt
    }
  }
  #join the two hash tables
  $Primary + $Secondary
}
