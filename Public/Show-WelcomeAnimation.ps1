function Show-WelcomeAnimation {
  # this is still a hardcoded function but it can get better
  # ex:
  # todo: add options configure the animation if its the first time the user uses the cmdlet
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false)]
    [String]$Message
  )

  process {
    <#>>Banner>>#>
    Write-Info -ForegroundColor Green "$([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('CgAgACAAIAAgACAAIAAgACAALgBkADgAOAA4ACAAZAA4AGIAIAA4ADgAOAAKACAAIAAgACAAIAAgACAAIABkADgAQgAiACAAIABZADgAUAAgADgAOAA4AAoAIAAgACAAIAAgACAAIAAgADgAOAA4ACAAIAAgACAAIAAgACAAOAA4ADgAIAAgACAAIAAgACAAIAAgAAoAIAAgACAAIAAgACAAOAA4ADgAOAA4ADgAOAAgADgAOAA4ACAAOAA4ADgAIAAgAC4AZAA4ADgAYgAuACAAIAAuAGQAOAA4ADgAOAB5AAoAIAAgACAAIAAgACAAIAAgADgAOAA4ACAAIAAgADgAOAA4ACAAOAA4ADgAIABkADgAUAAgACAAWQA4AGIAIAA4ADgASwAKACAAIAAgACAAIAAgACAAIAA4ADgAOAAgACAAIAA4ADgAOAAgADgAOAA4ACAAOAA4ADgAOAA4ADgAOAA4ACAAIgBZADgAOAA4ADgAYgAuAAoAIAAgACAAIABkADgAYgAgADgAOAA4ACAAIAAgADgAOAA4ACAAOAA4ADgAIABZADgAYgAuACAAIAAgACAAIAAgACAAIAAgACAAWAA4ADgACgAgACAAIAAgAFkAOABQACAAOAA4ADgAIAAgACAAOAA4ADgAIAA4ADgAOAAgACAAIgBZADgAOAA4ADgAIAAgACAAbAA4ADgAOAA4AFAAJwA=')))"; Write-Info -NoNewline "`n   "; Write-RGB "$($(Get-ciminstance win32_operatingsystem).caption) Build: $([System.Environment]::OSVersion.Version.Build)`n" -ForegroundColor SlateBlue -BackgroundColor Black;
    # TODO: create an animated text
    $cursoranimation = @("|", "/", "-", "\", "|", "/", "-", "\" , "+", "/", "-", "\", "|", "/", "+", "\", "+", "/", "-", "\", "|", "/", "-", "\" , "|", "/", "-", "\", "|") # Animation sequence characters
    $ReturnCode = @{}
    $_StatusMsg = "Loading $ProjectName"

    $CursorTop = [Console]::CursorTop #// Cursor position on Y axis
    $CursorLeft = $_StatusMsg.Length #// Cursor position on X axis
    Write-Info $_StatusMsg -ForegroundColor Cyan -NoNewline

    #// starting the background job

    $MsbJob = [PowerShell]::Create().AddScript({
        param($MsbArgs, $Result)
        & msbuild $MsbArgs | Out-Null
        $Result.Value = $LASTEXITCODE
      }
    ).AddArgument($MsbArgs).AddArgument($ReturnCode)

    $async = $MsbJob.BeginInvoke() #// start executing the job.

    #// While above script block is doing its job in background, display status and animation in console window.

    while (!$async.IsCompleted) {
      $cursoranimation | ForEach-Object {
        [Console]::SetCursorPosition($CursorLeft + 5, $CursorTop) #//setting position for cursor
        Write-Info "`b$_" -NoNewline -ForegroundColor Yellow
        Start-Sleep -m 55
      }
    }
    $MsbJob.EndInvoke($async)
  }
  end {
    [System.GC]::Collect()
  }
}