function Start-ProcessAsAdmin {
  <#
    .SYNOPSIS
    Runs a process with administrative privileges. If `-ExeToRun` is not
    specified, it is run with PowerShell.

    .NOTES
    Administrative Access Required.

    .INPUTS
    None

    .OUTPUTS
    None

    .PARAMETER Statements
    Arguments to pass to `ExeToRun` or the PowerShell script block to be
    run.

    .PARAMETER ExeToRun
    The executable/application/installer to run. Defaults to `'powershell'`.

    .PARAMETER Elevated
    Indicate whether the process should run elevated/aS Admin.

    Available in 0.10.2+.

    .PARAMETER Minimized
    Switch indicating if a Windows pops up (if not called with a silent
    argument) that it should be minimized.

    .PARAMETER NoSleep
    Used only when calling PowerShell - indicates the window that is opened
    should return instantly when it is complete.

    .PARAMETER ValidExitCodes
    Array of exit codes indicating success. Defaults to `@(0)`.

    .PARAMETER WorkingDirectory
    The working directory for the running process. Defaults to
    `Get-Location`. If current location is a UNC path, uses
    `$env:TEMP` for default as of 0.10.14.

    Available in 0.10.1+.

    .PARAMETER SensitiveStatements
    Arguments to pass to  `ExeToRun` that are not logged.

    Note that only licensed versions of Chocolatey provide a way to pass
    those values completely through without having them in the install
    script or on the system in some way.

    Available in 0.10.1+.

    .PARAMETER IgnoredArguments
    Allows splatting with arguments that do not apply. Do not use directly.

    .EXAMPLE
    Start-ProcessAsAdmin -Statements "$msiArgs" -ExeToRun 'msiexec'

    .EXAMPLE
    Start-ProcessAsAdmin -Statements "$silentArgs" -ExeToRun $file

    .EXAMPLE
    Start-ProcessAsAdmin -Statements "$silentArgs" -ExeToRun $file -ValidExitCodes @(0,21)

    .EXAMPLE
    >
    # Run PowerShell statements
    $psFile = Join-Path "$(Split-Path -parent $MyInvocation.MyCommand.Definition)" 'someInstall.ps1'
    Start-ProcessAsAdmin "& `'$psFile`'"

    .EXAMPLE
    # This also works for cmd and is required if you have any spaces in the paths within your command
    $appPath = "$env:ProgramFiles\myapp"
    $cmdBatch = "/c `"$appPath\bin\installmyappservice.bat`""
    Start-ProcessAsAdmin $cmdBatch cmd
    # or more explicitly
    Start-ProcessAsAdmin -Statements $cmdBatch -ExeToRun "cmd.exe"

    .LINK
    Install-DotfilePackage

    .LINK
    Install-DotfilePackage
    #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [parameter(Mandatory = $false, Position = 0)][string[]] $statements,
    [parameter(Mandatory = $false, Position = 1)][string] $exeToRun = 'powershell',
    [parameter(Mandatory = $false)][switch] $elevated,
    [parameter(Mandatory = $false)][switch] $minimized,
    [parameter(Mandatory = $false)][switch] $noSleep,
    [parameter(Mandatory = $false)] $validExitCodes = @(0),
    [parameter(Mandatory = $false)][string] $workingDirectory = $null,
    [parameter(Mandatory = $false)][string] $sensitiveStatements = ''
  )

  DynamicParam {
    $DynamicParams = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new()
    #region IgnoredArguments
    $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]::new()
    $attributes = [System.Management.Automation.ParameterAttribute]::new(); $attHash = @{
      Position                        = 8
      ParameterSetName                = '__AllParameterSets'
      Mandatory                       = $False
      ValueFromPipeline               = $true
      ValueFromPipelineByPropertyName = $true
      ValueFromRemainingArguments     = $true
      HelpMessage                     = 'Allows splatting with arguments that do not apply. Do not use directly.'
      DontShow                        = $False
    }; $attHash.Keys | ForEach-Object { $attributes.$_ = $attHash.$_ }
    $attributeCollection.Add($attributes)
    # $attributeCollection.Add([System.Management.Automation.ValidateSetAttribute]::new([System.Object[]]$ValidateSetOption))
    # $attributeCollection.Add([System.Management.Automation.ValidateRangeAttribute]::new([System.Int32[]]$ValidateRange))
    # $attributeCollection.Add([System.Management.Automation.ValidateNotNullOrEmptyAttribute]::new())
    # $attributeCollection.Add([System.Management.Automation.AliasAttribute]::new([System.String[]]$Aliases))
    $RuntimeParam = [System.Management.Automation.RuntimeDefinedParameter]::new("IgnoredArguments", [Object[]], $attributeCollection)
    $DynamicParams.Add("IgnoredArguments", $RuntimeParam)
    #endregion IgnoredArguments
    return $DynamicParams
  }

  Process {
    $PsCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
    [string]$statements = $statements -join ' '
    # Log Invocation  and Parameters used. $MyInvocation, $PSBoundParameters

    if ($null -eq $workingDirectory) {
      # $pwd = $(Get-Location -PSProvider 'FileSystem')
      if ($pwd -eq $null -or $null -eq $pwd.ProviderPath) {
        Write-Debug "Unable to use current location for Working Directory. Using Cache Location instead."
        $workingDirectory = $env:TEMP
      }
      $workingDirectory = $pwd.ProviderPath
    }
    $alreadyElevated = $false
    [bool]$IsAdmin = $((New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator));
    if ($IsAdmin) {
      $alreadyElevated = $true
    } else {
      Write-Warning "$fxn : [!]  It seems You're not Admin [!] "
      break
    }


    $dbMessagePrepend = "Elevating permissions and running"
    if (!$elevated) {
      $dbMessagePrepend = "Running"
    }

    try {
      if ($null -ne $exeToRun) { $exeToRun = $exeToRun -replace "`0", "" }
      if ($null -ne $statements) { $statements = $statements -replace "`0", "" }
    } catch {
      Write-Debug "Removing null characters resulted in an error - $($_.Exception.Message)"
    }

    if ($null -ne $exeToRun) {
      $exeToRun = $exeToRun.Trim().Trim("'").Trim('"')
    }

    $wrappedStatements = $statements
    if ($null -eq $wrappedStatements) { $wrappedStatements = '' }

    if ($exeToRun -eq 'powershell') {
      $exeToRun = "$($env:SystemRoot)\System32\WindowsPowerShell\v1.0\powershell.exe"
      $importChocolateyHelpers = "& import-module -name '$helpersPath\chocolateyInstaller.psm1' -Verbose:`$false | Out-Null;"
      $block = @"
        `$noSleep = `$$noSleep
        #`$env:dotfilesEnvironmentDebug='false'
        #`$env:dotfilesEnvironmentVerbose='false'
        $importChocolateyHelpers
        try{
            `$progressPreference="SilentlyContinue"
            $statements
            if(!`$noSleep){start-sleep 6}
        }
        catch{
            if(!`$noSleep){start-sleep 8}
            throw
        }
"@
      $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($block))
      $wrappedStatements = "-NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -InputFormat Text -OutputFormat Text -EncodedCommand $encoded"
      $dbgMessage = @"
$dbMessagePrepend powershell block:
$block
This may take a while, depending on the statements.
"@
    } else {
      $dbgMessage = @"
$dbMessagePrepend [`"$exeToRun`" $wrappedStatements]. This may take a while, depending on the statements.
"@
    }

    Write-Debug $dbgMessage

    $exeIsTextFile = [System.IO.Path]::GetFullPath($exeToRun) + ".istext"
    if ([System.IO.File]::Exists($exeIsTextFile)) {
      Set-PowerShellExitCode 4
      throw "The file was a text file but is attempting to be run as an executable - '$exeToRun'"
    }

    if ($exeToRun -eq 'msiexec' -or $exeToRun -eq 'msiexec.exe') {
      $exeToRun = "$($env:SystemRoot)\System32\msiexec.exe"
    }

    if (!([System.IO.File]::Exists($exeToRun)) -and $exeToRun -notmatch 'msiexec') {
      Write-Warning "May not be able to find '$exeToRun'. Please use full path for executables."
      # until we have search paths enabled, let's just pass a warning
      #Set-PowerShellExitCode 2
      #throw "Could not find '$exeToRun'"
    }

    # Redirecting output slows things down a bit.
    $writeOutput = {
      if ($null -ne $EventArgs.Data) {
        Write-Verbose "$($EventArgs.Data)"
      }
    }

    $writeError = {
      if ($null -ne $EventArgs.Data) {
        Write-Error "$($EventArgs.Data)"
      }
    }

    $process = New-Object System.Diagnostics.Process
    $process.EnableRaisingEvents = $true
    Register-ObjectEvent -InputObject $process -SourceIdentifier "LogOutput_ChocolateyProc" -EventName OutputDataReceived -Action $writeOutput | Out-Null
    Register-ObjectEvent -InputObject $process -SourceIdentifier "LogErrors_ChocolateyProc" -EventName ErrorDataReceived -Action $writeError | Out-Null

    #$process.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($exeToRun, $wrappedStatements)
    # in case empty args makes a difference, try to be compatible with the older
    # version
    $psi = New-Object System.Diagnostics.ProcessStartInfo

    $psi.FileName = $exeToRun
    if ($wrappedStatements -ne '') {
      $psi.Arguments = "$wrappedStatements"
    }
    if ($null -ne $sensitiveStatements -and $sensitiveStatements -ne '') {
      Write-Info "Sensitive arguments have been passed. Adding to arguments."
      $psi.Arguments += " $sensitiveStatements"
    }
    $process.StartInfo = $psi

    # process start info
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.WorkingDirectory = $workingDirectory

    if ($elevated -and !$alreadyElevated -and [Environment]::OSVersion.Version -ge (New-Object 'Version' 6, 0)) {
      # this doesn't actually currently work - because we are not running under shell execute
      Write-Debug "Setting RunAs for elevation"
      $process.StartInfo.Verb = "RunAs"
    }
    if ($minimized) {
      $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
    }
    if ($PSCmdlet.ShouldProcess("`$process", "Start Process")) {
      $process.Start() | Out-Null
      if ($process.StartInfo.RedirectStandardOutput) { $process.BeginOutputReadLine() }
      if ($process.StartInfo.RedirectStandardError) { $process.BeginErrorReadLine() }
      $process.WaitForExit()

      # For some reason this forces the jobs to finish and waits for
      # them to do so. Without this it never finishes.
      Unregister-Event -SourceIdentifier "LogOutput_ChocolateyProc"
      Unregister-Event -SourceIdentifier "LogErrors_ChocolateyProc"

      # sometimes the process hasn't fully exited yet.
      for ($loopCount = 1; $loopCount -le 15; $loopCount++) {
        if ($process.HasExited) { break; }
        Write-Debug "Waiting for process to exit - $loopCount/15 seconds";
        Start-Sleep 1;
      }

      $exitCode = $process.ExitCode
      $process.Dispose()

      Write-Debug "Command [`"$exeToRun`" $wrappedStatements] exited with `'$exitCode`'."
    }
    $exitErrorMessage = ''
    $errorMessageAddendum = " This is most likely an issue with the '$env:dotfilesPackageName' package and not with Chocolatey itself. Please follow up with the package maintainer(s) directly."

    switch ($exitCode) {
      0 { break }
      1 { break }
      3010 { break }
      # NSIS - http://nsis.sourceforge.net/Docs/AppendixD.html
      # InnoSetup - http://www.jrsoftware.org/ishelp/index.php?topic=setupexitcodes
      2 { $exitErrorMessage = 'Setup was cancelled.'; break }
      3 { $exitErrorMessage = 'A fatal error occurred when preparing or moving to next install phase. Check to be sure you have enough memory to perform an installation and try again.'; break }
      4 { $exitErrorMessage = 'A fatal error occurred during installation process.' + $errorMessageAddendum; break }
      5 { $exitErrorMessage = 'User (you) cancelled the installation.'; break }
      6 { $exitErrorMessage = 'Setup process was forcefully terminated by the debugger.'; break }
      7 { $exitErrorMessage = 'While preparing to install, it was determined setup cannot proceed with the installation. Please be sure the software can be installed on your system.'; break }
      8 { $exitErrorMessage = 'While preparing to install, it was determined setup cannot proceed with the installation until you restart the system. Please reboot and try again.'; break }
      # MSI - https://msdn.microsoft.com/en-us/library/windows/desktop/aa376931.aspx
      1602 { $exitErrorMessage = 'User (you) cancelled the installation.'; break }
      1603 { $exitErrorMessage = "Generic MSI Error. This is a local environment error, not an issue with a package or the MSI itself - it could mean a pending reboot is necessary prior to install or something else (like the same version is already installed). Please see MSI log if available. If not, try again adding `'--install-arguments=`"`'/l*v c:\$($env:dotfilesPackageName)_msi_install.log`'`"`'. Then search the MSI Log for `"Return Value 3`" and look above that for the error."; break }
      1618 { $exitErrorMessage = 'Another installation currently in progress. Try again later.'; break }
      1619 { $exitErrorMessage = 'MSI could not be found - it is possibly corrupt or not an MSI at all. If it was downloaded and the MSI is less than 30K, try opening it in an editor like Notepad++ as it is likely HTML.' + $errorMessageAddendum; break }
      1620 { $exitErrorMessage = 'MSI could not be opened - it is possibly corrupt or not an MSI at all. If it was downloaded and the MSI is less than 30K, try opening it in an editor like Notepad++ as it is likely HTML.' + $errorMessageAddendum; break }
      1622 { $exitErrorMessage = 'Something is wrong with the install log location specified. Please fix this in the package silent arguments (or in install arguments you specified). The directory specified as part of the log file path must exist for an MSI to be able to log to that directory.' + $errorMessageAddendum; break }
      1623 { $exitErrorMessage = 'This MSI has a language that is not supported by your system. Contact package maintainer(s) if there is an install available in your language and you would like it added to the packaging.'; break }
      1625 { $exitErrorMessage = 'Installation of this MSI is forbidden by system policy. Please contact your system administrators.'; break }
      1632 { $exitErrorMessage = 'Installation of this MSI is not supported on this platform. Contact package maintainer(s) if you feel this is in error or if you need an architecture that is not available with the current packaging.'; break }
      1633 { $exitErrorMessage = 'Installation of this MSI is not supported on this platform. Contact package maintainer(s) if you feel this is in error or if you need an architecture that is not available with the current packaging.'; break }
      1638 { $exitErrorMessage = 'This MSI requires uninstall prior to installing a different version. Please ask the package maintainer(s) to add a check in the chocolateyInstall.ps1 script and uninstall if the software is installed.' + $errorMessageAddendum; break }
      1639 { $exitErrorMessage = 'The command line arguments passed to the MSI are incorrect. If you passed in additional arguments, please adjust. Otherwise followup with the package maintainer(s) to get this fixed.' + $errorMessageAddendum; break }
      1640 { $exitErrorMessage = 'Cannot install MSI when running from remote desktop (terminal services). This should automatically be handled in licensed editions. For open source editions, you may need to run change.exe prior to running Chocolatey or not use terminal services.'; break }
      1645 { $exitErrorMessage = 'Cannot install MSI when running from remote desktop (terminal services). This should automatically be handled in licensed editions. For open source editions, you may need to run change.exe prior to running Chocolatey or not use terminal services.'; break }
    }

    if ($exitErrorMessage) {
      $errorMessageSpecific = "Exit code indicates the following: $exitErrorMessage."
      Write-Warning $exitErrorMessage
    } else {
      $errorMessageSpecific = 'See log for possible error messages.'
    }

    if ($validExitCodes -notcontains $exitCode) {
      Set-PowerShellExitCode $exitCode
      throw "Running [`"$exeToRun`" $wrappedStatements] was not successful. Exit code was '$exitCode'. $($errorMessageSpecific)"
    } else {
      $chocoSuccessCodes = @(0, 1605, 1614, 1641, 3010)
      if ($chocoSuccessCodes -notcontains $exitCode) {
        Write-Warning "Exit code '$exitCode' was considered valid by script, but not as a Chocolatey success code. Returning '0'."
        $exitCode = 0
      }
    }

    Write-Debug "Finishing '$($MyInvocation.InvocationName)'"

    return $exitCode
  }
}
<#
    $ShimGen = [System.IO.Path]::GetFullPath($ShimGen)
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = new-object System.Diagnostics.ProcessStartInfo($ShimGen, $ShimGenArgs)
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $process.Start() | Out-Null
    $process.WaitForExit()
#>

<# Start PROCESS UTF8
# $standardOut = @(Start-Utf8Process $script:OMPExecutable @("print", "tooltip", "--pwd=$cleanPWD", "--shell=powershell", "--pswd=$cleanPSWD", "--config=$env:POSH_THEME", "--command=$command", "--shell-version=$script:PSVersion"))
    function Start-Utf8Process {
        param(
            [string]$FileName,
            [string[]]$Arguments = @()
        )

        $Process = New-Object System.Diagnostics.Process
        $StartInfo = $Process.StartInfo
        $StartInfo.FileName = $FileName
        if ($StartInfo.ArgumentList.Add) {
            # ArgumentList is supported in PowerShell 6.1 and later (built on .NET Core 2.1+)
            # ref-1: https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.argumentlist?view=net-6.0
            # ref-2: https://docs.microsoft.com/en-us/powershell/scripting/whats-new/differences-from-windows-powershell?view=powershell-7.2#net-framework-vs-net-core
            $Arguments | ForEach-Object -Process { $StartInfo.ArgumentList.Add($_) }
        } else {
            # escape arguments manually in lower versions, refer to https://docs.microsoft.com/en-us/previous-versions/17w5ykft(v=vs.85)
            $escapedArgs = $Arguments | ForEach-Object {
                # escape N consecutive backslash(es), which are followed by a double quote, to 2N consecutive ones
                $s = $_ -replace '(\\+)"', '$1$1"'
                # escape N consecutive backslash(es), which are at the end of the string, to 2N consecutive ones
                $s = $s -replace '(\\+)$', '$1$1'
                # escape double quotes
                $s = $s -replace '"', '\"'
                # quote the argument
                "`"$s`""
            }
            $StartInfo.Arguments = $escapedArgs -join ' '
        }
        $StartInfo.StandardErrorEncoding = $StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $StartInfo.RedirectStandardError = $StartInfo.RedirectStandardInput = $StartInfo.RedirectStandardOutput = $true
        $StartInfo.UseShellExecute = $false
        if ($PWD.Provider.Name -eq 'FileSystem') {
            $StartInfo.WorkingDirectory = $PWD.ProviderPath
        }
        $StartInfo.CreateNoWindow = $true
        [void]$Process.Start()

        # we do this to remove a deadlock potential on Windows
        $stdoutTask = $Process.StandardOutput.ReadToEndAsync()
        $stderrTask = $Process.StandardError.ReadToEndAsync()
        [void]$Process.WaitForExit()
        $stderr = $stderrTask.Result.Trim()
        if ($stderr -ne '') {
          $Host.UI.WriteErrorLine($stderr)
        }
        $stdoutTask.Result
#>