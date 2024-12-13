function Approve-AuthenticodeSignature {
  [CmdletBinding()]
  param (
    # Parameter help description
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$pathToCheck
  )

  process {
    If (Test-Path -Path $pathToCheck -ErrorAction SilentlyContinue) {
      $AuthenticodeSig = (Get-AuthenticodeSignature -FilePath $pathToCheck)
      $cert = $AuthenticodeSig.SignerCertificate
      $FileInfo = (Get-Command $pathToCheck).FileVersionInfo
      if (Test-Path $resultOutputDir -ErrorAction SilentlyContinue) {
        $issuerInfo = "$resultOutputDir\issuerInfo.txt"
      } else {
        $issuerInfo = "$PSScriptRoot\issuerInfo.txt"
      }
      $issuer = $cert.Issuer

      #OS is older than 2016 and some built-in processes will not be signed
      if (($OSBuild -lt 14393) -and (!$AuthenticodeSig.SignerCertificate)) {
        if (($FileInfo.CompanyName -eq "Microsoft Corporation")) {
          return
        } else {
          Write-Error "Script execution terminated because a process or script that does not have any signature was detected" | Out-File $issuerInfo -Append
          $pathToCheck | Out-File $issuerInfo -Append
          $AuthenticodeSig | Format-List * | Out-File $issuerInfo -Append
          $cert | Format-List * | Out-File $issuerInfo -Append
          [Environment]::Exit(1)
        }
      }
      #check if valid
      if ($AuthenticodeSig.Status -ne "Valid") {
        Write-Error "Script execution terminated because a process or script that does not have a valid Signature was detected" | Out-File $issuerInfo -Append
        $pathToCheck | Out-File $issuerInfo -Append
        $AuthenticodeSig | Format-List * | Out-File $issuerInfo -Append
        $cert | Format-List * | Out-File $issuerInfo -Append
        [Environment]::Exit(1)
      }
      #check issuer
      if (($issuer -ne "CN=Microsoft Code Signing PCA 2011, O=Microsoft Corporation, L=Redmond, S=Washington, C=US") -and ($issuer -ne "CN=Microsoft Windows Production PCA 2011, O=Microsoft Corporation, L=Redmond, S=Washington, C=US") -and ($issuer -ne "CN=Microsoft Code Signing PCA, O=Microsoft Corporation, L=Redmond, S=Washington, C=US") -and ($issuer -ne "CN=Microsoft Code Signing PCA 2010, O=Microsoft Corporation, L=Redmond, S=Washington, C=US") -and ($issuer -ne "CN=Microsoft Development PCA 2014, O=Microsoft Corporation, L=Redmond, S=Washington, C=US")) {
        Write-Error "Script execution terminated because a process or script that is not Microsoft signed was detected" | Out-File $issuerInfo -Append
        $pathToCheck | Out-File $issuerInfo -Append
        $AuthenticodeSig | Format-List * | Out-File $issuerInfo -Append
        $cert | Format-List * | Out-File $issuerInfo -Append
        [Environment]::Exit(1)
      }
      if ($AuthenticodeSig.IsOSBinary -ne "True") {
        #If revocation is offline then test below will fail
        $IsOnline = (Get-NetConnectionProfile).IPv4Connectivity -like "*Internet*"
        if ($IsOnline) {
          $IsWindowsSystemComponent = (Test-Certificate -Cert $cert -EKU "1.3.6.1.4.1.311.10.3.6" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -WarningVariable OsCertWarnVar -ErrorVariable OsCertErrVar)
          $IsMicrosoftPublisher = (Test-Certificate -Cert $cert -EKU "1.3.6.1.4.1.311.76.8.1" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -WarningVariable MsPublisherWarnVar -ErrorVariable MsPublisherErrVar)
          if (($IsWindowsSystemComponent -eq $False) -and ($IsMicrosoftPublisher -eq $False)) {
            #Defender AV and some OS processes will have an old signature if older version is installed
            #Ignore if cert is OK and only signature is old
            if (($OsCertWarnVar -like "*CERT_TRUST_IS_NOT_TIME_VALID*") -or ($MsPublisherWarnVar -like "*CERT_TRUST_IS_NOT_TIME_VALID*") -or ($OsCertWarnVar -like "*CERT_TRUST_IS_OFFLINE_REVOCATION*") -or ($MsPublisherWarnVar -like "CERT_TRUST_IS_OFFLINE_REVOCATION")) {
              return
            }
            Write-Error "Script execution terminated because the process or script certificate failed trust check" | Out-File $issuerInfo -Append
            $pathToCheck | Out-File $issuerInfo -Append
            $AuthenticodeSig | Format-List * | Out-File $issuerInfo -Append
            $cert | Format-List * | Out-File $issuerInfo -Append
            [Environment]::Exit(1)
          }
        }
      }
    } else {
      Write-Error ("Path " + $pathToCheck + " was not found") | Out-File $issuerInfo -Append
    }
  }

  end {

  }
}