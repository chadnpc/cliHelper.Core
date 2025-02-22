function Write-Typewriter {
  <#
	.SYNOPSIS
		Writes text with the typewriter effect
	.EXAMPLE
		$random_Paragraph = Get-LoremIpsum
		$random_Paragraph | Write-Typewriter
	.LINK
		https://github.com/chadnpc/devHelper/blob/main/Private/devHelper.Cli/Public/Write-Typewriter.ps1
	#>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelinebyPropertyName = $True)]
    [string]$text = [string]::Empty,
    [int]$speed = 200
  )
  Begin {
    $IAP = $InformationPreference; $InformationPreference = 'Continue'
  }

  process {
    $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
    try {
      $text -split '' | ForEach-Object {
        Write-Host -NoNewline $_
        Start-Sleep -Milliseconds $(1 + [System.Random]::new().Next($speed))
      }
    } catch {
      Write-Host "Error: $($Error[0]) $fxn : $($_.InvocationInfo.ScriptLineNumber))"
      break
    }
  }

  end {
    $InformationPreference = $IAP
  }
}
