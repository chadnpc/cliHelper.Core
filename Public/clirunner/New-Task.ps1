function New-Task {
  [CmdletBinding()][Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification = "Not changing state")]
  [OutputType([PSCustomObject])]
  [Alias('Create-Task')]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [scriptblock][ValidateNotNullOrEmpty()]
    $ScriptBlock,

    [Parameter(Mandatory = $false, Position = 1)]
    [Object[]]
    $ArgumentList,

    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateNotNullOrEmpty()][System.Management.Automation.Runspaces.Runspace]
    $Runspace = (Get-Variable ExecutionContext -ValueOnly).Host.Runspace
  )
  begin {
    $_result = $null
    $powershell = [System.Management.Automation.PowerShell]::Create()
  }
  process {
    $_Action = $(if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('ArgumentList')) {
        { Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList } -as [System.Action]
      } else {
        { Invoke-Command -ScriptBlock $ScriptBlock } -as [System.Action]
      }
    )
    $powershell = $powershell.AddScript({
        param (
          [Parameter(Mandatory = $true)]
          [ValidateNotNull()]
          [System.Action]$Action
        )
        return [System.Threading.Tasks.Task]::Factory.StartNew($Action)
      }
    ).AddArgument($_Action)
    if (!$PSCmdlet.MyInvocation.BoundParameters.ContainsKey('Runspace')) {
      $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    } else {
      Write-Verbose "[Task] Using LocalRunspace ..."
      $Runspace = [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace
    }
    if ($Runspace.RunspaceStateInfo.State -ne 'Opened') { $Runspace.Open() }
    $powershell.Runspace = $Runspace
    [ValidateNotNull()][System.Action]$_Action = $_Action;
    Write-Verbose "[Task] Runing in background ..."
  }
  end {
    return $_result
  }
}