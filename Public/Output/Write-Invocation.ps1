function Write-Invocation {
  # .SYNOPSIS
  #     Writes on line that shows the PSCmdlet's invocation and the calling functions.
  # .DESCRIPTION
  #     Reads the CallStack using Get-PSCallStack cmdlet and verbose output as one line
  # .EXAMPLE
  #     $PSCmdletName = $(Get-Variable PSCmdlet -Scope ($NestedPromptLevel + 1) -ValueOnly).MyInvocation.InvocationName
  #     Write-Invocation -Invocation $MyInvocation-msg "$PSCmdletName Started"
  param (
    # Invocation Info
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.InvocationInfo]$Invocation = $(Get-Variable MyInvocation -Scope ($NestedPromptLevel + 1) -ValueOnly),
    #number of levels to go back in the call stack
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 99)]
    [int]$level,
    [Switch]$FullStack,
    [switch]$IncludeArgs
  )
  begin { $oeap = $ErrorActionPreference; $ErrorActionPreference = 'SilentlyContinue' }
  Process {
    $Stack = Get-PSCallStack
    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('levels') -and ![string]::IsNullOrEmpty($level.ToString())) {
      $level = [Math]::Min( $level, $Stack.Length - 1 )
      if ($FullStack) {
        $WHOLEstack = @($Stack[$level])
      } else {
        $CommandList = @($Stack[$level] | Select-Object -ExpandProperty Command)
      }
    } else {
      if ($FullStack) {
        $WHOLEstack = @($Stack)
      } else {
        $CommandList = @($Stack | Select-Object -ExpandProperty Command)
      }
    }
    $rStack = & {
      if ($FullStack -and [bool]$WHOLEstack) {
        $stackHash = @{
          Command          = $WHOLEstack.Command
          Position         = $WHOLEstack.Position
          Location         = $WHOLEstack.Location
          FunctionName     = $WHOLEstack.FunctionName
          ScriptLineNumber = $WHOLEstack.ScriptLineNumber
        }
        return $($stackHash.Keys | ForEach-Object { "$_ = $($stackHash.$_)" }) -join ', '
      } else {
        [void][System.Array]::Reverse($CommandList)
        $FilteredL = @($CommandList | ForEach-Object { $i = if (![string]::IsNullOrEmpty($MyInvocation.MyCommand.Name)) { $_.Replace($MyInvocation.MyCommand.Name, '') }else { [string]::Empty }; try { $i.Replace('<ScriptBlock>', '') } catch { $i } })
        $stackLine = $(@(for ($i = 0; $i -lt $FilteredL.Count; $i++) { if ($i -eq 0) { "[$(if ([string]::IsNullOrEmpty($FilteredL[$i])) { 'Command' }else { $FilteredL[$i] })] Started" } else { $FilteredL[$i] } }) -join ' ')
        if ($IncludeArgs) { $stackLine += $('Argslist : ' + $(($Invocation.BoundParameters.Keys | ForEach-Object { "-$_ `"$($Invocation.BoundParameters[$_])`"" }) -join ' ')) }
        $stackLine += ' ...'
        return $stackLine
      }
    }
    Out-Verbose $rStack
  }
  end {
    $ErrorActionPreference = $oeap
  }
}
