function Get-EncryptedObject {
  <#
    .SYNOPSIS
        Applies several paranoid encryptions to an Object or a file.
    .DESCRIPTION
        Encryption can be applied to any item that can be converted to a byte array.
        This function may currently encrypt Objects (i.e. "System.Object") and files.
        The function employs Rijndael AES-256, Rivest-Shamir-Adleman encryption (RSA), MD5 Triple D.E.S, and other algorithms.
        Yeah, It gets Pretty paranoid!

        There is an option to store your encryption key(s) in Windows Password vault so that the
        Decryptor Function (Decryp) can use them without need of your input again.
    .NOTES
        # Some Points to Consider When Using This function:

        1. If you don't feel safe when typing or sending sensitive info to the terminal/console or via RMM,
        Then its better to use some nerdy function that uses the best well known/tested/approved standard algorithms
        That way, you know your data is secure enough. This was the whole reason why I created this function.

        2. One of this script's flaws is that it is a script (a non-obfuscated, cleartext script!).
        If you or some hacker can't get the password but have the source code you can reverse engineer to findout why you are not getting clear output.
        Thus allowing to bruteforce untill you get cleartext. Although I doubt that AES-256-GCM can be brute forced if you used a strong Password.
        Even though that eventuality is unlikely, ensure that the source code (Modified Version of this Script or anything...) is never leaked in production.
        Perhaps compile it to an encrypted binary or something.

        3. Sometimes even your local password vault is not secure enough!
        i.e: Read: https://www.hackingarticles.in/credential-dumping-windows-credential-manager/
        So If you feel unsafe Retrieve your stuff from WindowsCredentialManager, Store them on a Goober or somethin
        Then clean your local vault, ie:
        if (![bool]("Windows.Security.Credentials.PasswordVault" -as 'type';)) { [Windows.Security.Credentials.PasswordVault, Windows.Security.Credentials, ContentType = WindowsRuntime] }

        $vault = [Windows.Security.Credentials.PasswordVault]::new()
        # Suppose you have stuff in your vault. ex:
        # $vault.Add([Windows.Security.Credentials.PasswordCredential]::new(';MySecretPlan';, $(whoami), "#Test`nThis is my secret Plan written in MarkDown..."))

        $VaultContent = $vault.RetrieveAll() | select resource, userName | % {$vault.Retrieve($_.Resource, $_.UserName)} | select UserName, Resource, @{l=';Content';; e={$_.Password}};
        $VaultContent | ConvertTo-Json | Set-Content -Path $PathtoMyGoober\MyLocalVault_Export.json -Encoding UTF8
        $(Get-Item $PathtoMyGoober\MyLocalVault_Export.json).Encrypt();
        $vault.RetrieveAll() | % { $vault.Remove($vault.Retrieve($_.Resource, $_.UserName)); Write-verbose "[i] Removed $($_.Resource)" }
    .LINK
        https://github.com/alainQtec/cliHelper.Core/blob/main/Private/cliHelper.Core.xcrypt/cliHelper.Core.xcrypt.psm1
    .EXAMPLE
        $enc = Encrypt -Object "Hello World!" -Password $([ArgonCage]::GetPassword()) -KeyOutFile .\PublicKee.txt
        $dec = Decrypt -InputBytes $enc -Password $([ArgonCage]::GetPassword()) -PublicKey $(cat .\PublicKee.txt)
    #>
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'Prefer verb usage')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertSecurestringWithPlainText", '')]
  [CmdletBinding(ConfirmImpact = "Medium", DefaultParameterSetName = 'WithSecureKey')]
  [Alias('Encrypt', 'Encrypt-Object')]
  [OutputType([byte[]])]
  param (
    # The Object you want to encrypt
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = '__AllParameterSets')]
    [Alias('InputObj')]
    $Object,

    # Use a strong password. It will be used Lock Your local Key (ConvertTo-SecureString -String "Message" -SecureKey [System.Security.SecureString]) before storing in vault.
    # Add this if you want 3rd layer of security. Useful when someone(Ex: Hacker) has somehow gained admin priviledges of your PC;
    # With a locked local Password vault it will require much more than just guessing The password, or any BruteForce tool.
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'WithSecureKey')]
    [Alias('Password', 'Securestring')]
    [SecureString]$PrivateKey = [ArgonCage]::GetPassword(),

    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrEmpty()]
    [string]$PublicKey,

    # Source or the Encryption Key. Full/Path of the keyfile you already have. It will be used to lock your keys. (ConvertTo-SecureString -String "Message" -Key [Byte[]])
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'WithKey')]
    [ValidateNotNullOrEmpty()]
    [Byte[]]$Key,

    # Path OF the KeyFile (Containing You saved key base64String Key)
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'WithKeyFile')]
    [ValidateNotNullOrEmpty()]
    [string]$KeyFile,

    # FilePath to store your keys. Saves keys as base64 in an enrypted file. Ex: some_random_Name.key (Not recomended)
    [Parameter(Mandatory = $false, Position = 3, ParameterSetName = '__AllParameterSets')]
    [ValidateNotNullOrEmpty()]
    [Alias('ExportFile')]
    [string]$KeyOutFile,

    # How long you want the encryption to last. Default to one month (!Caution Your data will be LOST Forever if you do not decrypt before the Expiration date!)
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'WithVault')]
    [Parameter(Mandatory = $false, Position = 4, ParameterSetName = 'WithKey')]
    [Parameter(Mandatory = $false, Position = 3, ParameterSetName = 'WithPlainKey')]
    [Parameter(Mandatory = $false, Position = 3, ParameterSetName = 'WithSecureKey')]
    [ValidateNotNullOrEmpty()]
    [Alias('KeyExpiration')]
    [datetime]$Expiration = ([Datetime]::Now + [TimeSpan]::new(30, 0, 0, 0)),

    [Parameter(Mandatory = $false, Position = 4, ParameterSetName = 'WithSecureKey')]
    [Parameter(Mandatory = $false, Position = 4, ParameterSetName = 'WithPlainKey')]
    [Parameter(Mandatory = $false, Position = 4, ParameterSetName = 'WithVault')]
    [Parameter(Mandatory = $false, Position = 5, ParameterSetName = 'WithKey')]
    [ValidateNotNullOrEmpty()]
    [int]$Iterations = 2,

    [Parameter(Mandatory = $false, Position = 6, ParameterSetName = '__AllParameterSets')]
    [ValidateScript({
        if ([Enum]::GetNames([CryptoAlgorithm]).Contains($_)) {
          return $true
        }
        throw 'Invalid CryptoAlgorithm'
      }
    )][Alias('CryptoAlgorithm')]
    [ValidateNotNullOrEmpty()]
    [string]$Algorithm
  )

  DynamicParam {
    $DynamicParams = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
    [bool]$IsPossiblefileType = $false
    [bool]$IsArrayObject = $false
    [int]$P = 7 #(Position)
    try {
      if ($Object.count -gt 1) {
        $InputType = @()
        $IsArrayObject = $true
        foreach ($Obj in $Object) {
          $InputType += $Obj.GetType()
        }
        $InputType = $InputType | Sort-Object -Unique
      } else {
        $InputType = $Object.GetType()
      }
    } catch { $InputType = [string]::Empty }
    $IsPossiblefileTypes = @('string', 'string[]', 'System.IO.FileInfo', 'System.IO.FileInfo[]', 'System.Object', 'System.Object[]')
    if ($IsArrayObject) {
      foreach ($type in $InputType) {
        $IsPossiblefileType = [bool]($type -in $IsPossiblefileTypes) -or $IsPossiblefileType
      }
    } else {
      $IsPossiblefileType = [bool]($InputType -in $IsPossiblefileTypes)
    }
    #region OutFile
    if ($IsPossiblefileType) {
      $attributes = [System.Management.Automation.ParameterAttribute]::new(); $attHash = @{
        Position                        = $P
        ParameterSetName                = '__AllParameterSets'
        Mandatory                       = $False
        ValueFromPipeline               = $false
        ValueFromPipelineByPropertyName = $false
        ValueFromRemainingArguments     = $false
        HelpMessage                     = 'Use to specify Output File, if inputObject is a file.'
        DontShow                        = $False
      }; $attHash.Keys | ForEach-Object { $attributes.$_ = $attHash.$_ }
      $attributeCollection.Add($attributes);
      $attributeCollection.Add([System.Management.Automation.ValidateNotNullOrEmptyAttribute]::new())
      $attributeCollection.Add([System.Management.Automation.AliasAttribute]::new([System.String[]]('OutPutFile', 'DestinationFile')))
      $RuntimeParam = [System.Management.Automation.RuntimeDefinedParameter]::new("OutFile", [Object], $attributeCollection)
      $DynamicParams.Add("OutFile", $RuntimeParam)
      $P++
    }
    #endregion OutFile

    #region IgnoredArguments
    $attributes = [System.Management.Automation.ParameterAttribute]::new(); $attHash = @{
      Position                        = $P
      ParameterSetName                = '__AllParameterSets'
      Mandatory                       = $False
      ValueFromPipeline               = $true
      ValueFromPipelineByPropertyName = $true
      ValueFromRemainingArguments     = $true
      HelpMessage                     = 'Allows splatting with arguments that do not apply. Do not use directly.'
      DontShow                        = $False
    }; $attHash.Keys | ForEach-Object { $attributes.$_ = $attHash.$_ }
    $attributeCollection.Add($attributes)
    $RuntimeParam = [System.Management.Automation.RuntimeDefinedParameter]::new("IgnoredArguments", [Object[]], $attributeCollection)
    $DynamicParams.Add("IgnoredArguments", $RuntimeParam)
    #endregion IgnoredArguments
    return $DynamicParams
  }

  begin {
    $eap = $ErrorActionPreference; $ErrorActionPreference = "SilentlyContinue"
    $PsCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
    $PsW = [securestring]::new(); $nc = $null;
    $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
    $ExportsPNK = $PsCmdlet.MyInvocation.BoundParameters.ContainsKey('KeyOutFile') -and ![string]::IsNullOrEmpty($KeyOutFile)
    if ($PsCmdlet.ParameterSetName -ne 'WithKey' -and !$ExportsPNK) {
      throw 'Plese specify PublicKey "ExportFile/Outfile" Parameter.'
    }
    # Write-Invocation $MyInvocation
  }

  process {
    Write-Verbose "[+] $fxn $($PsCmdlet.ParameterSetName) ..."
    Set-Variable -Name PsW -Scope Local -Visibility Private -Option Private -Value $(switch ($PsCmdlet.ParameterSetName) {
        'WithKey' {  }
        'WithVault' {  }
        'WithSecureKey' { $PrivateKey }
        Default {
          throw 'Error!'
        }
      }
    );
    Set-Variable -Name nc -Scope Local -Visibility Private -Option Private -Value $([xcrypt]::new($Object));
    if ($PsCmdlet.MyInvocation.BoundParameters.ContainsKey('Expiration')) { $nc.key.Expiration = [Expiration]::new($Expiration) }
    if ($PsCmdlet.MyInvocation.BoundParameters.ContainsKey('PublicKey')) {
      $nc.SetPNKey($PublicKey);
    } else {
      Write-Verbose "[+] Create PublicKey (K3Y) ...";
      $PNK = New-K3Y -UserName $nc.key.User.UserName -Password $PsW -Expiration $nc.key.Expiration.date -AsString -Protect
      $nc.SetPNKey($PNK);
    }
    $encryptor = [Encryptor]::new($bytesToEncrypt, [securestring]$Password, [byte[]]$salt, [CryptoAlgorithm]$Algorithm);
    $encrypted = $encryptor.encrypt($Iterations);
    $bytes = $encrypted
    if ($ExportsPNK) {
      Write-Verbose "[i] Export PublicKey (PNK) to $KeyOutFile ..."
      $nc.key.Export($KeyOutFile, $true);
    }
    $bytes = $(if ($bytes.Equals($nc.Object.Bytes)) { $null }else { $nc.Object.Bytes })
  }

  end {
    $ErrorActionPreference = $eap
    return $bytes
  }
}
