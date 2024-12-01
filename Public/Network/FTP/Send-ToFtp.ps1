function Send-ToFtp($file) {
  #$File = "c:\users\vladimir\desktop\test.xlsx"
  $ftp = 'ftp://proftpd:123@ubuntu64:21/estel/test.xlsx'
  $webclient = New-Object System.Net.WebClient
  $uri = New-Object System.Uri($ftp)
  $webclient.UploadFile($uri, $File)
}