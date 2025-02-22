function Invoke-InputBox {
  <#
    .SYNOPSIS
        A short one-line action-based description, e.g. 'Tests if a function is valid'
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Information or caveats about the function e.g. 'This function is not supported in Linux'
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        Test-MyTestFunction -Verbose
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    #>
  [cmdletbinding(DefaultParameterSetName = "plain")]
  [alias("ibx")]
  [OutputType([system.string], ParameterSetName = 'plain')]
  [OutputType([system.security.securestring], ParameterSetName = 'secure')]

  Param(
    [Parameter(ParameterSetName = "secure")]
    [Parameter(HelpMessage = "Enter the title for the input box. No more than 25 characters.",
      ParameterSetName = "plain")]

    [ValidateNotNullorEmpty()]
    [ValidateScript( { $_.length -le 25 })]
    [string]$Title = "User Input",

    [Parameter(ParameterSetName = "secure")]
    [Parameter(HelpMessage = "Enter a prompt. No more than 50 characters.", ParameterSetName = "plain")]
    [ValidateNotNullorEmpty()]
    [ValidateScript( { $_.length -le 50 })]
    [string]$Prompt = "Please enter a value:",

    [Parameter(HelpMessage = "Use to mask the entry and return a secure string.",
      ParameterSetName = "secure")]
    [switch]$AsSecureString,

    [string]$BackgroundColor = "White"
  )

  if ((Test-IsPSWindows)) {
    Add-Type -AssemblyName 'PresentationFramework'
    Add-Type -AssemblyName 'PresentationCore'

    #remove the variable because it might get cached in the ISE or VS Code
    Remove-Variable -Name myInput -Scope script -ErrorAction SilentlyContinue

    $form = New-Object System.Windows.Window
    $stack = New-Object System.Windows.Controls.StackPanel

    #define what it looks like
    $form.Title = $title
    $form.Height = 150
    $form.Width = 350

    $form.Background = $BackgroundColor

    $label = New-Object System.Windows.Controls.Label
    $label.Content = "    $Prompt"
    $label.HorizontalAlignment = "left"
    $stack.AddChild($label)

    if ($AsSecureString) {
      $inputbox = New-Object System.Windows.Controls.PasswordBox
    } else {
      $inputbox = New-Object System.Windows.Controls.TextBox
    }

    $inputbox.Width = 300
    $inputbox.HorizontalAlignment = "center"

    $stack.AddChild($inputbox)

    $space = New-Object System.Windows.Controls.Label
    $space.Height = 10
    $stack.AddChild($space)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "_OK"

    $btn.Width = 65
    $btn.HorizontalAlignment = "center"
    $btn.VerticalAlignment = "bottom"

    #add an event handler
    $btn.Add_click( {
        if ($AsSecureString) {
          $script:myInput = $inputbox.SecurePassword
        } else {
          $script:myInput = $inputbox.text
        }
        $form.Close()
      }
    )
    $stack.AddChild($btn)
    $space2 = New-Object System.Windows.Controls.Label
    $space2.Height = 10
    $stack.AddChild($space2)

    $btn2 = New-Object System.Windows.Controls.Button
    $btn2.Content = "_Cancel"

    $btn2.Width = 65
    $btn2.HorizontalAlignment = "center"
    $btn2.VerticalAlignment = "bottom"

    #add an event handler
    $btn2.Add_click( {
        $form.Close()
      }
    )
    $stack.AddChild($btn2)

    #add the stack to the form
    $form.AddChild($stack)

    #show the form
    [void]$inputbox.Focus()
    $form.WindowStartupLocation = [System.Windows.WindowStartupLocation]::CenterScreen

    [void]$form.ShowDialog()

    #write the result from the input box back to the pipeline
    $script:myInput
  } else {
    Write-Warning "Sorry. This command requires a Windows platform."
    #bail out
    Return
  }
}