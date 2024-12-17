function Split-StringOnLiteralString {
  <#
      .SYNOPSIS
        Splits a string based on another literal string (as opposed to regex).
      .DESCRIPTION
        The function is designed to split strings the way its expected to be done.
        It's also designed to be backward-compatible with all versions
        of PowerShell and has been tested successfully on PowerShell v1.

      .EXAMPLE
        $result = Split-StringOnLiteralString 'foo' ' '
        # $result.GetType().FullName is System.Object[]
        # $result.Count is 1
      .EXAMPLE
        $result = Split-StringOnLiteralString 'What do you think of this function?' ' '
        # $result.Count is 7
      .INPUTS
        # This function takes two positional arguments
        # The first argument is a string, and the string to be split
        # The second argument is a string or char, and it is that which is to split the string in the first parameter
      .OUTPUTS
        Output (if any)
      .NOTES
        This function always returns an array, even when there is zero or one element in it.

        # Origin of the Idea by original author; Frank Lesniak.
        @"
        The motivation for creating this function was;
        (1) I wanted a split function that behaved more like VBScript's Split function.
        (2) I do not want to be messing around with RegEx, and
        (3) I needed code that was backward-compatible with all versions of PowerShell.
        "@ - Frank Lesniak. https://github.com/franklesniak/
      #>
  [CmdletBinding()]
  [OutputType([Object[]])]
  param (
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "The string object to split")]
    [Alias('String')]
    [string]$objToSplit,
    # Spliter char
    [Parameter(Mandatory = $false, Position = 1)]
    [Alias('Splitter')]
    [string]$objSplitter
  )
  process {
    if ($PsCmdlet.MyInvocation.BoundParameters.ContainsKey('objToSplit')) {
      if (($objToSplit.Length -gt 2) -or ($objToSplit.Length -eq 0)) {
        $ex = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList "Cannot find path '$aPath' because it does not exist."
        $category = [System.Management.Automation.ErrorCategory]::ObjectNotFound
        $errRecord = New-Object System.Management.Automation.ErrorRecord $ex, 'PathNotFound', $category, $aPath
        $psCmdlet.WriteError($errRecord)
        Write-Debug "ObjSpliter found"
      } else {
        $ex = New-Object -TypeName System.Management.Automation.ItemNotFoundException -ArgumentList "Invalid ObjToSplit"
        $category = [System.Management.Automation.ErrorCategory]::ObjectNotFound
        $errRecord = New-Object System.Management.Automation.ErrorRecord $ex, 'InvalidObjToSplit', $category, $aPath
        $PSCmdlet.ThrowTerminatingError($errRecord)
      }
    }
    if ($null -eq $objToSplit) {
      $result = @()
    }
    if ($null -eq $objSplitter) {
      Write-Warning -Message 'Object Spliter is empty string'
      # Splitter was $null; return string to be split within an array (of one element).
      $result = @($objToSplit)
    } else {
      $objSplitterInRegEx = [regex]::Escape($objSplitter)
      # With the leading comma, force encapsulation into an array so that an array is
      # returned even when there is one element:
      $result = @([regex]::Split($objToSplit, $objSplitterInRegEx))
    }

    # The following code forces the function to return an array, always, even when there are zero or one elements in the array
    [int]$itemCount = 1
    if (($null -ne $result) -and $result.GetType().FullName.Contains('[]')) {
      if (($result.Count -ge 2) -or ($result.Count -eq 0)) {
        $itemCount = $result.Count
      }
    }
    $strLowercaseFunctionName = $MyInvocation.InvocationName.ToLower()
    $boolArrayEncapsulation = $MyInvocation.Line.ToLower().Contains('@(' + $strLowercaseFunctionName + ')') -or $MyInvocation.Line.ToLower().Contains('@(' + $strLowercaseFunctionName + ' ')
    $result = $(if ($boolArrayEncapsulation) {
        $result
      } elseif ($itemCount -eq 0) {
        , @()
      } elseif ($itemCount -eq 1) {
        , (, $objToSplit)
      } else {
        $result
      }
    )
  }
  end {
    return $result
  }
}
