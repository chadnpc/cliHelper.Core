function Wait-Task {
  #.DESCRIPTION
  #  Waits for a scriptblock or job to complete
  #.EXAMPLE
  # Wait-Task "waiting" { Start-Sleep -Seconds 3; $input | Out-String } (Get-Process pwsh);
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

    [Parameter(Mandatory = $false)]
    [Alias('input')]
    [PsObject]$InputObject
  )
  begin {
    $Result = $null
  }
  process {
    $threadJob = [ProgressUtil]::WaitJob($ProgressMsg, $($PSCmdlet.ParameterSetName -eq 'Job' ? $Job : $ScriptBlock), $InputObject);
    $Result = $threadJob | Receive-Job
  }
  end {
    return $Result
  }
}
