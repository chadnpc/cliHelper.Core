<# :: netmon.bat - a network speed monitor directly on the taskbar (changes title every second)
@echo off&set "0=%~f0"
reg query HKU\S-1-5-19>nul 2>nul||(powershell -nop -c start $env:0 -v runas -win 2&exit)
powershell -nop -noni -c iex(gc $env:0 -deli "`0")&exit
#>

$unit=1MB
#$unit=1KB #uncomment to measure in KiloBytes/second

$ErrorActionPreference=0
gwmi win32_networkadapter -filter "netconnectionstatus=2" |% {
  $r='"\Network Interface('+$_.name+')\Bytes Received/sec"';
  $s='"\Network Interface('+$_.name+')\Bytes Sent/sec"'
}
typeperf $r $s -y |% {
  $a=$_ -split '"'; $dl=($a[3]/$unit).tostring('0.000').padright(9,'0'); $up=($a[5]/$unit).tostring('0.000').padright(9,'0')
  $host.ui.RawUI.WindowTitle="$dl / $up"
  if ($host.UI.RawUI.WindowSize.Height -gt 1) {mode 50,1}
}