# PowerShell zombie art conversion
$e = [char]27
foreach ($j in @('f','b')) {
    $base = if ($j -eq 'f') { 3 } else { 4 }
    0..7 | ForEach-Object {
        New-Variable -Name "$j$_" -Value "$e[${base}${_}m" -Scope Script
    }
}
0..7 | ForEach-Object {
    New-Variable -Name "fbright$_" -Value "$e[9${_}m" -Scope Script
}
$bld = "$e[1m"
$rst = "$e[0m"
$inv = "$e[7m"

$art = @"
   
             Hit any key to continue
              _
             |▀|
             {●}■■■(■)■   ////~/
             |_|   \|'    $($f1)| o o|
                    \|▀■▄ $($f1)( c  )            ____
                     $($f5)▀■▄\▄ $($f1)\= /            ||   \_
                      $($f5)▄▄▄▄|▄$($f6)               ||     |
                      $($f5)▄▄|▄|▄$($f6)            ...||__/|-"
                      $($f5)▄|▄▄▄$($f6)           ──|───────'──
                       \ ||          |_____________|
                        |||          || ||     || ||
                        |||          || ||     || ||
────────────────────────|||──────────||─||─────||─||──
                        |__ >        || ||     || ||
 $($rst)
"@

Write-Host $art
