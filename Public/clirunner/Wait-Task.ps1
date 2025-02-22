function Wait-Task {
  #.DESCRIPTION
  #  Waits for a scriptblock or job to complete
  #.EXAMPLE
  #  Wait-Task "Running" { Param($ob) Start-Sleep -Seconds 3; return $ob } (Get-Process pwsh);
  #.PARAMETER ProgressMsg
  #  Message to display while waiting
  #.PARAMETER ScriptBlock
  #  Scriptblock to execute
  #.PARAMETER Job
  #  Job to execute
  #.PARAMETER InputObject
  #  Object to pass to the scriptblock
  #.OUTPUTS
  #  [PsObject]
  [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
  [OutputType([PsObject])][Alias('await')]
  Param (
    [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'Job')]
    [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ScriptBlock')]
    [Alias('m')][ValidateNotNullOrEmpty()]
    [string]$ProgressMsg = "Waiting",

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ScriptBlock')]
    [Alias('s')][ValidateNotNullOrEmpty()]
    [scriptblock]$ScriptBlock,

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Job')]
    [Alias('j')][ValidateNotNullOrEmpty()]
    [System.Management.Automation.Job]$Job,

    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'ScriptBlock')]
    [Object[]]$ArgumentList = $null
  )
  begin {
    $Result = $null
  }
  process {
    if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
      $thrJob = [ProgressUtil]::WaitJob($ProgressMsg, $ScriptBlock, $ArgumentList);
    } else {
      $thrJob = [ProgressUtil]::WaitJob($ProgressMsg, $Job);
    }
    $Result = $thrJob | Receive-Job
  }
  end {
    return $Result
  }
}
