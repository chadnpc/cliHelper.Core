
function Show-Menu {}

function Show-Prompt {}

function Confirm-Choice {
  # .SYNOPSIS
  #     Prompts the user to choose a yes/no option.
  # .DESCRIPTION
  #     The message parameter is presented to the user and the user is then prompted to
  #     respond yes or no. In environments such as the PowerShell ISE, the Confirm param
  #     is the title of the window presenting the message.
  # .OUTPUTS
  #     [Boolean]
  # .Parameter Message
  #     The message given to the user that tels them what they are responding yes/no to.
  # .Parameter Caption
  #     The title of the dialog window that is presented in environments that present
  #     the prompt in its own window. If not provided, the Message is used.
  [OutputType([Boolean])]
  [CmdletBinding()]
  param (
    [Parameter()]
    [string]$Message,
    [string]$Caption = $Message
  )
  $y = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Yes";
  $n = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "No";
  $answer = $host.ui.PromptForChoice($caption, $message, $([System.Management.Automation.Host.ChoiceDescription[]]($y, $n)), 0)

  switch ($answer) {
    0 { return $true; break }
    1 { return $false; break }
  }
}

function New-MessageBox {
  <#
.SYNOPSIS
    New-Popup will display a message box. If a timeout is requested it uses Wscript.Shell PopUp method. If a default button is requested it uses the ::Show method from 'Windows.Forms.MessageBox'
.DESCRIPTION
    The New-Popup command uses the Wscript.Shell PopUp method to display a graphical message
    box. You can customize its appearance of icons and buttons. By default the user
    must click a button to dismiss but you can set a timeout value in seconds to
    automatically dismiss the popup.

    The command will write the return value of the clicked button to the pipeline:
    Timeout = -1
    OK      =  1
    Cancel  =  2
    Abort   =  3
    Retry   =  4
    Ignore  =  5
    Yes     =  6
    No      =  7

    If no button is clicked, the return value is -1.
.PARAMETER Message
    The message you want displayed
.PARAMETER Title
    The text to appear in title bar of dialog box
.PARAMETER Time
    The time to display the message. Defaults to 0 (zero) which will keep dialog open until a button is clicked
.PARAMETER  Buttons
    Valid values for -Buttons include:
    "OK"
    "OKCancel"
    "AbortRetryIgnore"
    "YesNo"
    "YesNoCancel"
    "RetryCancel"
.PARAMETER  Icon
    Valid values for -Icon include:
    "Stop"
    "Question"
    "Exclamation"
    "Information"
    "None"
.PARAMETER  ShowOnTop
    Switch which will force the popup window to appear on top of all other windows.
.PARAMETER  AsString
    Will return a human readable representation of which button was pressed as opposed to an integer value.
.EXAMPLE
    new-popup -message "The update script has completed" -title "Finished" -time 5

    This will display a popup message using the default OK button and default
    Information icon. The popup will automatically dismiss after 5 seconds.
.EXAMPLE
    $answer = new-popup -Message "Please pick" -Title "form" -buttons "OKCancel" -icon "information"

    If the user clicks "OK" the $answer variable will be equal to 1. If the user clicks "Cancel" the
    $answer variable will be equal to 2.
.EXAMPLE
    $answer = new-popup -Message "Please pick" -Title "form" -buttons "OKCancel" -icon "information" -AsString

    If the user clicks "OK" the $answer variable will be equal to 'OK'. If the user clicks "Cancel" the
    $answer variable will be 'Cancel'
.OUTPUTS
    An integer with the following value depending upon the button pushed.

    Timeout = -1    # Value when timer finishes countdown.
    OK      =  1
    Cancel  =  2
    Abort   =  3
    Retry   =  4
    Ignore  =  5
    Yes     =  6
    No      =  7
.LINK
    Wscript.Shell
#>

  #region Parameters
  [CmdletBinding(DefaultParameterSetName = 'Timeout')]
  [OutputType('int')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
  Param (
    [Parameter(Mandatory, HelpMessage = 'Enter a message for the message box', ParameterSetName = 'DefaultButton')]
    [Parameter(Mandatory, HelpMessage = 'Enter a message for the message box', ParameterSetName = 'Timeout')]
    [ValidateNotNullorEmpty()]
    [string] $Message,

    [Parameter(Mandatory, HelpMessage = 'Enter a title for the message box', ParameterSetName = 'DefaultButton')]
    [Parameter(Mandatory, HelpMessage = 'Enter a title for the message box', ParameterSetName = 'Timeout')]
    [ValidateNotNullorEmpty()]
    [string] $Title,

    [Parameter(ParameterSetName = 'Timeout')]
    [ValidateScript({ $_ -ge 0 })]
    [int] $Time = 0,

    [Parameter(ParameterSetName = 'DefaultButton')]
    [Parameter(ParameterSetName = 'Timeout')]
    [ValidateNotNullorEmpty()]
    [ValidateSet('OK', 'OKCancel', 'AbortRetryIgnore', 'YesNo', 'YesNoCancel', 'RetryCancel')]
    [string] $Buttons = 'OK',

    [Parameter(ParameterSetName = 'DefaultButton')]
    [Parameter(ParameterSetName = 'Timeout')]
    [ValidateNotNullorEmpty()]
    [ValidateSet('None', 'Stop', 'Hand', 'Error', 'Question', 'Exclamation', 'Warning', 'Asterisk', 'Information')]
    [string] $Icon = 'None',

    [Parameter(ParameterSetName = 'Timeout')]
    [switch] $ShowOnTop,

    [Parameter(ParameterSetName = 'DefaultButton')]
    [ValidateSet('Button1', 'Button2', 'Button2')]
    [string] $DefaultButton = 'Button1',

    [Parameter(ParameterSetName = 'DefaultButton')]
    [Parameter(ParameterSetName = 'Timeout')]
    [switch] $AsString

  )
  #endregion Parameters

  begin {
    Write-Invocation $MyInvocation
    Out-Verbose "ParameterSetName [$($PsCmdlet.ParameterSetName)]"

    # set $ShowOnTopValue based on switch
    if ($ShowOnTop) {
      $ShowOnTopValue = 4096
    } else {
      $ShowOnTopValue = 0
    }

    #lookup key to convert buttons to their integer equivalents
    $ButtonsKey = ([ordered] @{
        'OK'               = 0
        'OKCancel'         = 1
        'AbortRetryIgnore' = 2
        'YesNo'            = 4
        'YesNoCancel'      = 3
        'RetryCancel'      = 5
      })

    #lookup key to convert icon to their integer equivalents
    $IconKey = ([ordered] @{
        'None'        = 0
        'Stop'        = 16
        'Hand'        = 16
        'Error'       = 16
        'Question'    = 32
        'Exclamation' = 48
        'Warning'     = 48
        'Asterisk'    = 64
        'Information' = 64
      })

    #lookup key to convert return value to human readable button press
    $ReturnKey = ([ordered] @{
        -1 = 'Timeout'
        1  = 'OK'
        2  = 'Cancel'
        3  = 'Abort'
        4  = 'Retry'
        5  = 'Ignore'
        6  = 'Yes'
        7  = 'No'
      })
  }

  process {
    switch ($PsCmdlet.ParameterSetName) {
      'Timeout' {
        try {
          $wshell = New-Object -ComObject Wscript.Shell -ErrorAction Stop
          #Button and icon type values are added together to create an integer value
          $return = $wshell.Popup($Message, $Time, $Title, $ButtonsKey[$Buttons] + $Iconkey[$Icon] + $ShowOnTopValue)
          if ($return -eq -1) {
            Out-Verbose "User timedout [$($returnkey[$return])] after [$time] seconds"
          } else {
            Out-Verbose "User pressed [$($returnkey[$return])]"
          }
          if ($AsString) {
            $ReturnKey[$return]
          } else {
            $return
          }
        } catch {
          #You should never really run into an exception in normal usage
          Write-Error -Message 'Failed to create Wscript.Shell COM object'
          Write-Error -Message ($_.exception.message)
        }
      }

      'DefaultButton' {
        try {
          $MessageBox = [Windows.Forms.MessageBox]
          $Return = ($MessageBox::Show($Message, $Title, $ButtonsKey[$Buttons], $Iconkey[$Icon], $DefaultButton)).Value__
          Out-Verbose "User pressed [$($returnkey[$return])]"
          if ($AsString) {
            $ReturnKey[$return]
          } else {
            $return
          }
        } catch {
          #You should never really run into an exception in normal usage
          Write-Error -Message 'Failed to create MessageBox'
          Write-Error -Message ($_.exception.message)
        }
      }
    }
  }

  end {
    Out-Verbose $fxn "Complete."
  }
}


function New-Inputbox {
  <#
.SYNOPSIS
    Display a Visual Basic style inputbox.
.DESCRIPTION
    This function will display a graphical Inputbox, like the one from VisualBasic
    and VBScript. You must specify a message prompt. You can specify a title, the
    default is "Input". You can also specify a default value. The inputbox will write
    whatever is entered into it to the pipeline. If you click Cancel the inputbox
    will still write a string to the pipeline with a length of 0. It is recommended
    that you validate input.
.PARAMETER Prompt
    A string that is displayed before the text entry field in dialog box
.PARAMETER Title
    A string that appears as the title of the dialog box
.PARAMETER Default
    An optional parameter indicating the default value of the text entry field
.EXAMPLE
    $c = New-Inputbox -Prompt 'Enter the Netbios name of a domain computer' -Title "Enter a computername" -Default $env:computername
    Get-Service -ComputerName $c
.OUTPUTS
    [string]
#>

  [CmdletBinding(ConfirmImpact = 'None')]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]

  Param (
    [Parameter(Position = 0)]
    [ValidateNotNullorEmpty()]
    [string] $Prompt = 'Please enter a value',

    [Parameter(Position = 1)]
    [string] $Title = 'Input',

    [Parameter(Position = 2)]
    [string] $Default = ''

  )

  begin {
    Write-Invocation $MyInvocation
    Out-Verbose "-Prompt is [$Prompt]"
    Out-Verbose "-Title is [$Title]"
    Out-Verbose "-Default is [$Default]"
  }

  process {
    try {
      Add-Type -AssemblyName 'microsoft.visualbasic' -ErrorAction Stop
      [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, $Title, $Default)
    } catch {
      Write-Warning -Message 'There was a problem creating the inputbox'
      Write-Warning -Message $_.Exception.Message
    }
  }

  end {
    Out-Verbose $fxn "Complete."
  }
}