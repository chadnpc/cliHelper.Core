function Set-Snippets {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (

  )
  process {
    if ($PSCmdlet.ShouldProcess("Target", "Set Snippets")) {}
  }
}