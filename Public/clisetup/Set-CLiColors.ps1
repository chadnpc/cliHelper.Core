function Set-CLiColors {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
  )

  begin {
  }

  process {
    if ($PSCmdlet.ShouldProcess("Target", "Set colors")) {}
  }
}