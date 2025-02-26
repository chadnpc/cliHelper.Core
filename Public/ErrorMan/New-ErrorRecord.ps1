function New-ErrorRecord {
  # .SYNOPSIS
  #     A function to make it easy to create custom ErrorsRecords for "PowerShell noobs" like me.

  # .DESCRIPTION
  #     Helps when writing complex errors with little knowledge on /dotnet/api/{ErrorID}(s) or ErrorCategories.
  #     All you gotta do is think what the errorId NAME might be and use tab completion.

  # .EXAMPLE
  #     PS C:\> $ErrRec = New-Error -ErrorId System.DllNotFoundException -RecommendedAction "Take a deep breath; .... TaBleFLIP. (⌐■_■) Quit!" -Category ObjectNotFound
  #     PS C:\> Write-Error $ErrRec -Category $ErrRec.CategoryInfo.Category

  # .EXAMPLE
  #     PS C:\> New-ErrorRecord -msg "CustomMessage" -ErrorId file<tab><tab> -Category Obj<tab><tab>

  #     CustomMessage. This Exception Is Thrown When A Requested Object Is Not Found In The Underlying Directory Store.
  #     + CategoryInfo          : ObjectNotFound: (New-ErrorRecord... ObjectNotFound:String) [], FileLoadException
  #     + FullyQualifiedErrorId : System.IO.FileLoadException

  #     # This example shows the use of <tab> expansion help with New-ErrorRecord.
  #     # All I had to do was write :
  #     # -ErrorId <Keyword_I_think_Might_Be_in_Exception's_TpeName> and keep PRESSING <TAB> until I GET the perfect ErrorId.

  # .EXAMPLE
  #     PS C:\> $ERRrecord = New-ErrorRecord -ErrorId System.StackOverflowException -Category InvalidOperation
  #     # Then you can # $PSCmdlet.ThrowTerminatingError($ERRrecord)
  #     #or
  #     Write-Error -ErrorRecord $ERRrecord

  # .INPUTS
  #     [string]

  # .OUTPUTS
  #     [System.Management.Automation.ErrorRecord]

  # .NOTES
  #     ErrorIds and Exceptions are from: https://powershellexplained.com/2017-04-07-all-dotnet-exception-list
  #     I' am truly thankful to 'Kevin Marquette' for compiling that list.

  # .LINK
  #     ErrorManager
  [Alias('New-Error')]
  [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'default')]
  [OutputType([System.Management.Automation.ErrorRecord])]
  param (
    # A short Message that sums up all the error
    [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'default')]
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'ByException')]
    [Alias('msg')]
    [ValidateNotNullorEmpty()]
    [String]$Message,

    # For example An exception you already got from the pipeline.
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByException')]
    [System.Exception]$Exception,

    # Qualified Error Id, or Exception typename.
    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'default')]
    [Alias('Id', 'QualifiedErrorId')]
    [ArgumentCompleter({
        [OutputType([System.Management.Automation.CompletionResult])]
        param([string]$CommandName, [string]$ParameterName, [string]$WordToComplete, [System.Management.Automation.Language.CommandAst]$CommandAst, [System.Collections.IDictionary]$FakeBoundParameters)
        $CompletionResults = [System.Collections.Generic.List[System.Management.Automation.CompletionResult]]::new()
        Get-Variable -Name AllExptnTypes -Scope Global | Select-Object -ExpandProperty value | Select-Object -ExpandProperty Typename | Where-Object { $_ -like "*$wordToComplete*" } | ForEach-Object { $CompletionResults.Add([System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)) }
        return $CompletionResults
      })]
    [System.String]$ErrorId,

    # Error Category
    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'default')]
    [Alias('c', 'Category')]
    [ArgumentCompleter({
        [OutputType([System.Management.Automation.CompletionResult])]
        param([string]$CommandName, [string]$ParameterName, [string]$WordToComplete, [System.Management.Automation.Language.CommandAst]$CommandAst, [System.Collections.IDictionary]$FakeBoundParameters)
        $CompletionResults = [System.Collections.Generic.List[System.Management.Automation.CompletionResult]]::new()
        [System.Management.Automation.ErrorCategory].GetMembers() | Where-Object { $_.MemberType -eq 'Field' -and $_.Name -notlike "*__*" } | Select-Object -ExpandProperty Name | Where-Object { $_ -like "*$wordToComplete*" } | ForEach-Object { $CompletionResults.Add([System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)) }
        return $CompletionResults
      })]
    [System.String]$ErrorCategory = 'NotSpecified',

    [Parameter(Mandatory = $false, Position = 3, ParameterSetName = 'default')]
    [string]$CategoryReason,

    # Description
    [Parameter(Mandatory = $false, Position = 4, ParameterSetName = 'default')]
    [Alias('d', 'desc')]
    [System.String]$Description,

    # Recommended Action to avoid the exception
    [Parameter(Mandatory = $false, Position = 5, ParameterSetName = 'default')]
    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'ByException')]
    [Alias('rca', 'Recommendation')]
    [System.String]$RecommendedAction,

    [Parameter(Mandatory = $false, Position = 6, ParameterSetName = 'default')]
    [System.Exception]$InnerException,

    [Parameter(Mandatory = $false, Position = 7, ParameterSetName = 'default')]
    [Alias('Target', 'OffendingObject')]
    [System.Object]$TargetObject
  )

  DynamicParam {
    $DynamicParams = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
    $attributes = [System.Management.Automation.ParameterAttribute]::new(); $attHash = @{
      Position                        = 8
      ParameterSetName                = '__AllParameterSets'
      Mandatory                       = $False
      ValueFromPipeline               = $true
      ValueFromPipelineByPropertyName = $true
      ValueFromRemainingArguments     = $true
      HelpMessage                     = 'Allows splatting with arguments that do not apply. Do not use directly.'
      DontShow                        = $False
    }; $attHash.Keys | ForEach-Object { $attributes.$_ = $attHash.$_ }
    $attributeCollection.Add($attributes)
    # $attributeCollection.Add([System.Management.Automation.ValidateSetAttribute]::new([System.Object[]]$ValidateSetOption))
    # $attributeCollection.Add([System.Management.Automation.ValidateRangeAttribute]::new([System.Int32[]]$ValidateRange))
    # $attributeCollection.Add([System.Management.Automation.ValidateNotNullOrEmptyAttribute]::new())
    # $attributeCollection.Add([System.Management.Automation.AliasAttribute]::new([System.String[]]$Aliases))
    $RuntimeParam = [System.Management.Automation.RuntimeDefinedParameter]::new("IgnoredArguments", [Object[]], $attributeCollection)
    $DynamicParams.Add("IgnoredArguments", $RuntimeParam)
    return $DynamicParams
  }

  process {
    $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
    $oeap = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue'
    $PsCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
    # $PsBoundParameters["Cmdlet"] = $(Get-Variable -Scope $($NestedPromptLevel + 1) PSCmdlet).Value
    try {
      $ExcepnTypeName = if (!$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('InnerException') -and $PSCmdlet.ParameterSetName -eq 'default') { $ErrorId } elseif ($PSCmdlet.ParameterSetName -eq 'ByException') { $Exception.pstypenames[0] }
      $InnerException = New-Object -TypeName $ExcepnTypeName
      $ExcepnDescr = [string]$($AllExptnTypes | Where-Object { $_.TypeName -eq "$ExcepnTypeName" }).Description
      $RecommendedAction = if (![string]::IsNullOrEmpty($RecommendedAction)) { "`n    + RecommendedAction     : $RecommendedAction" }else { [string]::Empty }
      $MsgString = if ([string]::IsNullOrEmpty($Message)) { [string]$($InnerException.Message) }else { $Message }
      $ErrorMessage = "{0} {1}{2}" -f $MsgString, $ExcepnDescr, $RecommendedAction
      # Not sure how this is used for, but ... # TODO: Add a way to create full exception, with members like { Data, HelpLink, Source, StackTrace, WasThrownFromThrowStatement ...}
      $HelpLink = if ([string]::IsNullOrEmpty($HelpLink)) { "https://docs.microsoft.com/en-us/dotnet/api/$ExcepnTypeName" }
      $TargetObject = if ($PsCmdlet.MyInvocation.BoundParameters.ContainsKey('TargetObject') -and $null -eq $TargetObject) { [string]::Empty }
      $Exception = New-Object -TypeName $ExcepnTypeName -ArgumentList ("$ErrorMessage", "$InnerException")
      $ErrorRecord = [System.Management.Automation.ErrorRecord]::new($Exception, $ExcepnTypeName.Split('.')[-1], $ErrorCategory, $TargetObject)
      $IsSuccess = $?
    } catch {
      $IsSuccess = $false
      $Errxceptn = $_
    } finally {
      $Execution = [PSCustomObject]@{
        Output    = $ErrorRecord
        IsSuccess = $IsSuccess
        Error     = $Errxceptn
      }
      $EndMsg = $(if ($Execution.IsSuccess) { "Created Successfully." } else { "Completed With Errors. Check the log file : $LogPath" })
    }
  }

  end {
    Out-Verbose $fxn "$EndMsg"
    $ErrorActionPreference = $oeap
    return $Execution.Output
  }
}