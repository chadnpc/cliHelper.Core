function Get-HostOs {
  [CmdletBinding()][OutputType([string])]
  param ()

  process {
    return [xcrypt]::Get_Host_Os()
  }
}