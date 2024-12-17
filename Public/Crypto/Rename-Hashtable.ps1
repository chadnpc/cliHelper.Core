function Rename-Hashtable {

  [cmdletbinding(SupportsShouldProcess, DefaultParameterSetName = "Pipeline")]
  [alias("rht")]

  Param(
    [parameter(
      Position = 0,
      Mandatory,
      HelpMessage = "Enter the name of your hash table variable without the `$",
      ParameterSetName = "Name"
    )]
    [ValidateNotNullorEmpty()]
    [string]$Name,
    [parameter(
      Position = 0,
      Mandatory,
      ValueFromPipeline,
      ParameterSetName = "Pipeline"
    )]
    [ValidateNotNullorEmpty()]
    [object]$InputObject,
    [parameter(
      Position = 1,
      Mandatory,
      HelpMessage = "Enter the existing key name you want to rename")]
    [ValidateNotNullorEmpty()]
    [string]$Key,
    [parameter(position = 2, Mandatory, HelpMessage = "Enter the NEW key name"
    )]
    [ValidateNotNullorEmpty()]
    [string]$NewKey,
    [switch]$Passthru,
    [ValidateSet("Global", "Local", "Script", "Private", 0, 1, 2, 3)]
    [ValidateNotNullOrEmpty()]
    [string]$Scope = "Global"
  )

  Begin {
    Write-Verbose -Message "Starting $($MyInvocation.Mycommand)"
    Write-Verbose "using parameter set $($PSCmdlet.ParameterSetName)"
  }

  Process {
    Write-Verbose "PSBoundparameters"
    Write-Verbose $($PSBoundParameters | Out-String)
    #validate Key and NewKey are not the same
    if ($key -eq $NewKey) {
      Write-Warning "The values you specified for -Key and -NewKey appear to be the same. Names are NOT case-sensitive"
      #bail out
      Return
    }

    Try {
      #validate variable is a hash table
      if ($InputObject) {
        #create a completely random name to avoid any possible naming collisions
        $name = [system.io.path]::GetRandomFileName()
        Write-Verbose "Creating temporary hashtable ($name) from pipeline input"
        Set-Variable -Name $name -Scope $scope -Value $InputObject -WhatIf:$False
        $passthru = $True
      } else {
        Write-Verbose "Using hashtable variable $name"
      }

      Write-Verbose (Get-Variable -Name $name -Scope $scope | Out-String)
      Write-Verbose "Validating $name as a hashtable in $Scope scope."
      #get the variable
      $var = Get-Variable -Name $name -Scope $Scope -ErrorAction Stop
      Write-Verbose "Detected a $($var.value.GetType().fullname)"

      Write-Verbose "Testing for key $key"
      if (!$var.value.Contains($key)) {
        Write-Warning "Failed to find the key $key in the hashtable."
        #bail out
        Return
      }
      if ( $var.Value -is [hashtable]) {
        #create a temporary copy

        Write-Verbose "Cloning a temporary hashtable"
        <#
                Use the clone method to create a separate copy.
                If you just assign the value to $temphash, the
                two hash tables are linked in memory so changes
                to $tempHash are also applied to the original
                object.
                #>
        $tempHash = $var.Value.Clone()

        if ($pscmdlet.ShouldProcess($NewKey, "Replace key $key")) {
          Write-Verbose "Writing the new hashtable to variable named $hashname"
          #create a key with the new name using the value from the old key
          Write-Verbose "Adding new key $newKey to the temporary hashtable"
          $tempHash.Add($NewKey, $tempHash.$Key)
          #remove the old key
          Write-Verbose "Removing $key"
          $tempHash.Remove($Key)
          #write the new value to the variable
          Write-Verbose "Writing the new hashtable to variable named $Name"
          Write-Verbose ($tempHash | Out-String)
          Set-Variable -Name $Name -Value $tempHash -Scope $Scope -Force -PassThru:$Passthru |
            Select-Object -ExpandProperty Value
        }
      } elseif ($var.value -is [System.Collections.Specialized.OrderedDictionary]) {
        Write-Verbose "Processing as an ordered dictionary"
        $varHash = $var.value
        #find the index number of the existing key
        $i = -1
        Do {
          $i++
        } Until (($varHash.GetEnumerator().name)[$i] -eq $Key)

        #save the current value
        $val = $varhash.item($i)

        if ($pscmdlet.ShouldProcess($NewKey, "Replace key $key at $i")) {
          #remove at the index number
          $varhash.RemoveAt($i)
          #insert the new value at the index number
          $varhash.Insert($i, $NewKey, $val)
          Write-Verbose "Writing the new hashtable to variable named $name"
          Write-Verbose ($varHash | Out-String)
          Set-Variable -Name $name -Value $varhash -Scope $Scope -Force -PassThru:$Passthru |
            Select-Object -ExpandProperty Value
        }
      } else {
        Write-Warning "The variable $name does not appear to be a hash table or ordered dictionaryBet"
      }
    }

    Catch {
      Write-Warning "Failed to find a variable with a name of $Name. $($_.exception.message)."
    }

    Write-Verbose "Rename complete."
  }

  End {
    #clean up any temporary variables
    if ($InputObject) {
      Write-Verbose "Removing temporary variable $name"
      Remove-Variable -Name $Name -Scope $scope -WhatIf:$False
    }
    Write-Verbose -Message "Ending $($MyInvocation.Mycommand)"
  }
}
