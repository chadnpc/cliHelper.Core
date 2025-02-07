function Confirm-Choice {
  # .SYNOPSIS
  #   Prompts the user to choose a yes/no option.
  # .DESCRIPTION
  #   The message parameter is presented to the user and the user is then prompted to
  #   respond yes or no. In environments such as the PowerShell ISE, the Confirm param
  #   is the title of the window presenting the message.
  # .OUTPUTS
  #   [Boolean]
  # .Parameter Message
  #   The message given to the user that tels them what they are responding yes/no to.
  # .Parameter Caption
  #   The title of the dialog window that is presented in environments that present
  #   the prompt in its own window. If not provided, the Message is used.
  # .EXAMPLE
  #   Confirm-Choice "Are you sure?"
  [CmdletBinding()]
  [OutputType([Boolean])]
  [Reflection.AssemblyMetadata("title", "Confirm-Choice")]
  param (
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$Message,

    [Parameter(Position = 1)]
    [string]$Caption = 'Do action.'
  )
  $y = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Yes";
  $n = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "No";
  $answer = $host.ui.PromptForChoice($caption, $message, $([System.Management.Automation.Host.ChoiceDescription[]]($y, $n)), 0)

  switch ($answer) {
    0 { return $true; break }
    1 { return $false; break }
  }
}