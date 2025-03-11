# ANSI Color Setup
$e = [char]27
foreach ($j in @('f','b')) {
    $base = if ($j -eq 'f') { 3 } else { 4 }
    0..7 | ForEach-Object { 
        New-Variable -Name "$j$_" -Value "$e[$base${_}m" -Scope Script 
    }
}

# Bright colors (90-97)
0..7 | ForEach-Object { 
    New-Variable -Name "g$_" -Value "$e[9${_}m" -Scope Script 
}

# Style codes
$bd = "$e[1m"
$rt = "$e[0m"
$iv = "$e[7m"

# Pacman Ghosts Art
$art = @"
  ${f1}    ██████        ${f3}    ██████        ${f6}    ██████        ${f5}    ██████
  ${f1}  ██████████      ${f3}  ██████████      ${f6}  ██████████      ${f5}  ██████████
  ${f1}██████████████    ${f3}██████████████    ${f6}██████████████    ${f5}██████████████
  ${f1}██${f7}████${f1}██${f7}████${f1}██    ${f3}██${f7}████${f3}██${f7}████${f3}██    ${f6}██${f7}█${f0}██${f7}█${f6}██${f7}█${f0}██${f7}█${f6}██    ${f5}██${f7}████${f5}██${f7}████${f5}██
  ${f1}██${f7}█${f0}██${f7}█${f1}██${f7}█${f0}██${f7}█${f1}██    ${f3}██${f7}██${f0}██${f3}██${f7}██${f0}██${f3}██    ${f6}██${f7}████${f6}██${f7}████${f6}██    ${f5}██${f0}██${f7}██${f5}██${f0}██${f7}██${f5}██
  ${f1}██████████████    ${f3}██████████████    ${f6}██████████████    ${f5}██████████████
  ${f1}██████████████    ${f3}██████████████    ${f6}██████████████    ${f5}██████████████
  ${f1}██  ██  ██  ██    ${f3}██  ██  ██  ██    ${f6}██  ██  ██  ██    ${f5}██  ██  ██  ██$rt
"@

Write-Host $art
