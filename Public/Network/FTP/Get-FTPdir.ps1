# .EXAMPLE
#  $server = "ftp://d34221f77428:d2Sn1K@www.estel.ee:21/htdocs/administrator/backups"
#  Get-FTPdir $server
function Get-FTPdir($server) {
  [void] [System.Reflection.Assembly]::LoadWithPartialName("system.net")
  $ftp = [system.net.ftpwebrequest] [system.net.webrequest]::create($server)
  $ftp.method = [system.net.WebRequestMethods+ftp]::listdirectorydetails
  $response = $ftp.getresponse()
  $stream = $response.getresponsestream()

  $buffer = New-Object System.Byte[] 1024
  $encoding = New-Object System.Text.AsciiEncoding

  $outputBuffer = ""
  $foundMore = $false

  do {
    Start-Sleep -m 1000
    $foundmore = $false
    $stream.ReadTimeout = 2000
    do {
      try {
        $read = $stream.Read($buffer, 0, 1024)

        if ($read -gt 0) {
          $foundmore = $true
          $outputBuffer += ($encoding.GetString($buffer, 0, $read))
        }
      } catch { $foundMore = $false; $read = 0 }
    } while ($read -gt 0)
  } while ($foundmore)


  #$outputbuffer

  $mytable = @()

  foreach ($x in $outputBuffer.Split("`n")) {
    $temp = '' | Select-Object date, size, name
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")
    $x = $x -replace ("  ", " ")

    $temp.date = $x.Split(" ")[5..7]
    $tempdate = $temp.date
    $temp.date = "$tempdate`t"

    $temp.size = $x.Split(" ")[4]
    $tempsize = $temp.size
    $temp.size = "$tempsize`t"

    $temp.name = $x.Split(" ")[8..99]
    $tempname = $temp.name
    $temp.name = "$tempname"

    $mytable += $temp
  }
  # $mytable | Sort date -desc | Format-Table -AutoSize
  #$i = 0
  foreach ($xx in $mytable) {
    if ($xx.Name -like "*backup*") {

      #$i = $i + 1
      $webclient = New-Object System.Net.WebClient
      $backup_name = $xx.name
      $web_backup = "http://www.estel.ee/administrator/backups/" + $backup_name
      $new_backup = Get-Date -Format "yyyy-MM-dd"
      $new_backup = "\\diskstation\estelbackup\website\" + $new_backup + ".tar"
      "Downloading $web_backup to $new_backup"
      $webclient.DownloadFile($web_backup, $new_backup)

      $ServerUri = New-Object System.Uri "ftp://www.estel.ee@www.estel.ee/htdocs/administrator/backups/$backup_name"
      if ($ServerUri.Scheme -ne [system.Uri]::UriSchemeFtp) {
        " Bad URI"; return
      }

      # Get the object used to communicate with the server.
      $request = [system.Net.FtpWebRequest]::Create($serverUri)
      $request.Method = [System.Net.WebRequestMethods+ftp]::Deletefile
      $Request.Credentials = New-Object System.Net.NetworkCredential "d34221f77428", "d2Sn1K"

      $response = $request.GetResponse()
      "Delete status: {0}" -f $response.StatusDescription
      $response.Close();
    } else {
      "Could not find backup files. Exit"
    }
  }
}