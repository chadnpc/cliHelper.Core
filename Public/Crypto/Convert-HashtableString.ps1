function Convert-HashtableString {
  [cmdletbinding()]
  [OutputType([System.Collections.Hashtable])]

  Param(
    [parameter(Mandatory, HelpMessage = "Enter your hashtable string", ValueFromPipeline)]
    [ValidateNotNullOrEmpty()]
    [string]$Text
  )

  Begin {
    Write-Verbose "[BEGIN  ] Starting: $($MyInvocation.Mycommand)"
  }

  Process {

    $tokens = $null
    $err = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$err)
    $data = $ast.find( { $args[0] -is [System.Management.Automation.Language.HashtableAst] }, $true)

    if ($err) {
      Throw $err
    } else {
      $data.SafeGetValue()
    }
  }

  End {
    Write-Verbose "[END    ] Ending: $($MyInvocation.Mycommand)"
  }
}
